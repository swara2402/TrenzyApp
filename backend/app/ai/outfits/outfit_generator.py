"""AI Outfit Builder with compatibility scoring.

Generates outfit combinations based on:
- User Style DNA
- Outfit composition rules
- Color compatibility
- Style coherence
- Occasion appropriateness
- FashionCLIP embedding similarity (beta-ready requirement)
"""

from __future__ import annotations

from typing import List, Dict, Optional, Tuple
from itertools import product
import logging
import numpy as np

from sqlalchemy.orm import Session
from sqlalchemy import and_

from ...models import Product, User
from ..models_ai import UserStyleProfile, OutfitGeneration, ProductEmbedding
from ..recommendation.rule_based_recommender import RuleBasedRecommender
from ..vision.embedding_service import get_embedding_service

logger = logging.getLogger(__name__)


class OutfitCompatibilityScorer:
    """Scores outfit compatibility between items."""

    # Color harmony rules (complementary, analogous, etc.)
    COLOR_HARMONY = {
        "black": ["white", "gray", "navy", "red", "yellow"],
        "white": ["black", "gray", "blue", "red", "green"],
        "navy": ["white", "beige", "gray", "red", "yellow"],
        "gray": ["black", "white", "navy", "pink", "yellow"],
        "beige": ["navy", "black", "brown", "white", "olive"],
        "brown": ["beige", "white", "cream", "orange", "green"],
        "red": ["black", "white", "gray", "navy", "beige"],
        "blue": ["white", "gray", "navy", "yellow", "orange"],
        "green": ["white", "beige", "brown", "navy", "red"],
    }

    # Style coherence rules
    STYLE_COHERENCE = {
        "casual": ["casual", "streetwear"],
        "formal": ["formal", "classic"],
        "streetwear": ["casual", "streetwear", "sporty"],
        "sporty": ["casual", "sporty", "streetwear"],
        "boho": ["boho", "casual"],
        "classic": ["formal", "classic", "casual"],
    }

    def __init__(self):
        """Initialize the rule-based scorer without downloading ML weights."""
        self._embedding_service = None
    
    def _fashionclip_similarity(self, db: Session, item1: Product, item2: Product) -> float:
        """Compute FashionCLIP cosine similarity between two product embeddings.

        Args:
            db: Database session
            item1: First product
            item2: Second product

        Returns:
            Similarity score (0-1, normalized from cosine [-1,1])
        """
        # Catalog import stores canonical FashionCLIP vectors directly on
        # Product.image_embedding_vector. Prefer those vectors so outfit
        # compatibility uses the same embeddings as visual search.
        emb1 = (
            np.asarray(item1.image_embedding_vector, dtype=np.float32)
            if item1.image_embedding_vector is not None
            else None
        )
        emb2 = (
            np.asarray(item2.image_embedding_vector, dtype=np.float32)
            if item2.image_embedding_vector is not None
            else None
        )

        # Backward-compatible fallback for older rows stored in ProductEmbedding.
        if emb1 is None or emb2 is None:
            if self._embedding_service is None:
                self._embedding_service = get_embedding_service()
            if emb1 is None:
                emb1 = self._embedding_service.get_product_embedding(db, item1.id)
            if emb2 is None:
                emb2 = self._embedding_service.get_product_embedding(db, item2.id)

        # If either embedding is genuinely missing, use a neutral score.
        if emb1 is None or emb2 is None:
            logger.warning("Missing FashionCLIP embedding for outfit item - using neutral similarity")
            return 0.5
        
        # Compute cosine similarity (dot product since embeddings are already L2-normalized)
        cosine_sim = np.dot(emb1, emb2)
        
        # Normalize from [-1,1] to [0,1] for compatibility with other scores
        normalized_sim = (cosine_sim + 1) / 2
        logger.debug(f"FashionCLIP similarity between {item1.id} and {item2.id}: {normalized_sim:.3f}")
        
        return float(normalized_sim)

    def _color_compatibility(self, color1: str, color2: str) -> float:
        """Compute color compatibility score.

        Args:
            color1: First color
            color2: Second color

        Returns:
            Compatibility score (0-1)
        """
        if not color1 or not color2:
            return 0.5

        c1 = color1.lower()
        c2 = color2.lower()

        # Same color
        if c1 == c2:
            return 0.7  # Monochromatic is okay but not ideal

        # Check harmony
        if c1 in self.COLOR_HARMONY:
            if c2 in self.COLOR_HARMONY[c1]:
                return 1.0

        # Neutral colors work with most things
        neutrals = ["black", "white", "gray", "beige", "cream", "navy"]
        if c1 in neutrals or c2 in neutrals:
            return 0.9

        return 0.5  # Unknown combination

    def _style_coherence(self, style1: str, style2: str) -> float:
        """Compute style coherence score.

        Args:
            style1: First style
            style2: Second style

        Returns:
            Coherence score (0-1)
        """
        if not style1 or not style2:
            return 0.5

        s1 = style1.lower()
        s2 = style2.lower()

        if s1 == s2:
            return 1.0

        if s1 in self.STYLE_COHERENCE:
            if s2 in self.STYLE_COHERENCE[s1]:
                return 0.8

        return 0.4

    def _occasion_match(self, item1: Product, item2: Product) -> float:
        """Check if items match for the same occasion.

        Args:
            item1: First product
            item2: Second product

        Returns:
            Match score (0-1)
        """
        if not item1.occasion or not item2.occasion:
            return 0.5

        if item1.occasion.lower() == item2.occasion.lower():
            return 1.0

        # Some occasions are compatible
        compatible = {
            "casual": ["casual", "streetwear"],
            "formal": ["formal", "office"],
            "office": ["formal", "office", "casual"],
        }

        o1 = item1.occasion.lower()
        o2 = item2.occasion.lower()

        if o1 in compatible:
            if o2 in compatible[o1]:
                return 0.7

        return 0.3

    def score_pair(
        self,
        db: Session,
        item1: Product,
        item2: Product,
    ) -> float:
        """Score compatibility between two items.

        Args:
            db: Database session
            item1: First product
            item2: Second product

        Returns:
            Compatibility score (0-1)
        """
        scores = []

        # Color compatibility
        color_score = self._color_compatibility(item1.color or "", item2.color or "")
        scores.append(color_score)

        # Style coherence
        style_score = self._style_coherence(item1.style or "", item2.style or "")
        scores.append(style_score)

        # Occasion match
        occasion_score = self._occasion_match(item1, item2)
        scores.append(occasion_score)
        
        # FashionCLIP embedding similarity (beta-ready requirement)
        fashionclip_score = self._fashionclip_similarity(db, item1, item2)
        scores.append(fashionclip_score)

        return np.mean(scores)

    def score_outfit(
        self,
        db: Session,
        items: List[Product],
    ) -> float:
        """Score overall outfit compatibility.

        Args:
            db: Database session
            items: List of products in the outfit

        Returns:
            Overall compatibility score (0-1)
        """
        if len(items) < 2:
            return 1.0

        pair_scores = []
        for i in range(len(items)):
            for j in range(i + 1, len(items)):
                pair_scores.append(self.score_pair(db, items[i], items[j]))

        return np.mean(pair_scores)


class AIOutfitBuilder:
    """AI-powered outfit builder."""

    OUTFIT_ROLES = ["upper", "bottom", "footwear", "outerwear", "accessory"]

    def __init__(
        self,
        compatibility_scorer: Optional[OutfitCompatibilityScorer] = None,
    ):
        """Initialize outfit builder.

        Args:
            compatibility_scorer: Compatibility scorer instance
        """
        self.compatibility_scorer = compatibility_scorer or OutfitCompatibilityScorer()
        self.recommender = RuleBasedRecommender()

    def _get_candidates_by_role(
        self,
        db: Session,
        user_id: int,
        role: str,
        context: Optional[Dict[str, any]] = None,
        limit: int = 10,
    ) -> List[Product]:
        """Get candidate products for a specific outfit role.

        Args:
            db: Database session
            user_id: User ID
            role: Outfit role (upper, bottom, etc.)
            context: Request context
            limit: Number of candidates

        Returns:
            List of candidate products
        """
        query = db.query(Product).filter(
            Product.is_active == True,
            Product.outfit_role == role,
        )

        if context and "max_price" in context:
            query = query.filter(Product.price <= context["max_price"])

        candidates = query.limit(limit * 2).all()

        # Score and rank candidates
        scored = []
        for product in candidates:
            score = self.recommender.compute_final_score(
                db=db,
                user_id=user_id,
                product=product,
                context=context,
            )
            scored.append((product, score))

        scored.sort(key=lambda x: x[1], reverse=True)

        return [p for p, s in scored[:limit]]

    def generate_outfit(
        self,
        db: Session,
        user_id: int,
        prompt: str,
        context: Optional[Dict[str, any]] = None,
        num_options: int = 3,
    ) -> List[Dict[str, any]]:
        """Generate outfit options based on prompt.

        Args:
            db: Database session
            user_id: User ID
            prompt: Natural language prompt (e.g., "casual college outfit")
            context: Additional context
            num_options: Number of outfit options to generate

        Returns:
            List of outfit options with scores and explanations
        """
        # Parse prompt for context hints
        if context is None:
            context = {}

        prompt_lower = prompt.lower()

        # Extract style from prompt
        styles = ["casual", "formal", "streetwear", "sporty", "boho", "classic"]
        for style in styles:
            if style in prompt_lower:
                context["style"] = style
                break

        # Extract occasion from prompt
        occasions = ["casual", "formal", "office", "date", "party", "travel"]
        for occasion in occasions:
            if occasion in prompt_lower:
                context["occasion"] = occasion
                break

        # Generate and rank real combinations deterministically. The previous
        # implementation sampled random combinations, which could return the
        # same outfit repeatedly and made beta behavior impossible to reproduce.
        upper_candidates = self._get_candidates_by_role(db, user_id, "upper", context)
        bottom_candidates = self._get_candidates_by_role(db, user_id, "bottom", context)
        footwear_candidates = self._get_candidates_by_role(db, user_id, "footwear", context)

        if not upper_candidates or not bottom_candidates or not footwear_candidates:
            return []

        ranked = []
        for items in product(upper_candidates, bottom_candidates, footwear_candidates):
            score = self.compatibility_scorer.score_outfit(db, list(items))
            ranked.append((float(score), list(items)))

        ranked.sort(
            key=lambda entry: (-entry[0], tuple(str(item.id) for item in entry[1]))
        )

        # Deduplicate by product ids and keep the strongest combinations.
        options = []
        seen: set[tuple[str, ...]] = set()
        for score, items in ranked:
            key = tuple(str(item.id) for item in items)
            if key in seen:
                continue
            seen.add(key)
            outfit_items = [
                {"product_id": p.id, "role": p.outfit_role}
                for p in items
            ]
            options.append({
                "items": outfit_items,
                "compatibility_score": score,
                "explanation": self._generate_explanation(
                    db, user_id, items, prompt
                ),
            })
            if len(options) >= num_options:
                break

        return options

    def _generate_explanation(
        self,
        db: Session,
        user_id: int,
        items: List[Product],
        prompt: str,
    ) -> str:
        """Generate explanation for outfit selection.

        Args:
            db: Database session
            user_id: User ID
            items: Selected products
            prompt: Original prompt

        Returns:
            Natural language explanation
        """
        style_profile = db.query(UserStyleProfile).filter(
            UserStyleProfile.user_id == user_id
        ).first()

        parts = []

        if style_profile:
            # Top style preference
            top_style = max(
                style_profile.style_scores.items(),
                key=lambda x: x[1]
            )
            if top_style[1] > 0.5:
                parts.append(
                    f"Based on your preference for {top_style[0]} style"
                )

            # Top fit preference
            top_fit = max(
                style_profile.fit_scores.items(),
                key=lambda x: x[1]
            )
            if top_fit[1] > 0.5:
                parts.append(f"and {top_fit[0]} fits")

        # Mention the prompt
        parts.append(f"I selected items that match your request for '{prompt}'")

        # Mention compatibility
        if len(items) >= 2:
            parts.append("with good color and style compatibility")

        if not parts:
            return "This outfit combines items that work well together for your request."

        return " ".join(parts) + "."

    def save_outfit_generation(
        self,
        db: Session,
        user_id: int,
        prompt: str,
        outfit_option: Dict[str, any],
        model_version: str = "v1.0",
    ) -> OutfitGeneration:
        """Save an outfit generation to database.

        Args:
            db: Database session
            user_id: User ID
            prompt: Generation prompt
            outfit_option: Outfit option with items and score
            model_version: Model version

        Returns:
            OutfitGeneration instance
        """
        generation = OutfitGeneration(
            user_id=user_id,
            prompt=prompt,
            outfit_items=outfit_option["items"],
            explanation=outfit_option.get("explanation"),
            compatibility_score=outfit_option["compatibility_score"],
            model_version=model_version,
        )

        db.add(generation)
        db.commit()

        return generation