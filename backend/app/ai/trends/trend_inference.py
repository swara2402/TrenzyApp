"""Trend prediction inference pipeline.

Computes trend scores using FashionCLIP embeddings and trained model.
"""

from __future__ import annotations

import logging
from typing import List, Tuple, Optional, Dict
import numpy as np
from datetime import datetime, timedelta

from sqlalchemy.orm import Session
from sqlalchemy import func

from ...models import Product
from ..models_ai import ProductEmbedding, InteractionEvent
from .trend_loader import TrendModelLoader
from .trend_trainer import TrendModelTrainer

logger = logging.getLogger(__name__)


class TrendInference:
    """Production inference pipeline for trend prediction."""

    def __init__(
        self,
        model_loader: Optional[TrendModelLoader] = None,
        fallback_to_popularity: bool = True,
    ):
        """Initialize inference pipeline.

        Args:
            model_loader: Model loader instance
            fallback_to_popularity: Whether to use popularity fallback if model unavailable
        """
        self.model_loader = model_loader or TrendModelLoader()
        self.fallback_to_popularity = fallback_to_popularity
        self.trainer = TrendModelTrainer()

    def compute_trend_score(
        self,
        db: Session,
        product_id: int,
    ) -> Tuple[float, Optional[str], str]:
        """Compute trend score for a product.

        Returns a 3-tuple: ``(trend_score, model_version, source)`` where
        ``source`` is one of ``"ml"``, ``"popularity"``, ``"default"``.

        Args:
            db: Database session
            product_id: Product ID to evaluate

        Returns:
            ``(trend_score, model_version, source)``
        """
        # Load model if not loaded
        if not self.model_loader.is_loaded():
            self.model_loader.load_model()

        # Build feature vector
        feature_vector = self._build_trend_features(db, product_id)

        if self.model_loader.is_loaded():
            # Use ML model
            score = self.model_loader.predict_trend_score(feature_vector)
            return score, self.model_loader.get_version(), "ml"
        elif self.fallback_to_popularity:
            # Use popularity fallback
            score = self._popularity_score(db, product_id)
            return score, None, "popularity"
        else:
            # Return default
            return 0.5, None, "default"

    def _build_trend_features(
        self,
        db: Session,
        product_id: int,
    ) -> np.ndarray:
        """Build feature vector for trend prediction.

        Args:
            db: Database session
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

        # Get product
        product = db.query(Product).filter(Product.id == product_id).first()

        if product:
            # Recent interaction count (last 7 days)
            week_ago = datetime.utcnow() - timedelta(days=7)
            recent_views = db.query(func.count(InteractionEvent.id)).filter(
                InteractionEvent.entity_id == product_id,
                InteractionEvent.entity_type == "product",
                InteractionEvent.event_type == "view_product",
                InteractionEvent.created_at >= week_ago,
            ).scalar() or 0

            recent_likes = db.query(func.count(InteractionEvent.id)).filter(
                InteractionEvent.entity_id == product_id,
                InteractionEvent.entity_type == "product",
                InteractionEvent.event_type.in_(["like_product", "wishlist"]),
                InteractionEvent.created_at >= week_ago,
            ).scalar() or 0

            features.append(float(recent_views))
            features.append(float(recent_likes))

            # Product age
            if product.created_at:
                age_days = (datetime.utcnow() - product.created_at).days
                features.append(float(age_days))
            else:
                features.append(0.0)

            # Price
            features.append(float(product.price) if product.price else 0.0)

            # Rating
            features.append(float(product.rating) if product.rating else 0.0)
        else:
            features.extend([0.0] * 6)

        return np.array(features)

    def _popularity_score(
        self,
        db: Session,
        product_id: int,
    ) -> float:
        """Calculate popularity score (fallback).

        Args:
            db: Database session
            product_id: Product ID to evaluate

        Returns:
            Popularity score (0-1)
        """
        # Get product
        product = db.query(Product).filter(Product.id == product_id).first()

        if not product:
            return 0.0

        # Recent interaction count (last 7 days)
        week_ago = datetime.utcnow() - timedelta(days=7)
        recent_views = db.query(func.count(InteractionEvent.id)).filter(
            InteractionEvent.entity_id == product_id,
            InteractionEvent.entity_type == "product",
            InteractionEvent.event_type == "view_product",
            InteractionEvent.created_at >= week_ago,
        ).scalar() or 0

        recent_likes = db.query(func.count(InteractionEvent.id)).filter(
            InteractionEvent.entity_id == product_id,
            InteractionEvent.entity_type == "product",
            InteractionEvent.event_type.in_(["like_product", "wishlist"]),
            InteractionEvent.created_at >= week_ago,
        ).scalar() or 0

        # Normalize to 0-1
        score = min((recent_views + recent_likes * 2) / 100.0, 1.0)

        return score

    def get_trending_products(
        self,
        db: Session,
        limit: int = 20,
        category: Optional[str] = None,
        style: Optional[str] = None,
    ) -> List[Tuple[Product, float, Optional[str], str]]:
        """Get trending products.

        Args:
            db: Database session
            limit: Number of products
            category: Optional category filter
            style: Optional style filter

        Returns:
            List of (product, score, model_version, source) tuples
        """
        # Get candidate products
        query = db.query(Product).filter(Product.is_active == True)

        if category:
            query = query.filter(Product.category == category)
        if style:
            query = query.filter(Product.style == style)

        candidates = query.limit(limit * 5).all()

        # Score candidates
        scored_products = []

        for product in candidates:
            score, model_version, source = self.compute_trend_score(db, product.id)
            scored_products.append((product, score, model_version, source))

        # Sort by score
        scored_products.sort(key=lambda x: x[1], reverse=True)

        return scored_products[:limit]
