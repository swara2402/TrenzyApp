"""Blend ML model inference pipeline.

Computes group preference scores using FashionCLIP embeddings and trained model.
"""

from __future__ import annotations

import logging
from typing import List, Tuple, Optional, Dict
import numpy as np

from sqlalchemy.orm import Session

from ...models import Product, User
from ..models_ai import ProductEmbedding, UserStyleProfile, InteractionEvent
from .blend_loader import BlendModelLoader
from .blend_trainer import BlendModelTrainer

logger = logging.getLogger(__name__)


class BlendInference:
    """Production inference pipeline for blend recommendations."""

    def __init__(
        self,
        model_loader: Optional[BlendModelLoader] = None,
        fallback_to_aggregation: bool = True,
    ):
        """Initialize inference pipeline.

        Args:
            model_loader: Model loader instance
            fallback_to_aggregation: Whether to use aggregation fallback if model unavailable
        """
        self.model_loader = model_loader or BlendModelLoader()
        self.fallback_to_aggregation = fallback_to_aggregation
        self.trainer = BlendModelTrainer()

    def compute_group_preference(
        self,
        db: Session,
        user_ids: List[int],
        product_id: int,
    ) -> Tuple[float, Optional[str], str]:
        """Compute group preference score for a product.

        Returns a 3-tuple: ``(preference_score, model_version, source)`` where
        ``source`` is one of ``"ml"``, ``"aggregation"``, ``"default"``.

        Args:
            db: Database session
            user_ids: List of user IDs in the blend
            product_id: Product ID to evaluate

        Returns:
            ``(preference_score, model_version, source)``
        """
        # Load model if not loaded
        if not self.model_loader.is_loaded():
            self.model_loader.load_model()

        # Build feature vector
        feature_vector = self._build_group_features(db, user_ids, product_id)

        if self.model_loader.is_loaded():
            # Use ML model
            score = self.model_loader.predict_group_preference(feature_vector)
            return score, self.model_loader.get_version(), "ml"
        elif self.fallback_to_aggregation:
            # Use aggregation fallback
            score = self._aggregate_preferences(db, user_ids, product_id)
            return score, None, "aggregation"
        else:
            # Return default
            return 0.5, None, "default"

    def _build_group_features(
        self,
        db: Session,
        user_ids: List[int],
        product_id: int,
    ) -> np.ndarray:
        """Build feature vector for group-product pair.

        Args:
            db: Database session
            user_ids: List of user IDs in the blend
            product_id: Product ID to evaluate

        Returns:
            Feature vector
        """
        features = []

        # Get product embedding
        product_emb = db.query(ProductEmbedding).filter(
            ProductEmbedding.product_id == product_id,
            ProductEmbedding.combined_embedding.isnot(None),
        ).first()

        if product_emb:
            features.extend(product_emb.combined_embedding[:128])
        else:
            features.extend([0.0] * 128)

        # Get user style profiles
        user_profiles = db.query(UserStyleProfile).filter(
            UserStyleProfile.user_id.in_(user_ids)
        ).all()

        # Aggregate style scores
        style_categories = ["streetwear", "minimal", "classic", "boho", "casual",
                          "formal", "sporty", "ethnic", "vintage", "modern"]

        for style in style_categories:
            avg_style = 0.0
            if user_profiles:
                style_values = [p.style_scores.get(style, 0.0) for p in user_profiles]
                avg_style = np.mean(style_values) if style_values else 0.0
            features.append(avg_style)

        # Group size
        features.append(float(len(user_ids)))

        # Group diversity (style diversity)
        if user_profiles:
            style_vectors = [list(p.style_scores.values()) for p in user_profiles]
            diversity = np.std(style_vectors, axis=0).mean() if style_vectors else 0.0
            features.append(diversity)
        else:
            features.append(0.0)

        return np.array(features)

    def _aggregate_preferences(
        self,
        db: Session,
        user_ids: List[int],
        product_id: int,
    ) -> float:
        """Aggregate individual preferences (fallback).

        Args:
            db: Database session
            user_ids: List of user IDs in the blend
            product_id: Product ID to evaluate

        Returns:
            Aggregated preference score (0-1)
        """
        if not user_ids:
            return 0.5

        # Get individual preferences from interactions
        preferences = []

        for user_id in user_ids:
            # Check if user liked this product
            liked = db.query(InteractionEvent).filter(
                InteractionEvent.user_id == user_id,
                InteractionEvent.entity_id == product_id,
                InteractionEvent.entity_type == "product",
                InteractionEvent.event_type == "like_product",
            ).first()

            if liked:
                preferences.append(1.0)
            else:
                # Check similar products
                preferences.append(0.5)

        return np.mean(preferences) if preferences else 0.5

    def get_blend_recommendations(
        self,
        db: Session,
        user_ids: List[int],
        limit: int = 20,
        exclude_product_ids: Optional[List[int]] = None,
    ) -> List[Tuple[Product, float, Optional[str], str]]:
        """Get blend recommendations for a group.

        Args:
            db: Database session
            user_ids: List of user IDs in the blend
            limit: Number of recommendations
            exclude_product_ids: Product IDs to exclude

        Returns:
            List of (product, score, model_version, source) tuples
        """
        # Get candidate products
        from ...models import Product
        query = db.query(Product).filter(Product.is_active == True)

        if exclude_product_ids:
            query = query.filter(~Product.id.in_(exclude_product_ids))

        candidates = query.limit(limit * 5).all()

        # Score candidates
        scored_products = []

        for product in candidates:
            score, model_version, source = self.compute_group_preference(
                db, user_ids, product.id
            )
            scored_products.append((product, score, model_version, source))

        # Sort by score
        scored_products.sort(key=lambda x: x[1], reverse=True)

        return scored_products[:limit]
