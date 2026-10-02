"""Blend Preference Aggregator for Blends.

Aggregates group preferences from simple weighted voting to generate ranked recommendations:
- Everyone's picks (high group consensus)
- Most compatible (style coherence)
- Individual picks (personalized for each member)
- Best compromise (balanced for all)
Note: This is a rule-based aggregator, not an ML model.
"""

from __future__ import annotations

from typing import List, Dict, Optional, Tuple
import logging
import numpy as np

from sqlalchemy.orm import Session
from sqlalchemy import and_

from ...models import User, Product
from ...blend_helpers import get_blend_members
from ..models_ai import UserStyleProfile, UserEmbedding, ProductEmbedding
from ..recommendation.rule_based_recommender import RuleBasedRecommender
from ..outfits.outfit_generator import OutfitCompatibilityScorer

logger = logging.getLogger(__name__)


class BlendPreferenceAggregator:
    """Rule-based group preference aggregator for Blends (formerly GroupPreferenceModel)."""

    def __init__(
        self,
        recommender: Optional[RuleBasedRecommender] = None,
        compatibility_scorer: Optional[OutfitCompatibilityScorer] = None,
    ):
        """Initialize blend preference aggregator.

        Args:
            recommender: Rule-based recommender instance
            compatibility_scorer: Outfit compatibility scorer
        """
        self.recommender = recommender or RuleBasedRecommender()
        self.compatibility_scorer = compatibility_scorer or OutfitCompatibilityScorer()

    def _get_member_style_profiles(
        self,
        db: Session,
        member_ids: List[int],
    ) -> Dict[int, UserStyleProfile]:
        """Get Style DNA profiles for all blend members.

        Args:
            db: Database session
            member_ids: List of user IDs

        Returns:
            Dictionary mapping user_id to Style DNA profile
        """
        profiles = db.query(UserStyleProfile).filter(
            UserStyleProfile.user_id.in_(member_ids)
        ).all()

        return {p.user_id: p for p in profiles}

    def _compute_group_style_vector(
        self,
        style_profiles: Dict[int, UserStyleProfile],
    ) -> Dict[str, float]:
        """Compute aggregate group style preferences.

        Args:
            style_profiles: Dictionary of user Style DNA profiles

        Returns:
            Aggregate style scores
        """
        if not style_profiles:
            return {}

        # Initialize accumulators
        style_scores = {}
        color_scores = {}
        fit_scores = {}
        brand_scores = {}
        category_scores = {}

        # Accumulate across all members
        for profile in style_profiles.values():
            for style, score in profile.style_scores.items():
                style_scores[style] = style_scores.get(style, 0) + score

            for color, score in profile.color_scores.items():
                color_scores[color] = color_scores.get(color, 0) + score

            for fit, score in profile.fit_scores.items():
                fit_scores[fit] = fit_scores.get(fit, 0) + score

            for brand, score in profile.brand_scores.items():
                brand_scores[brand] = brand_scores.get(brand, 0) + score

            for category, score in profile.category_scores.items():
                category_scores[category] = category_scores.get(category, 0) + score

        # Normalize by number of members
        num_members = len(style_profiles)
        if num_members > 0:
            for key in style_scores:
                style_scores[key] /= num_members
            for key in color_scores:
                color_scores[key] /= num_members
            for key in fit_scores:
                fit_scores[key] /= num_members
            for key in brand_scores:
                brand_scores[key] /= num_members
            for key in category_scores:
                category_scores[key] /= num_members

        return {
            "style": style_scores,
            "color": color_scores,
            "fit": fit_scores,
            "brand": brand_scores,
            "category": category_scores,
        }

    def _compute_group_consensus_score(
        self,
        product: Product,
        style_profiles: Dict[int, UserStyleProfile],
    ) -> float:
        """Compute how much the group will like a product.

        Args:
            product: Product to score
            style_profiles: Member Style DNA profiles

        Returns:
            Group consensus score (0-1)
        """
        if not style_profiles:
            return 0.5

        individual_scores = []

        for profile in style_profiles.values():
            # Compute individual preference score
            score = 0.0
            count = 0

            if product.style and product.style.lower() in profile.style_scores:
                score += profile.style_scores[product.style.lower()]
                count += 1

            if product.color and product.color.lower() in profile.color_scores:
                score += profile.color_scores[product.color.lower()]
                count += 1

            if product.fit and product.fit.lower() in profile.fit_scores:
                score += profile.fit_scores[product.fit.lower()]
                count += 1

            if count > 0:
                individual_scores.append(score / count)
            else:
                individual_scores.append(0.5)

        # Group score is average of individual scores
        return np.mean(individual_scores)

    def _compute_group_compatibility(
        self,
        products: List[Product],
    ) -> float:
        """Compute how well a set of products works together as a group.

        Args:
            products: List of products

        Returns:
            Compatibility score (0-1)
        """
        return self.compatibility_scorer.score_outfit(products)

    def generate_everyones_picks(
        self,
        db: Session,
        member_ids: List[int],
        limit: int = 20,
    ) -> List[Tuple[Product, float]]:
        """Generate picks that everyone in the group will like.

        High group consensus ranking.

        Args:
            db: Database session
            member_ids: List of blend member user IDs
            limit: Number of products to return

        Returns:
            List of (product, consensus_score) tuples
        """
        # Get member style profiles
        style_profiles = self._get_member_style_profiles(db, member_ids)

        # Get candidate products
        from ...models import Product
        candidates = db.query(Product).filter(
            Product.is_active == True
        ).limit(200).all()

        # Score by group consensus
        scored = []
        for product in candidates:
            consensus_score = self._compute_group_consensus_score(
                product,
                style_profiles,
            )
            scored.append((product, consensus_score))

        # Sort by consensus
        scored.sort(key=lambda x: x[1], reverse=True)

        return scored[:limit]

    def generate_most_compatible(
        self,
        db: Session,
        member_ids: List[int],
        limit: int = 10,
    ) -> List[Tuple[List[Product], float]]:
        """Generate outfit combinations with high group compatibility.

        Args:
            db: Database session
            member_ids: List of blend member user IDs
            limit: Number of outfit combinations

        Returns:
            List of (products, compatibility_score) tuples
        """
        # Get group style vector
        style_profiles = self._get_member_style_profiles(db, member_ids)
        group_style = self._compute_group_style_vector(style_profiles)

        # Get candidates by role
        from ...models import Product
        upper_candidates = db.query(Product).filter(
            Product.is_active == True,
            Product.outfit_role == "upper",
        ).limit(20).all()

        bottom_candidates = db.query(Product).filter(
            Product.is_active == True,
            Product.outfit_role == "bottom",
        ).limit(20).all()

        footwear_candidates = db.query(Product).filter(
            Product.is_active == True,
            Product.outfit_role == "footwear",
        ).limit(20).all()

        # Generate combinations
        combinations = []
        for _ in range(min(limit, 50)):
            upper = np.random.choice(upper_candidates) if upper_candidates else None
            bottom = np.random.choice(bottom_candidates) if bottom_candidates else None
            footwear = np.random.choice(footwear_candidates) if footwear_candidates else None

            items = [p for p in [upper, bottom, footwear] if p]
            if len(items) >= 2:
                compatibility = self._compute_group_compatibility(items)
                combinations.append((items, compatibility))

        # Sort by compatibility
        combinations.sort(key=lambda x: x[1], reverse=True)

        return combinations[:limit]

    def generate_individual_picks(
        self,
        db: Session,
        member_ids: List[int],
        limit_per_member: int = 5,
    ) -> Dict[int, List[Tuple[Product, float]]]:
        """Generate personalized picks for each group member.

        Args:
            db: Database session
            member_ids: List of blend member user IDs
            limit_per_member: Number of picks per member

        Returns:
            Dictionary mapping user_id to list of (product, score) tuples
        """
        individual_picks = {}

        for user_id in member_ids:
            # Use hybrid recommender for each member
            recommendations = self.recommender.recommend(
                db=db,
                user_id=user_id,
                limit=limit_per_member,
            )

            individual_picks[user_id] = recommendations

        return individual_picks

    def generate_best_compromise(
        self,
        db: Session,
        member_ids: List[int],
        limit: int = 10,
    ) -> List[Tuple[Product, float]]:
        """Generate picks that balance preferences across all members.

        Finds products that are acceptable to everyone even if not
        the top choice for any single member.

        Args:
            db: Database session
            member_ids: List of blend member user IDs
            limit: Number of products to return

        Returns:
            List of (product, compromise_score) tuples
        """
        # Get member style profiles
        style_profiles = self._get_member_style_profiles(db, member_ids)

        # Get candidate products
        from ...models import Product
        candidates = db.query(Product).filter(
            Product.is_active == True
        ).limit(200).all()

        # Score by minimum individual score (compromise metric)
        scored = []
        for product in candidates:
            individual_scores = []

            for profile in style_profiles.values():
                score = 0.0
                count = 0

                if product.style and product.style.lower() in profile.style_scores:
                    score += profile.style_scores[product.style.lower()]
                    count += 1

                if product.color and product.color.lower() in profile.color_scores:
                    score += profile.color_scores[product.color.lower()]
                    count += 1

                if count > 0:
                    individual_scores.append(score / count)
                else:
                    individual_scores.append(0.5)

            # Compromise score is the minimum (worst-case) score
            # We want to maximize the minimum
            compromise_score = min(individual_scores) if individual_scores else 0.5
            scored.append((product, compromise_score))

        # Sort by compromise score
        scored.sort(key=lambda x: x[1], reverse=True)

        return scored[:limit]

    def get_blend_insights(
        self,
        db: Session,
        member_ids: List[int],
    ) -> Dict[str, any]:
        """Generate insights about the blend's group preferences.

        Args:
            db: Database session
            member_ids: List of blend member user IDs

        Returns:
            Dictionary with group insights
        """
        style_profiles = self._get_member_style_profiles(db, member_ids)
        group_style = self._compute_group_style_vector(style_profiles)

        # Top styles
        top_styles = sorted(
            group_style["style"].items(),
            key=lambda x: x[1],
            reverse=True
        )[:5]

        # Top colors
        top_colors = sorted(
            group_style["color"].items(),
            key=lambda x: x[1],
            reverse=True
        )[:5]

        # Style diversity (variance in preferences)
        style_variance = 0.0
        if len(style_profiles) > 1:
            style_scores_list = [
                list(profile.style_scores.values())
                for profile in style_profiles.values()
            ]
            # Simple variance metric
            if style_scores_list:
                avg_variance = np.mean([np.var(scores) for scores in style_scores_list])
                style_variance = avg_variance

        return {
            "member_count": len(member_ids),
            "top_styles": [{"style": s, "score": score} for s, score in top_styles],
            "top_colors": [{"color": c, "score": score} for c, score in top_colors],
            "style_diversity": style_variance,
            "group_coherence": 1.0 - min(style_variance, 1.0),
        }