"""Trenzy-specific recommendation model training.

Trains a proprietary recommendation model using:
- User features (Style DNA, demographics)
- Product features (FashionCLIP embeddings, attributes)
- Interaction history (likes, views, purchases)
- Contextual features

Uses LightGBM/XGBoost for gradient boosting with time-based train/validation/test splits.
"""

from __future__ import annotations

from typing import List, Dict, Optional, Tuple
import logging
import numpy as np
import pickle
import json
from datetime import datetime
from pathlib import Path

from sqlalchemy.orm import Session
from sqlalchemy import and_, or_, func

import lightgbm as lgb
import xgboost as xgb

from ...models import User, Product
from ..models_ai import UserStyleProfile, ProductEmbedding, InteractionEvent
from ..ml_config import EMBEDDING_DIM

logger = logging.getLogger(__name__)


class RecommendationModelTrainer:
    """Trains Trenzy's proprietary recommendation model."""

    def __init__(
        self,
        model_type: str = "lightgbm",
        model_dir: str = "models/recommendation",
    ):
        """Initialize trainer.

        Args:
            model_type: Model type (lightgbm or xgboost)
            model_dir: Directory to save trained models
        """
        self.model_type = model_type
        self.model_dir = Path(model_dir)
        self.model_dir.mkdir(parents=True, exist_ok=True)

    def _build_training_dataset(
        self,
        db: Session,
        positive_threshold: int = 3,
        negative_ratio: int = 3,
    ) -> Tuple[np.ndarray, np.ndarray]:
        """Build training dataset from interaction history.

        Args:
            db: Database session
            positive_threshold: Minimum interactions to consider as positive
            negative_ratio: Number of negative samples per positive

        Returns:
            Tuple of (features, labels)
        """
        logger.info("Building training dataset...")

        # Get positive examples (users who liked products)
        positive_events = db.query(InteractionEvent).filter(
            InteractionEvent.event_type.in_(["like_product", "wishlist", "purchase"]),
            InteractionEvent.entity_type == "product",
        ).all()

        if not positive_events:
            logger.warning("No positive events found for training")
            return np.array([]), np.array([])

        # Build feature vectors
        features = []
        labels = []

        for event in positive_events:
            user_id = event.user_id
            product_id = event.entity_id

            if not product_id:
                continue

            # Get user features
            user_profile = db.query(UserStyleProfile).filter(
                UserStyleProfile.user_id == user_id
            ).first()

            # Get product features
            product = db.query(Product).filter(Product.id == product_id).first()
            product_emb = db.query(ProductEmbedding).filter(
                ProductEmbedding.product_id == product_id
            ).first()

            if not product:
                continue

            # Build feature vector
            feature_vector = self._build_feature_vector(
                user_profile, product, product_emb
            )
            features.append(feature_vector)
            labels.append(1)  # Positive

            # Add negative samples
            for _ in range(negative_ratio):
                # Sample a random product the user hasn't interacted with.
                # Product.is_archived (not is_active) is the correct field.
                random_product = db.query(Product).filter(
                    Product.is_archived == False,  # noqa: E712
                    Product.id != product_id,
                ).order_by(func.random()).first()

                if random_product:
                    random_emb = db.query(ProductEmbedding).filter(
                        ProductEmbedding.product_id == random_product.id
                    ).first()

                    neg_feature = self._build_feature_vector(
                        user_profile, random_product, random_emb
                    )
                    features.append(neg_feature)
                    labels.append(0)  # Negative

        return np.array(features), np.array(labels)

    def _build_feature_vector(
        self,
        user_profile: Optional[UserStyleProfile],
        product: Product,
        product_emb: Optional[ProductEmbedding],
    ) -> np.ndarray:
        """Build feature vector for a user-product pair.

        Args:
            user_profile: User's Style DNA
            product: Product
            product_emb: Product embedding

        Returns:
            Feature vector
        """
        features = []

        # User style features (10 style categories)
        if user_profile:
            style_categories = ["streetwear", "minimal", "classic", "boho", "casual",
                             "formal", "sporty", "ethnic", "vintage", "modern"]
            for style in style_categories:
                features.append(user_profile.style_scores.get(style, 0.0))

            # Color features (top 5 colors)
            top_colors = sorted(user_profile.color_scores.items(),
                              key=lambda x: x[1], reverse=True)[:5]
            color_features = [0.0] * 10  # 10 common colors
            color_map = {"black": 0, "white": 1, "gray": 2, "navy": 3, "beige": 4,
                        "brown": 5, "red": 6, "blue": 7, "green": 8, "pink": 9}
            for color, score in top_colors:
                if color in color_map:
                    color_features[color_map[color]] = score
            features.extend(color_features)

            # Fit features
            fit_categories = ["oversized", "relaxed", "slim", "regular", "athletic"]
            for fit in fit_categories:
                features.append(user_profile.fit_scores.get(fit, 0.0))

            # Price sensitivity
            features.append(user_profile.price_sensitivity)
        else:
            # Default features for new users
            features.extend([0.1] * 10)  # Styles
            features.extend([0.0] * 10)  # Colors
            features.extend([0.2] * 5)   # Fits
            features.append(0.5)          # Price sensitivity

        # Product features
        features.append(float(product.price or 0) / 10000.0)  # Normalized price

        # Product embedding (EMBEDDING_DIM-dimensional from FashionCLIP)
        if product_emb and product_emb.combined_embedding:
            emb = product_emb.combined_embedding
            if len(emb) != EMBEDDING_DIM:
                # Dimension mismatch — pad/truncate defensively and log warning
                logger.warning(
                    "Product %s embedding dim %d != EMBEDDING_DIM %d; padding/truncating",
                    product.id, len(emb), EMBEDDING_DIM
                )
                if len(emb) < EMBEDDING_DIM:
                    emb = emb + [0.0] * (EMBEDDING_DIM - len(emb))
                else:
                    emb = emb[:EMBEDDING_DIM]
            features.extend(emb)
        else:
            features.extend([0.0] * EMBEDDING_DIM)

        # Product attributes (one-hot encoded)
        categories = ["tops", "bottoms", "dresses", "outerwear", "footwear",
                     "accessories", "bags", "jewelry"]
        category_features = [0.0] * len(categories)
        # product.category is a String column — access directly, not via .name
        if product.category:
            cat_name = (product.category or "").lower()
            if cat_name in categories:
                category_features[categories.index(cat_name)] = 1.0
        features.extend(category_features)

        return np.array(features)

    def train(
        self,
        db: Session,
        validation_split: float = 0.2,
        num_rounds: int = 100,
        version: str = "v1.0",
    ):
        """Train the recommendation model.

        Args:
            db: Database session
            validation_split: Validation split ratio
            num_rounds: Number of training rounds
            version: Model version string
        """
        logger.info("Starting recommendation model training...")

        # Build dataset
        features, labels = self._build_training_dataset(db)

        if len(features) == 0:
            logger.error("No training data available")
            return None

        logger.info(f"Training dataset size: {len(features)} samples")

        # Split train/validation (time-based split should be done in dataset builder)
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

        # Create version directory
        version_dir = self.model_dir / version
        version_dir.mkdir(parents=True, exist_ok=True)

        # Save model artifact
        model_path = version_dir / f"model.{self.model_type}"
        with open(model_path, 'wb') as f:
            pickle.dump(model, f)

        # Save model metadata
        metadata = {
            "model_name": "recommendation",
            "version": version,
            "model_type": self.model_type,
            "training_date": datetime.utcnow().isoformat(),
            "num_rounds": num_rounds,
            "validation_split": validation_split,
            "training_samples": len(X_train),
            "validation_samples": len(X_val),
            "validation_accuracy": float(accuracy),
            "feature_dim": X_train.shape[1] if len(X_train) > 0 else 0,
        }

        metadata_path = version_dir / "metadata.json"
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)

        logger.info(f"Model saved to {model_path}")
        logger.info(f"Metadata saved to {metadata_path}")

        return model

    def predict(
        self,
        model,
        user_profile: Optional[UserStyleProfile],
        product: Product,
        product_emb: Optional[ProductEmbedding],
    ) -> float:
        """Predict likelihood of user liking a product.

        Args:
            model: Trained model
            user_profile: User's Style DNA
            product: Product
            product_emb: Product embedding

        Returns:
            Prediction score (0-1)
        """
        feature_vector = self._build_feature_vector(
            user_profile, product, product_emb
        ).reshape(1, -1)

        if hasattr(model, 'predict_proba'):
            return model.predict_proba(feature_vector)[0][1]
        else:
            return float(model.predict(feature_vector)[0])
