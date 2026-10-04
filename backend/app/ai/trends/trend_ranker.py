"""Trend prediction using time-series ML.

Predicts fashion trends based on historical engagement data:
- Views, likes, saves, purchases
- Category, brand, color, style
- Seasonal patterns
- Time-based momentum
"""

from __future__ import annotations

from typing import List, Dict, Optional, Tuple
import logging
import numpy as np
from datetime import datetime, timedelta

from sqlalchemy.orm import Session
from sqlalchemy import func, and_

from ...models import Product, TrendMetric
from ..models_ai import TrendPrediction

logger = logging.getLogger(__name__)


class TrendRanker:
    """Rule-based trend ranking system (formerly TrendPredictor).
    
    Ranks products by historical engagement and popularity metrics.
    Note: This is not a predictive ML model - it's a rule-based ranking system.
    """

    def __init__(self, decay_days: int = 30, prediction_horizon: int = 14):
        """Initialize trend predictor.

        Args:
            decay_days: Number of days for historical data
            prediction_horizon: Days to predict ahead
        """
        self.decay_days = decay_days
        self.prediction_horizon = prediction_horizon

    def _get_product_engagement(
        self,
        db: Session,
        product_id: int,
        days: int = 30,
    ) -> Dict[str, float]:
        """Get engagement metrics for a product.

        Args:
            db: Database session
            product_id: Product ID
            days: Number of days to look back

        Returns:
            Dictionary of engagement metrics
        """
        cutoff = datetime.utcnow() - timedelta(days=days)

        # Get trend metrics
        metrics = db.query(TrendMetric).filter(
            TrendMetric.product_id == product_id,
            TrendMetric.window_start >= cutoff,
        ).all()

        if not metrics:
            return {
                "views": 0,
                "saves": 0,
                "likes": 0,
                "purchases": 0,
            }

        total_views = sum(m.view_count or 0 for m in metrics)
        total_clicks = sum(m.click_count or 0 for m in metrics)

        return {
            "views": total_views,
            "saves": 0,
            "likes": total_clicks,
            "purchases": 0,
        }

    def _compute_trend_score(
        self,
        engagement: Dict[str, float],
    ) -> float:
        """Compute current trend score from engagement.

        Args:
            engagement: Engagement metrics

        Returns:
            Trend score (0-1)
        """
        # Weighted combination
        views_weight = 0.3
        saves_weight = 0.3
        likes_weight = 0.2
        purchases_weight = 0.2

        # Normalize (simple approach)
        total = engagement["views"] + engagement["saves"] + engagement["likes"] + engagement["purchases"]

        if total == 0:
            return 0.0

        normalized_views = engagement["views"] / (total + 1)
        normalized_saves = engagement["saves"] / (total + 1)
        normalized_likes = engagement["likes"] / (total + 1)
        normalized_purchases = engagement["purchases"] / (total + 1)

        score = (
            views_weight * normalized_views +
            saves_weight * normalized_saves +
            likes_weight * normalized_likes +
            purchases_weight * normalized_purchases
        )

        return min(score, 1.0)

    def _compute_momentum(
        self,
        db: Session,
        product_id: int,
    ) -> float:
        """Compute trend momentum (rate of change).

        Args:
            db: Database session
            product_id: Product ID

        Returns:
            Momentum score (-1 to 1)
        """
        # Compare recent vs older engagement
        recent_cutoff = datetime.utcnow() - timedelta(days=7)
        older_cutoff = datetime.utcnow() - timedelta(days=14)

        recent_metrics = db.query(TrendMetric).filter(
            TrendMetric.product_id == product_id,
            TrendMetric.window_start >= recent_cutoff,
        ).all()

        older_metrics = db.query(TrendMetric).filter(
            TrendMetric.product_id == product_id,
            TrendMetric.window_start >= older_cutoff,
            TrendMetric.window_start < recent_cutoff,
        ).all()

        recent_total = sum(
            (m.view_count or 0) + (m.click_count or 0)
            for m in recent_metrics
        )

        older_total = sum(
            (m.view_count or 0) + (m.click_count or 0)
            for m in older_metrics
        )

        if older_total == 0:
            return 0.5 if recent_total > 0 else 0.0

        # Momentum as percentage change
        momentum = (recent_total - older_total) / older_total
        return max(-1.0, min(1.0, momentum))

    def predict_product_trend(
        self,
        db: Session,
        product_id: int,
        model_version: str = "v1.0",
    ) -> Optional[TrendPrediction]:
        """Predict trend for a specific product.

        Args:
            db: Database session
            product_id: Product ID
            model_version: Model version identifier

        Returns:
            TrendPrediction instance or None
        """
        # Get current engagement
        engagement = self._get_product_engagement(db, product_id, self.decay_days)

        if engagement["views"] == 0 and engagement["saves"] == 0:
            # No data, skip
            return None

        # Compute current score
        current_score = self._compute_trend_score(engagement)

        # Compute momentum
        momentum = self._compute_momentum(db, product_id)

        # Predict future score (simple momentum-based prediction)
        # Higher momentum = higher predicted growth
        predicted_score = current_score + (momentum * 0.3)
        predicted_score = max(0.0, min(1.0, predicted_score))

        # Confidence based on data volume
        total_engagement = sum(engagement.values())
        confidence = min(total_engagement / 100.0, 1.0)

        # Create prediction
        prediction = TrendPrediction(
            trend_type="product",
            trend_id=product_id,
            current_score=current_score,
            predicted_score=predicted_score,
            momentum=momentum,
            horizon_days=self.prediction_horizon,
            confidence=confidence,
            model_version=model_version,
            target_date=datetime.utcnow() + timedelta(days=self.prediction_horizon),
        )

        db.add(prediction)
        db.commit()

        return prediction

    def predict_category_trends(
        self,
        db: Session,
        limit: int = 10,
        model_version: str = "v1.0",
    ) -> List[Tuple[str, float, float]]:
        """Predict trends for product categories.

        Args:
            db: Database session
            limit: Number of categories to return
            model_version: Model version

        Returns:
            List of (category_name, predicted_score, momentum) tuples
        """
        from ...models import Category

        categories = db.query(Category).all()

        if not categories:
            # Fallback: derive categories from product.category strings when
            # the categories table is unseeded (e.g. local dev SQLite).
            category_names = (
                db.query(Product.category)
                .filter(Product.category.isnot(None), Product.is_active == True)
                .distinct()
                .all()
            )
            return [(name, 0.0, 0.0) for (name,) in category_names[:limit]]

        category_scores = []

        for category in categories:
            # Get all products in category
            products = db.query(Product).filter(
                Product.category_id == category.id,
                Product.is_active == True,
            ).all()

            if not products:
                continue

            # Aggregate engagement across category
            total_engagement = {"views": 0, "saves": 0, "likes": 0, "purchases": 0}

            for product in products:
                engagement = self._get_product_engagement(db, product.id, self.decay_days)
                total_engagement["views"] += engagement["views"]
                total_engagement["saves"] += engagement["saves"]
                total_engagement["likes"] += engagement["likes"]
                total_engagement["purchases"] += engagement["purchases"]

            # Compute score
            score = self._compute_trend_score(total_engagement)

            # Simple momentum (would need time-series data for real implementation)
            momentum = 0.0

            category_scores.append((category.name, score, momentum))

        # Sort by predicted score
        category_scores.sort(key=lambda x: x[1], reverse=True)

        return category_scores[:limit]

    def predict_style_trends(
        self,
        db: Session,
        limit: int = 10,
        model_version: str = "v1.0",
    ) -> List[Tuple[str, float, float]]:
        """Predict trends for fashion styles.

        Args:
            db: Database session
            limit: Number of styles to return
            model_version: Model version

        Returns:
            List of (style, predicted_score, momentum) tuples
        """
        styles = ["casual", "formal", "streetwear", "sporty", "boho", "classic", "ethnic"]

        style_scores = []

        for style in styles:
            # Get products with this style (case-insensitive; seed data uses "Casual")
            products = db.query(Product).filter(
                func.lower(Product.style) == style,
                Product.is_active == True,
            ).all()

            if not products:
                continue

            # Aggregate engagement
            total_engagement = {"views": 0, "saves": 0, "likes": 0, "purchases": 0}

            for product in products:
                engagement = self._get_product_engagement(db, product.id, self.decay_days)
                total_engagement["views"] += engagement["views"]
                total_engagement["saves"] += engagement["saves"]
                total_engagement["likes"] += engagement["likes"]
                total_engagement["purchases"] += engagement["purchases"]

            # Compute score
            score = self._compute_trend_score(total_engagement)
            momentum = 0.0

            style_scores.append((style, score, momentum))

        # Sort by score
        style_scores.sort(key=lambda x: x[1], reverse=True)

        return style_scores[:limit]

    def get_trending_products(
        self,
        db: Session,
        limit: int = 20,
        min_score: float = 0.1,
    ) -> List[Tuple[Product, float, float]]:
        """Get currently trending products.

        Args:
            db: Database session
            limit: Number of products
            min_score: Minimum trend score

        Returns:
            List of (product, score, momentum) tuples
        """
        products = db.query(Product).filter(
            Product.is_active == True
        ).limit(200).all()

        trending = []

        for product in products:
            engagement = self._get_product_engagement(db, product.id, self.decay_days)

            if engagement["views"] == 0:
                continue

            score = self._compute_trend_score(engagement)

            if score >= min_score:
                momentum = self._compute_momentum(db, product.id)
                trending.append((product, score, momentum))

        # Sort by score
        trending.sort(key=lambda x: x[1], reverse=True)

        return trending[:limit]