"""Trend prediction model training pipeline.

Trains Trenzy's proprietary trend prediction model using:
- Historical engagement data (views, likes, saves, purchases)
- Time-series features (seasonality, momentum)
- Product attributes (category, brand, price)
- LightGBM/XGBoost for gradient boosting

Predicts: Future popularity of products/categories/styles.
"""

from __future__ import annotations

from typing import List, Dict, Optional, Tuple
import logging
import numpy as np
import pickle
from datetime import datetime, timedelta
from pathlib import Path

from sqlalchemy.orm import Session
from sqlalchemy import and_, func

import lightgbm as lgb
import xgboost as xgb

from ...models import Product, TrendMetric
from ..models_ai import TrendPrediction

logger = logging.getLogger(__name__)


class TrendModelTrainer:
    """Trains Trenzy's proprietary trend prediction model."""

    def __init__(
        self,
        model_type: str = "lightgbm",
        model_dir: str = "models/trends",
        prediction_horizon: int = 14,
    ):
        """Initialize trainer.

        Args:
            model_type: Model type (lightgbm or xgboost)
            model_dir: Directory to save trained models
            prediction_horizon: Days to predict ahead
        """
        self.model_type = model_type
        self.model_dir = Path(model_dir)
        self.model_dir.mkdir(parents=True, exist_ok=True)
        self.prediction_horizon = prediction_horizon

    def _get_product_time_series(
        self,
        db: Session,
        product_id: int,
        days: int = 60,
    ) -> List[Dict[str, float]]:
        """Get time-series data for a product.

        Args:
            db: Database session
            product_id: Product ID
            days: Number of historical days

        Returns:
            List of daily engagement data
        """
        cutoff = datetime.utcnow() - timedelta(days=days)

        metrics = db.query(TrendMetric).filter(
            TrendMetric.product_id == product_id,
            TrendMetric.date >= cutoff,
        ).order_by(TrendMetric.date).all()

        time_series = []
        for m in metrics:
            time_series.append({
                "date": m.date,
                "views": m.views or 0,
                "saves": m.saves or 0,
                "likes": m.likes or 0,
                "purchases": m.purchases or 0,
            })

        return time_series

    def _compute_time_series_features(
        self,
        time_series: List[Dict[str, float]],
    ) -> np.ndarray:
        """Compute time-series features for trend prediction.

        Args:
            time_series: List of daily engagement data

        Returns:
            Feature vector
        """
        if len(time_series) < 7:
            logger.warning(f"Cannot compute trend features: only {len(time_series)} days of data available (needs at least 7)")
            return None

        # Extract arrays
        views = [d["views"] for d in time_series]
        saves = [d["saves"] for d in time_series]
        likes = [d["likes"] for d in time_series]
        purchases = [d["purchases"] for d in time_series]

        features = []

        # Recent averages (last 7 days)
        recent_views = np.mean(views[-7:]) if len(views) >= 7 else 0
        recent_saves = np.mean(saves[-7:]) if len(saves) >= 7 else 0
        recent_likes = np.mean(likes[-7:]) if len(likes) >= 7 else 0
        recent_purchases = np.mean(purchases[-7:]) if len(purchases) >= 7 else 0

        features.extend([recent_views, recent_saves, recent_likes, recent_purchases])

        # Momentum (rate of change)
        if len(views) >= 14:
            momentum_views = (np.mean(views[-7:]) - np.mean(views[-14:-7])) / (np.mean(views[-14:-7]) + 1)
            momentum_saves = (np.mean(saves[-7:]) - np.mean(saves[-14:-7])) / (np.mean(saves[-14:-7]) + 1)
            momentum_likes = (np.mean(likes[-7:]) - np.mean(likes[-14:-7])) / (np.mean(likes[-14:-7]) + 1)
        else:
            momentum_views = 0.0
            momentum_saves = 0.0
            momentum_likes = 0.0

        features.extend([momentum_views, momentum_saves, momentum_likes])

        # Volatility
        if len(views) >= 7:
            volatility_views = np.std(views[-7:]) / (np.mean(views[-7:]) + 1)
            volatility_saves = np.std(saves[-7:]) / (np.mean(saves[-7:]) + 1)
        else:
            volatility_views = 0.0
            volatility_saves = 0.0

        features.extend([volatility_views, volatility_saves])

        # Trend direction (up/down)
        if len(views) >= 3:
            trend_direction = 1 if views[-1] > views[-3] else 0
        else:
            trend_direction = 0

        features.append(trend_direction)

        # Engagement ratios
        total_recent = recent_views + recent_saves + recent_likes + recent_purchases
        if total_recent > 0:
            save_ratio = recent_saves / total_recent
            like_ratio = recent_likes / total_recent
            purchase_ratio = recent_purchases / total_recent
        else:
            save_ratio = 0.0
            like_ratio = 0.0
            purchase_ratio = 0.0

        features.extend([save_ratio, like_ratio, purchase_ratio])

        # Day of week patterns (average by day)
        day_features = [0.0] * 7
        for d in time_series[-14:]:
            day_idx = d["date"].weekday()
            day_features[day_idx] += d["views"]

        day_features = [f / max(sum(day_features), 1) for f in day_features]
        features.extend(day_features)

        # Fill remaining
        while len(features) < 30:
            features.append(0.0)

        return np.array(features)

    def _build_training_dataset(
        self,
        db: Session,
        historical_days: int = 60,
    ) -> Tuple[np.ndarray, np.ndarray]:
        """Build training dataset from historical trend data.

        Args:
            db: Database session
            historical_days: Number of historical days to use

        Returns:
            Tuple of (features, labels)
        """
        logger.info("Building trend prediction training dataset...")

        # Get products with sufficient history
        cutoff = datetime.utcnow() - timedelta(days=historical_days)

        products = db.query(Product).filter(
            Product.is_active == True,
        ).limit(500).all()

        features = []
        labels = []

        for product in products:
            # Get time series
            time_series = self._get_product_time_series(db, product.id, historical_days)

            if len(time_series) < 14:
                continue

            # Compute features
            feature_vector = self._compute_time_series_features(time_series)

            # Label: future popularity (next 7 days vs previous 7 days)
            if len(time_series) >= 14:
                future_views = np.mean([d["views"] for d in time_series[-7:]])
                past_views = np.mean([d["views"] for d in time_series[-14:-7]])

                # Label: 1 if trending up, 0 if stable/down
                label = 1 if future_views > past_views * 1.1 else 0

                features.append(feature_vector)
                labels.append(label)

        return np.array(features), np.array(labels)

    def train(
        self,
        db: Session,
        validation_split: float = 0.2,
        num_rounds: int = 100,
    ):
        """Train trend prediction model.

        Args:
            db: Database session
            validation_split: Validation split ratio
            num_rounds: Number of training rounds
        """
        logger.info("Starting trend prediction model training...")

        # Build dataset
        features, labels = self._build_training_dataset(db)

        if len(features) == 0:
            logger.error("No training data available")
            return None

        logger.info(f"Training dataset size: {len(features)} samples")

        # Split train/validation
        split_idx = int(len(features) * (1 - validation_split))
        X_train, X_val = features[:split_idx], features[split_idx:]
        y_train, y_val = labels[:split_idx], labels[split_idx]

        # Train model
        if self.model_type == "lightgbm":
            model = lgb.LGBMClassifier(
                n_estimators=num_rounds,
                learning_rate=0.1,
                max_depth=8,
                num_leaves=31,
                random_state=42,
                verbose=-1,
            )
            model.fit(
                X_train, y_train,
                eval_set=[(X_val, y_val)],
                callbacks=[lgb.early_stopping(stopping_rounds=10)],
            )
        else:  # xgboost
            model = xgb.XGBClassifier(
                n_estimators=num_rounds,
                learning_rate=0.1,
                max_depth=8,
                random_state=42,
            )
            model.fit(
                X_train, y_train,
                eval_set=[(X_val, y_val)],
                early_stopping_rounds=10,
                verbose=False,
            )

        # Evaluate
        val_pred = model.predict(X_val)
        accuracy = np.mean(val_pred == y_val)
        logger.info(f"Validation accuracy: {accuracy:.4f}")

        # Save model
        model_path = self.model_dir / f"trend_{self.model_type}_{datetime.now().strftime('%Y%m%d')}.pkl"
        with open(model_path, 'wb') as f:
            pickle.dump(model, f)

        logger.info(f"Model saved to {model_path}")

        return model

    def predict(
        self,
        model,
        db: Session,
        product_id: int,
    ) -> float:
        """Predict future trend for a product.

        Args:
            model: Trained model
            db: Database session
            product_id: Product ID

        Returns:
            Trend score (0-1)
        """
        # Get time series
        time_series = self._get_product_time_series(db, product_id, days=60)

        if len(time_series) < 7:
            return 0.5  # Neutral for new products

        # Compute features
        feature_vector = self._compute_time_series_features(time_series).reshape(1, -1)

        if hasattr(model, 'predict_proba'):
            return model.predict_proba(feature_vector)[0][1]
        else:
            return float(model.predict(feature_vector)[0])

    def predict_category_trends(
        self,
        model,
        db: Session,
        category_id: int,
    ) -> float:
        """Predict future trend for a category.

        Args:
            model: Trained model
            db: Database session
            category_id: Category ID

        Returns:
            Trend score (0-1)
        """
        # Get products in category
        from ...models import Category
        products = db.query(Product).filter(
            Product.category_id == category_id,
            Product.is_active == True,
        ).limit(50).all()

        if not products:
            return 0.5

        # Average predictions across products
        scores = []
        for product in products:
            score = self.predict(model, db, product.id)
            scores.append(score)

        return np.mean(scores) if scores else 0.5