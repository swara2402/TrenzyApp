"""Style DNA inference pipeline.

Computes user Style DNA using FashionCLIP embeddings and trained classifiers.
"""

from __future__ import annotations

import logging
from typing import Dict, Optional
import numpy as np

from sqlalchemy.orm import Session

from ...models import Product
from ..models_ai import UserStyleProfile, ProductEmbedding, InteractionEvent
from .style_dna_loader import StyleDNAModelLoader
from .style_dna_trainer import StyleDNATrainer

logger = logging.getLogger(__name__)


class StyleDNAInference:
    """Production inference pipeline for Style DNA."""

    STYLE_CATEGORIES = [
        "streetwear", "minimal", "classic", "boho", "casual",
        "formal", "sporty", "ethnic", "vintage", "modern"
    ]

    def __init__(
        self,
        model_loader: Optional[StyleDNAModelLoader] = None,
        fallback_to_aggregation: bool = True,
    ):
        """Initialize inference pipeline.

        Args:
            model_loader: Model loader instance
            fallback_to_aggregation: Whether to use aggregation fallback if model unavailable
        """
        self.model_loader = model_loader or StyleDNAModelLoader()
        self.fallback_to_aggregation = fallback_to_aggregation
        self.trainer = StyleDNATrainer()

    def compute_style_dna(
        self,
        db: Session,
        user_id: int,
    ) -> Tuple[Dict[str, float], Optional[str], str]:
        """Compute Style DNA for a user.

        Returns a 3-tuple: ``(style_scores, model_version, source)`` where
        ``source`` is one of ``"ml"``, ``"aggregation"``, ``"default"``.

        Args:
            db: Database session
            user_id: User ID

        Returns:
            ``(style_scores, model_version, source)``
        """
        # Load model if not loaded
        if not self.model_loader.is_loaded():
            self.model_loader.load_model()

        # Get user's product embeddings
        user_embeddings = self._get_user_product_embeddings(db, user_id)

        if len(user_embeddings) == 0:
            # New user: return default scores
            return {style: 0.1 for style in self.STYLE_CATEGORIES}, None, "default"

        # Compute aggregate representation
        style_vector = self._compute_style_representation(user_embeddings)

        if self.model_loader.is_loaded():
            # Use ML model
            style_scores = self.model_loader.predict_style_scores(style_vector)
            return style_scores, self.model_loader.get_version(), "ml"
        elif self.fallback_to_aggregation:
            # Use aggregation fallback
            style_scores = self._aggregate_from_products(db, user_id)
            return style_scores, None, "aggregation"
        else:
            # Return default
            return {style: 0.1 for style in self.STYLE_CATEGORIES}, None, "default"

    def _get_user_product_embeddings(
        self,
        db: Session,
        user_id: int,
        limit: int = 100,
    ) -> np.ndarray:
        """Get embeddings of products a user has interacted with positively.

        Args:
            db: Database session
            user_id: User ID
            limit: Number of products to consider

        Returns:
            Array of product embeddings
        """
        # Get positive interactions
        positive_events = db.query(InteractionEvent).filter(
            InteractionEvent.user_id == user_id,
            InteractionEvent.event_type.in_(["like_product", "wishlist", "purchase"]),
            InteractionEvent.entity_type == "product",
        ).order_by(InteractionEvent.created_at.desc()).limit(limit).all()

        if not positive_events:
            return np.array([])

        # Get product embeddings
        product_ids = [e.entity_id for e in positive_events if e.entity_id]
        product_embeddings = db.query(ProductEmbedding).filter(
            ProductEmbedding.product_id.in_(product_ids),
            ProductEmbedding.combined_embedding.isnot(None),
        ).all()

        if not product_embeddings:
            return np.array([])

        # Aggregate embeddings
        embeddings = []
        for pe in product_embeddings:
            if pe.combined_embedding:
                embeddings.append(np.array(pe.combined_embedding))

        return np.array(embeddings) if embeddings else np.array([])

    def _compute_style_representation(
        self,
        embeddings: np.ndarray,
    ) -> np.ndarray:
        """Compute aggregate style representation from product embeddings.

        Args:
            embeddings: Array of product embeddings

        Returns:
            Aggregate style vector
        """
        if len(embeddings) == 0:
            logger.warning("No embeddings available to aggregate for user style DNA")
            return None

        # Average the embeddings
        return np.mean(embeddings, axis=0)

    def _aggregate_from_products(
        self,
        db: Session,
        user_id: int,
    ) -> Dict[str, float]:
        """Aggregate style scores from product attributes (fallback).

        Args:
            db: Database session
            user_id: User ID

        Returns:
            Dictionary of style scores
        """
        # Get user's liked products
        positive_events = db.query(InteractionEvent).filter(
            InteractionEvent.user_id == user_id,
            InteractionEvent.event_type.in_(["like_product", "wishlist", "purchase"]),
            InteractionEvent.entity_type == "product",
        ).limit(100).all()

        if not positive_events:
            return {style: 0.1 for style in self.STYLE_CATEGORIES}

        # Get products
        product_ids = [e.entity_id for e in positive_events if e.entity_id]
        products = db.query(Product).filter(
            Product.id.in_(product_ids),
            Product.style.isnot(None),
        ).all()

        if not products:
            return {style: 0.1 for style in self.STYLE_CATEGORIES}

        # Count styles
        style_counts = {style: 0 for style in self.STYLE_CATEGORIES}
        for product in products:
            if product.style:
                style_lower = product.style.lower()
                if style_lower in style_counts:
                    style_counts[style_lower] += 1

        # Normalize
        total = sum(style_counts.values())
        if total > 0:
            style_scores = {k: v / total for k, v in style_counts.items()}
        else:
            style_scores = {style: 0.1 for style in self.STYLE_CATEGORIES}

        return style_scores

    def update_user_profile(
        self,
        db: Session,
        user_id: int,
    ) -> UserStyleProfile:
        """Update user's Style DNA profile.

        Args:
            db: Database session
            user_id: User ID

        Returns:
            Updated UserStyleProfile
        """
        # Compute Style DNA
        style_scores, model_version, source = self.compute_style_dna(db, user_id)

        # Get or create profile
        profile = db.query(UserStyleProfile).filter(
            UserStyleProfile.user_id == user_id
        ).first()

        if not profile:
            profile = UserStyleProfile(user_id=user_id)
            db.add(profile)

        # Update style scores
        profile.style_scores = style_scores

        # Compute confidence based on interaction count
        user_embeddings = self._get_user_product_embeddings(db, user_id)
        profile.interaction_count = len(user_embeddings)
        profile.confidence = min(len(user_embeddings) / 50.0, 1.0)

        db.commit()

        logger.info(f"Updated Style DNA for user {user_id} (source={source})")

        return profile