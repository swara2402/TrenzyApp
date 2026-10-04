"""Outfit compatibility inference pipeline.

Computes outfit compatibility scores using FashionCLIP embeddings and trained model.
"""

from __future__ import annotations

import logging
from typing import List, Tuple, Optional, Dict
import numpy as np

from sqlalchemy.orm import Session

from ...models import Product
from ..models_ai import ProductEmbedding
from .compatibility_loader import OutfitCompatibilityModelLoader
from .compatibility_trainer import OutfitCompatibilityTrainer

logger = logging.getLogger(__name__)


class OutfitCompatibilityInference:
    """Production inference pipeline for outfit compatibility."""

    def __init__(
        self,
        model_loader: Optional[OutfitCompatibilityModelLoader] = None,
        fallback_to_rules: bool = True,
    ):
        """Initialize inference pipeline.

        Args:
            model_loader: Model loader instance
            fallback_to_rules: Whether to use rule-based fallback if model unavailable
        """
        self.model_loader = model_loader or OutfitCompatibilityModelLoader()
        self.fallback_to_rules = fallback_to_rules
        self.trainer = OutfitCompatibilityTrainer()

    def compute_compatibility(
        self,
        db: Session,
        products: List[Product],
    ) -> Tuple[float, Optional[str], str]:
        """Compute compatibility score for an outfit.

        Returns a 3-tuple: ``(compatibility_score, model_version, source)`` where
        ``source`` is one of ``"ml"``, ``"rules"``, ``"default"``.

        Args:
            db: Database session
            products: List of products in the outfit

        Returns:
            ``(compatibility_score, model_version, source)``
        """
        # Load model if not loaded
        if not self.model_loader.is_loaded():
            self.model_loader.load_model()

        # Build feature vector
        feature_vector = self._build_outfit_features(db, products)

        if self.model_loader.is_loaded():
            # Use ML model
            score = self.model_loader.predict_compatibility(feature_vector)
            return score, self.model_loader.get_version(), "ml"
        elif self.fallback_to_rules:
            # Use rule-based fallback
            score = self._rule_based_compatibility(products)
            return score, None, "rules"
        else:
            # Return default
            return 0.5, None, "default"

    def _build_outfit_features(
        self,
        db: Session,
        products: List[Product],
    ) -> np.ndarray:
        """Build feature vector for an outfit.

        Args:
            db: Database session
            products: List of products in the outfit

        Returns:
            Feature vector
        """
        features = []

        # Get product embeddings
        product_ids = [p.id for p in products]
        product_embeddings = db.query(ProductEmbedding).filter(
            ProductEmbedding.product_id.in_(product_ids),
            ProductEmbedding.combined_embedding.isnot(None),
        ).all()

        emb_map = {pe.product_id: np.array(pe.combined_embedding) for pe in product_embeddings}

        # Only use products with valid embeddings - never use zero vectors
        valid_embeddings = []
        for p in products:
            if p.id in emb_map:
                valid_embeddings.append(emb_map[p.id])
        
        if valid_embeddings:
            avg_embedding = np.mean(valid_embeddings, axis=0)
            features.extend(avg_embedding[:128])  # First 128 dimensions
        else:
            # No valid embeddings available - cannot compute compatibility
            logger.warning("No valid product embeddings found for outfit compatibility calculation")
            # Fill with NaN to indicate missing data instead of zero vector
            features.extend([np.nan] * 128)

        # Style coherence
        styles = [p.style for p in products if p.style]
        style_diversity = len(set(styles)) / len(styles) if styles else 0.0
        features.append(style_diversity)

        # Color harmony
        colors = [p.color for p in products if p.color]
        color_diversity = len(set(colors)) / len(colors) if colors else 0.0
        features.append(color_diversity)

        # Occasion match
        occasions = [p.occasion for p in products if p.occasion]
        occasion_match = 1.0 if len(set(occasions)) <= 1 else 0.0
        features.append(occasion_match)

        # Fit compatibility
        fits = [p.fit for p in products if p.fit]
        fit_compatibility = 1.0 if len(set(fits)) <= 2 else 0.0
        features.append(fit_compatibility)

        return np.array(features)

    def _rule_based_compatibility(
        self,
        products: List[Product],
    ) -> float:
        """Calculate compatibility using rule-based logic.

        Args:
            products: List of products in the outfit

        Returns:
            Compatibility score (0-1)
        """
        if not products:
            return 0.0

        score = 0.0

        # Style coherence
        styles = [p.style for p in products if p.style]
        if styles:
            style_diversity = len(set(styles)) / len(styles)
            score += (1.0 - style_diversity) * 0.3

        # Color harmony
        colors = [p.color for p in products if p.color]
        if colors:
            color_diversity = len(set(colors)) / len(colors)
            score += (1.0 - color_diversity) * 0.2

        # Occasion match
        occasions = [p.occasion for p in products if p.occasion]
        if occasions:
            occasion_match = 1.0 if len(set(occasions)) <= 1 else 0.0
            score += occasion_match * 0.3

        # Fit compatibility
        fits = [p.fit for p in products if p.fit]
        if fits:
            fit_compatibility = 1.0 if len(set(fits)) <= 2 else 0.0
            score += fit_compatibility * 0.2

        return min(score, 1.0)

    def rank_outfits(
        self,
        db: Session,
        outfit_options: List[List[Product]],
        limit: int = 10,
    ) -> List[Tuple[List[Product], float, Optional[str], str]]:
        """Rank multiple outfit options by compatibility.

        Args:
            db: Database session
            outfit_options: List of outfit options (each is a list of products)
            limit: Maximum number of outfits to return

        Returns:
            List of (outfit, score, model_version, source) tuples
        """
        scored_outfits = []

        for outfit in outfit_options:
            score, model_version, source = self.compute_compatibility(db, outfit)
            scored_outfits.append((outfit, score, model_version, source))

        # Sort by score
        scored_outfits.sort(key=lambda x: x[1], reverse=True)

        return scored_outfits[:limit]