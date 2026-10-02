"""Style DNA extraction and management.

Analyzes user interactions to extract fashion preferences and build
a dynamic Style DNA profile that evolves with user behavior.
"""

from __future__ import annotations

from typing import Dict, List, Optional
from datetime import datetime, timedelta
import logging
import numpy as np

from sqlalchemy.orm import Session
from sqlalchemy import func, and_

from ...models import Product, User
from ..models_ai import UserStyleProfile, InteractionEvent

logger = logging.getLogger(__name__)


class StyleDNAExtractor:
    """Extracts Style DNA from user interactions."""

    # Style categories to track
    STYLE_CATEGORIES = [
        "streetwear", "minimal", "classic", "boho", "casual",
        "formal", "sporty", "ethnic", "vintage", "modern"
    ]

    # Fit categories
    FIT_CATEGORIES = ["oversized", "relaxed", "slim", "regular", "athletic"]

    # Occasion categories
    OCCASION_CATEGORIES = [
        "casual", "formal", "sports", "party", "office",
        "date", "travel", "festival", "wedding"
    ]

    # Material categories
    MATERIAL_CATEGORIES = [
        "cotton", "denim", "polyester", "linen", "silk",
        "wool", "leather", "velvet", "chiffon"
    ]

    def __init__(self, decay_days: int = 90):
        """Initialize extractor.

        Args:
            decay_days: Number of days for interaction decay
        """
        self.decay_days = decay_days

    def create_initial_profile_from_onboarding(
        self,
        aesthetic: str,
        colors: List[str],
        fit: str,
        occasion: str,
        preferences: List[str],
    ) -> Dict[str, float]:
        """Create initial Style DNA scores from user onboarding preferences.
        
        Converts the user's explicit onboarding choices into a normalized
        style score dictionary that matches the format from interaction-based
        extraction, so the profile can evolve naturally over time.
        
        Args:
            aesthetic: User's primary style aesthetic
            colors: List of preferred color palettes
            fit: User's preferred garment fit
            occasion: Primary occasion they shop for
            preferences: Additional preference flags
        
        Returns:
            Dictionary of normalized style scores
        """
        # Initialize scores with base values
        style_scores = {s: 0.1 for s in self.STYLE_CATEGORIES}
        
        # Boost the selected aesthetic significantly
        aesthetic_mapping = {
            "minimal": "minimal",
            "streetwear": "streetwear", 
            "classic": "classic",
            "y2k": "vintage",
            "boho": "boho",
            "old_money": "classic",
            "sporty": "sporty",
            "edgy": "modern",
            "feminine": "modern",
            "casual": "casual"
        }
        
        # Apply main aesthetic boost
        if aesthetic in aesthetic_mapping:
            style_key = aesthetic_mapping[aesthetic]
            if style_key in style_scores:
                style_scores[style_key] += 0.8  # Primary aesthetic gets highest score
        
        # Add boosts for related aesthetics based on preferences
        if "prefer_trends" in preferences:
            style_scores["modern"] += 0.3
        if "prefer_timeless" in preferences:
            style_scores["classic"] += 0.3
        if "prefer_statement_pieces" in preferences:
            style_scores["vintage"] += 0.2
        
        # Normalize scores to 0-1 range
        max_score = max(style_scores.values())
        if max_score > 0:
            normalized_scores = {k: v / max_score for k, v in style_scores.items()}
        else:
            normalized_scores = style_scores
        
        # Add additional metadata scores for colors, fit, occasion
        color_scores = {color: 0.9 for color in colors}
        fit_scores = {f: 0.1 for f in self.FIT_CATEGORIES}
        if fit in fit_scores:
            fit_scores[fit] = 0.9
        
        occasion_scores = {o: 0.1 for o in self.OCCASION_CATEGORIES}
        occasion_mapping = {
            "college": "casual",
            "work": "office", 
            "casual": "casual",
            "party": "party",
            "travel": "travel",
            "date_night": "date",
            "formal": "formal"
        }
        if occasion in occasion_mapping:
            occasion_key = occasion_mapping[occasion]
            if occasion_key in occasion_scores:
                occasion_scores[occasion_key] = 0.9
        
        # Combine all into a single style_dna dictionary that matches interaction-based format
        full_dna = {}
        # Add normalized style scores
        for k, v in normalized_scores.items():
            full_dna[f"style_{k}"] = v
        # Add color scores
        for k, v in color_scores.items():
            full_dna[f"color_{k}"] = v
        # Add fit scores
        for k, v in fit_scores.items():
            full_dna[f"fit_{k}"] = v
        # Add occasion scores
        for k, v in occasion_scores.items():
            full_dna[f"occasion_{k}"] = v
        # Add preference flags as metadata scores
        for pref in preferences:
            full_dna[f"preference_{pref}"] = 1.0
            
        return full_dna

    def _get_weighted_interactions(
        self,
        db: Session,
        user_id: int,
    ) -> List[InteractionEvent]:
        """Get recent interactions with time-based weighting.

        More recent interactions have higher weight.

        Args:
            db: Database session
            user_id: User ID

        Returns:
            List of weighted interactions
        """
        cutoff_date = datetime.utcnow() - timedelta(days=self.decay_days)

        interactions = db.query(InteractionEvent).filter(
            InteractionEvent.user_id == user_id,
            InteractionEvent.created_at >= cutoff_date,
            InteractionEvent.entity_type == "product",
        ).all()

        # Apply time decay
        weighted = []
        for interaction in interactions:
            days_ago = (datetime.utcnow() - interaction.created_at).days
            weight = np.exp(-days_ago / 30.0)  # 30-day half-life
            weighted.append((interaction, weight))

        return weighted

    def _extract_from_product(
        self,
        product: Product,
        weight: float,
    ) -> Dict[str, float]:
        """Extract style signals from a product.

        Args:
            product: Product instance
            weight: Interaction weight

        Returns:
            Dictionary of style signals
        """
        signals = {}

        # Style category
        if product.style:
            style_key = product.style.lower()
            signals[f"style_{style_key}"] = weight

        # Fit
        if product.fit:
            fit_key = product.fit.lower()
            signals[f"fit_{fit_key}"] = weight

        # Occasion
        if product.occasion:
            occasion_key = product.occasion.lower()
            signals[f"occasion_{occasion_key}"] = weight

        # Material
        if product.material:
            material_key = product.material.lower()
            signals[f"material_{material_key}"] = weight

        # Color
        if product.color:
            color_key = product.color.lower()
            signals[f"color_{color_key}"] = weight

        # Category
        if product.category:
            category_key = product.category.name.lower()
            signals[f"category_{category_key}"] = weight

        # Brand
        if product.brand:
            brand_key = product.brand.name.lower()
            signals[f"brand_{brand_key}"] = weight

        return signals

    def extract_style_dna(
        self,
        db: Session,
        user_id: int,
    ) -> UserStyleProfile:
        """Extract Style DNA from user interactions.

        Args:
            db: Database session
            user_id: User ID

        Returns:
            UserStyleProfile instance
        """
        weighted_interactions = self._get_weighted_interactions(db, user_id)

        # Initialize accumulators
        style_scores = {s: 0.0 for s in self.STYLE_CATEGORIES}
        color_scores: Dict[str, float] = {}
        fit_scores = {f: 0.0 for f in self.FIT_CATEGORIES}
        brand_scores: Dict[str, float] = {}
        category_scores: Dict[str, float] = {}
        occasion_scores = {o: 0.0 for o in self.OCCASION_CATEGORIES}
        material_scores = {m: 0.0 for m in self.MATERIAL_CATEGORIES}

        total_weight = 0.0

        # Process interactions
        for interaction, weight in weighted_interactions:
            if interaction.entity_id:
                product = db.query(Product).filter(
                    Product.id == interaction.entity_id
                ).first()

                if product:
                    signals = self._extract_from_product(product, weight)

                    # Accumulate signals
                    for key, value in signals.items():
                        if key.startswith("style_"):
                            style = key.replace("style_", "")
                            if style in style_scores:
                                style_scores[style] += value
                        elif key.startswith("color_"):
                            color = key.replace("color_", "")
                            color_scores[color] = color_scores.get(color, 0) + value
                        elif key.startswith("fit_"):
                            fit = key.replace("fit_", "")
                            if fit in fit_scores:
                                fit_scores[fit] += value
                        elif key.startswith("brand_"):
                            brand = key.replace("brand_", "")
                            brand_scores[brand] = brand_scores.get(brand, 0) + value
                        elif key.startswith("category_"):
                            category = key.replace("category_", "")
                            category_scores[category] = category_scores.get(category, 0) + value
                        elif key.startswith("occasion_"):
                            occasion = key.replace("occasion_", "")
                            if occasion in occasion_scores:
                                occasion_scores[occasion] += value
                        elif key.startswith("material_"):
                            material = key.replace("material_", "")
                            if material in material_scores:
                                material_scores[material] += value

                    total_weight += weight

        # Normalize scores
        def normalize(scores: Dict[str, float]) -> Dict[str, float]:
            if not scores:
                return {}
            max_val = max(scores.values()) if scores else 1.0
            if max_val == 0:
                return {k: 0.0 for k in scores}
            return {k: v / max_val for k, v in scores.items()}

        style_scores = normalize(style_scores)
        fit_scores = normalize(fit_scores)
        occasion_scores = normalize(occasion_scores)
        material_scores = normalize(material_scores)
        color_scores = normalize(color_scores)
        brand_scores = normalize(brand_scores)
        category_scores = normalize(category_scores)

        # Calculate confidence based on interaction count
        interaction_count = len(weighted_interactions)
        confidence = min(interaction_count / 50.0, 1.0)  # Saturates at 50 interactions

        # Estimate price sensitivity from interaction context
        price_sensitivity = 0.5  # Default
        if weighted_interactions:
            # Look at price ranges of interacted products
            prices = []
            for interaction, _ in weighted_interactions:
                if interaction.entity_id:
                    product = db.query(Product).filter(
                        Product.id == interaction.entity_id
                    ).first()
                    if product:
                        prices.append(product.price)

            if prices:
                avg_price = np.mean(prices)
                # Higher average price = lower price sensitivity
                price_sensitivity = max(0.0, min(1.0, 1.0 - (avg_price / 5000.0)))

        # Get or create profile
        profile = db.query(UserStyleProfile).filter(
            UserStyleProfile.user_id == user_id
        ).first()

        if not profile:
            profile = UserStyleProfile(user_id=user_id)
            db.add(profile)

        # Update profile
        profile.style_scores = style_scores
        profile.color_scores = color_scores
        profile.fit_scores = fit_scores
        profile.brand_scores = brand_scores
        profile.category_scores = category_scores
        profile.occasion_scores = occasion_scores
        profile.material_scores = material_scores
        profile.price_sensitivity = price_sensitivity
        profile.confidence = confidence
        profile.interaction_count = interaction_count

        db.commit()

        logger.info(f"Updated Style DNA for user {user_id}: {interaction_count} interactions, confidence={confidence:.2f}")

        return profile

    def get_style_explanation(
        self,
        profile: UserStyleProfile,
    ) -> str:
        """Generate human-readable explanation of Style DNA.

        Args:
            profile: UserStyleProfile instance

        Returns:
            Natural language explanation
        """
        # Top styles
        top_styles = sorted(
            profile.style_scores.items(),
            key=lambda x: x[1],
            reverse=True
        )[:3]

        # Top colors
        top_colors = sorted(
            profile.color_scores.items(),
            key=lambda x: x[1],
            reverse=True
        )[:3]

        # Top fits
        top_fits = sorted(
            profile.fit_scores.items(),
            key=lambda x: x[1],
            reverse=True
        )[:2]

        parts = []

        if top_styles and top_styles[0][1] > 0.5:
            style_names = [s for s, score in top_styles if score > 0.3]
            if style_names:
                parts.append(f"You lean towards {', '.join(style_names)} fashion")

        if top_colors and top_colors[0][1] > 0.5:
            color_names = [c for c, score in top_colors if score > 0.3]
            if color_names:
                parts.append(f"You prefer {', '.join(color_names)} colors")

        if top_fits and top_fits[0][1] > 0.5:
            fit_names = [f for f, score in top_fits if score > 0.3]
            if fit_names:
                parts.append(f"You like {', '.join(fit_names)} fits")

        if profile.price_sensitivity > 0.7:
            parts.append("You're budget-conscious")
        elif profile.price_sensitivity < 0.3:
            parts.append("You're open to premium items")

        if not parts:
            return "Your style profile is still learning from your interactons."

        return ". ".join(parts) + "."