"""Recommendation inference pipeline.

Production flow:
User → Candidate products → Feature generation → LightGBM → P(like) → Ranking → Diversity → Final products

The pipeline uses a trained model via the ModelManager when available, and otherwise
falls back through the canonical chain: ML → rule-based baseline → popularity.
"""

from __future__ import annotations

import logging
from typing import List, Dict, Optional, Tuple

from sqlalchemy.orm import Session

from ...models import User, Product
from ..models_ai import UserStyleProfile
from .model_loader import RecommendationModelLoader

logger = logging.getLogger(__name__)


class RecommendationInference:
    """Production inference pipeline for recommendations."""

    def __init__(
        self,
        model_loader: Optional[RecommendationModelLoader] = None,
        fallback_to_rules: bool = True,
        preloaded_model = None,
    ):
        """Initialize inference pipeline.

        Args:
            model_loader: Model loader instance.
            fallback_to_rules: Whether to use rule-based fallback if model unavailable.
            preloaded_model: Preloaded model instance from ModelManager (loaded once at startup).
                When provided, uses this model instead of loading from disk during requests.
        """
        self.model_loader = model_loader or RecommendationModelLoader()
        self.fallback_to_rules = fallback_to_rules
        self.preloaded_model = preloaded_model
        
        # If we have a preloaded model, mark the loader as loaded to avoid request-time loading
        if self.preloaded_model is not None:
            self.model_loader.model = self.preloaded_model

    def get_recommendations(
        self,
        db: Session,
        user_id: int,
        limit: int = 20,
        context: Optional[Dict] = None,
        exclude_product_ids: Optional[List[int]] = None,
    ) -> Tuple[List[Product], List[str], Optional[str], str]:
        """Get personalized recommendations for a user.

        Returns a 4-tuple: ``(products, explanations, model_version, source)`` where
        ``source`` is one of ``"ml"``, ``"baseline"``, ``"popularity"``.

        Args:
            db: Database session
            user_id: User ID
            limit: Number of recommendations
            context: Optional context (occasion, budget, etc.)
            exclude_product_ids: Product IDs to exclude

        Returns:
            ``(products, explanations, model_version, source)``
        """
        # NOTE: models are loaded at startup by the ModelManager (before torch).
        # Never load at request time — unpickling LightGBM after torch is loaded
        # crashes the process on macOS (duplicate libomp). If no model is loaded,
        # we route through the rule-based fallback (source="baseline").

        # Get user profile
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            return [], [], None, "none"

        user_profile = db.query(UserStyleProfile).filter(
            UserStyleProfile.user_id == user_id
        ).first()

        # Get candidate products
        candidates = self._get_candidate_products(
            db, user_id, limit * 5, context, exclude_product_ids
        )

        if not candidates:
            # Cold start: no candidates matched filters — fall back to popularity.
            logger.info("No candidates for user %s; falling back to popularity", user_id)
            popular = self._popular_products(db, user_id, limit, exclude_product_ids)
            return popular, [], None, "popularity"

        source = "ml" if self.model_loader.is_loaded() else ("baseline" if self.fallback_to_rules else "none")

        # Score candidates
        scored_products = []
        for product in candidates:
            if self.model_loader.is_loaded():
                # Use ML model (gradient-boosted classifier .predict_proba)
                score = self.model_loader.predict(db, user_id, product)
            else:
                # Use fallback (rule-based)
                score = self._fallback_score(user_profile, product)

            scored_products.append((product, score))

        # Sort by score
        scored_products.sort(key=lambda x: x[1], reverse=True)

        # Apply diversity
        diversified = self._diversify_results(scored_products, limit)

        # Generate explanations
        explanations = self._generate_expressions(diversified, user_profile)

        products = [p for p, _ in diversified]

        model_version = self.model_loader.get_version()
        return products, explanations, model_version, source

    def _get_candidate_products(
        self,
        db: Session,
        user_id: int,
        limit: int,
        context: Optional[Dict],
        exclude_product_ids: Optional[List[int]],
    ) -> List[Product]:
        """Get candidate products for ranking.

        Args:
            db: Database session
            user_id: User ID
            limit: Number of candidates
            context: Optional context
            exclude_product_ids: Product IDs to exclude

        Returns:
            List of candidate products
        """
        from ...models import Product
        query = db.query(Product).filter(Product.is_archived == False)

        # Exclude products
        if exclude_product_ids:
            query = query.filter(~Product.id.in_(exclude_product_ids))

        # Apply context filters
        if context:
            if context.get("category"):
                query = query.filter(Product.category == context["category"])
            if context.get("max_price"):
                query = query.filter(Product.price <= context["max_price"])
            if context.get("style"):
                query = query.filter(Product.style == context["style"])

        # Get candidates
        candidates = query.limit(limit).all()

        return candidates

    def _popular_products(
        self,
        db: Session,
        user_id: int,
        limit: int,
        exclude_product_ids: Optional[List[int]],
    ) -> List[Product]:
        """Cold-start fallback: top-rated products (popularity)."""
        from ...models import Product
        query = db.query(Product).filter(Product.is_archived == False)
        if exclude_product_ids:
            query = query.filter(~Product.id.in_(exclude_product_ids))
        return query.order_by(Product.rating.desc().nullslast()).limit(limit).all()

    def _fallback_score(
        self,
        user_profile: Optional[UserStyleProfile],
        product: Product,
    ) -> float:
        """Calculate fallback score using rule-based logic.

        Args:
            user_profile: User's Style DNA
            product: Product

        Returns:
            Score (0-1)
        """
        if not user_profile:
            return 0.5

        # Style affinity
        style_score = 0.0
        if product.style:
            style_score = user_profile.style_scores.get(product.style.lower(), 0.0)

        # Category affinity
        category_score = 0.0
        if product.category:
            category_score = user_profile.category_scores.get(product.category.lower(), 0.0)

        # Brand affinity
        brand_score = 0.0
        if product.brand:
            brand_score = user_profile.brand_scores.get(product.brand.lower(), 0.0)

        # Combine scores
        score = (style_score * 0.4 + category_score * 0.3 + brand_score * 0.3)

        return score

    def _diversify_results(
        self,
        scored_products: List[Tuple[Product, float]],
        limit: int,
    ) -> List[Tuple[Product, float]]:
        """Diversify results to avoid brand/category dominance.

        Args:
            scored_products: List of (product, score) tuples
            limit: Number of results

        Returns:
            Diversified list
        """
        if not scored_products:
            return []

        # Simple diversity: interleave by brand
        by_brand = {}
        for product, score in scored_products:
            brand = product.brand if product.brand else "Unknown"
            if brand not in by_brand:
                by_brand[brand] = []
            by_brand[brand].append((product, score))

        diversified = []
        brand_keys = list(by_brand.keys())
        idx = 0

        while len(diversified) < limit and by_brand:
            brand = brand_keys[idx % len(brand_keys)]
            if by_brand[brand]:
                diversified.append(by_brand[brand].pop(0))
            else:
                del by_brand[brand]
                brand_keys.remove(brand)
            idx += 1

        return diversified[:limit]

    def _generate_expressions(
        self,
        scored_products: List[Tuple[Product, float]],
        user_profile: Optional[UserStyleProfile],
    ) -> List[str]:
        """Generate explanations for recommendations.

        Args:
            scored_products: List of (product, score) tuples
            user_profile: User's Style DNA

        Returns:
            List of explanations
        """
        explanations = []

        for product, score in scored_products:
            if score > 0.8:
                explanations.append(f"Highly recommended based on your style preferences")
            elif score > 0.6:
                explanations.append(f"Matches your {product.style or 'style'} preferences")
            elif score > 0.4:
                explanations.append(f"Similar to items you've liked")
            else:
                explanations.append(f"Popular item you might like")

        return explanations