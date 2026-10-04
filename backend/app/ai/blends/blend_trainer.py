"""Blend ML model training pipeline.

Trains Trenzy's proprietary group preference model using:
- Individual user Style DNA profiles
- Group interaction history (votes, saves, purchases)
- Product features (FashionCLIP embeddings)
- Group diversity features

Predicts: Will this group like this product?
"""

from __future__ import annotations

from typing import List, Dict, Optional, Tuple
import logging
import numpy as np
import pickle
from datetime import datetime
from pathlib import Path

from sqlalchemy.orm import Session
from sqlalchemy import and_, func

import lightgbm as lgb

from ...models import User, Product
from ...blend_helpers import get_blend_members
from ..models_ai import UserStyleProfile, ProductEmbedding, InteractionEvent

logger = logging.getLogger(__name__)


class BlendModelTrainer:
    """Trains Trenzy's proprietary Blend group preference model."""

    def __init__(
        self,
        model_dir: str = "models/blends",
    ):
        """Initialize trainer.

        Args:
            model_dir: Directory to save trained models
        """
        self.model_dir = Path(model_dir)
        self.model_dir.mkdir(parents=True, exist_ok=True)

    def _get_group_style_features(
        self,
        db: Session,
        member_ids: List[int],
    ) -> np.ndarray:
        """Get aggregated style features for a group.

        Args:
            db: Database session
            member_ids: List of member user IDs

        Returns:
            Group style feature vector
        """
        profiles = db.query(UserStyleProfile).filter(
            UserStyleProfile.user_id.in_(member_ids)
        ).all()

        if not profiles:
            logger.warning("No user style profiles found for group members, cannot aggregate style features")
            return None

        # Aggregate style scores
        style_categories = ["streetwear", "minimal", "classic", "boho", "casual",
                         "formal", "sporty", "ethnic", "vintage", "modern"]
        aggregated_styles = np.zeros(10)  # Safe: explicitly initialized zero vector for feature aggregation, not embeddings

        for profile in profiles:
            for i, style in enumerate(style_categories):
                aggregated_styles[i] += profile.style_scores.get(style, 0.0)

        aggregated_styles /= len(profiles)

        # Aggregate color preferences
        color_map = {"black": 0, "white": 1, "gray": 2, "navy": 3, "beige": 4,
                    "brown": 5, "red": 6, "blue": 7, "green": 8, "pink": 9}
        aggregated_colors = np.zeros(10)  # Safe: explicitly initialized zero vector for feature aggregation, not embeddings

        for profile in profiles:
            top_colors = sorted(profile.color_scores.items(),
                              key=lambda x: x[1], reverse=True)[:5]
            for color, score in top_colors:
                if color in color_map:
                    aggregated_colors[color_map[color]] += score

        aggregated_colors /= len(profiles)

        # Group diversity (variance in preferences)
        style_variances = []
        for style in style_categories:
            scores = [p.style_scores.get(style, 0.0) for p in profiles]
            style_variances.append(np.var(scores))

        diversity_score = np.mean(style_variances)

        return np.concatenate([
            aggregated_styles,
            aggregated_colors,
            [diversity_score],
            [len(profiles)],  # Group size
        ])

    def _build_blend_features(
        self,
        db: Session,
        blend_id: int,
        product_id: int,
        product_emb: Optional[ProductEmbedding],
    ) -> np.ndarray:
        """Build feature vector for blend-product pair.

        Args:
            db: Database session
            blend_id: Blend ID
            product_id: Product ID
            product_emb: Product embedding

        Returns:
            Feature vector
        """
        # Get group features
        member_ids = get_blend_members(db, blend_id)
        group_features = self._get_group_style_features(db, member_ids)
        if group_features is None:
            logger.warning(f"Cannot build blend features for blend {blend_id}: missing group style features")
            return None

        # Get product features
        product = db.query(Product).filter(Product.id == product_id).first()

        if not product:
            logger.warning(f"Cannot build blend features for product {product_id}: product not found")
            return None

        # Product embedding
        if product_emb and product_emb.combined_embedding:
            product_features = np.array(product_emb.combined_embedding)[:512]
        else:
            logger.warning(f"Missing embedding for product {product.id}, skipping in blend training")
            return None  # Skip this product instead of using zero vector

        # Product attributes
        price_feature = float(product.price) / 10000.0

        # Category one-hot
        categories = ["tops", "bottoms", "dresses", "outerwear", "footwear",
                     "accessories", "bags", "jewelry"]
        category_features = [0.0] * len(categories)
        if product.category:
            cat_name = product.category.name.lower()
            if cat_name in categories:
                category_features[categories.index(cat_name)] = 1.0

        # Style match (if product has style)
        style_match = 0.0
        if product.style:
            style_categories = ["streetwear", "minimal", "classic", "boho", "casual",
                             "formal", "sporty", "ethnic", "vintage", "modern"]
            if product.style.lower() in style_categories:
                style_match = group_features[style_categories.index(product.style.lower())]

        return np.concatenate([
            group_features,
            product_features,
            [price_feature],
            category_features,
            [style_match],
        ])

    def _build_training_dataset(
        self,
        db: Session,
        positive_threshold: int = 2,
        negative_ratio: int = 3,
    ) -> Tuple[np.ndarray, np.ndarray]:
        """Build training dataset from blend interaction history.

        Args:
            db: Database session
            positive_threshold: Minimum votes to consider as positive
            negative_ratio: Number of negative samples per positive

        Returns:
            Tuple of (features, labels)
        """
        logger.info("Building blend training dataset...")

        # Get blend vote events
        vote_events = db.query(InteractionEvent).filter(
            InteractionEvent.event_type == "blend_vote",
            InteractionEvent.entity_type == "product",
        ).all()

        if not vote_events:
            logger.warning("No blend vote events found")
            return np.array([]), np.array([])

        # Aggregate votes by (blend_id, product_id)
        vote_counts = {}
        for event in vote_events:
            key = (event.context.get("blend_id"), event.entity_id)
            if key[0] and key[1]:
                vote_counts[key] = vote_counts.get(key, 0) + 1

        # Build features
        features = []
        labels = []

        for (blend_id, product_id), vote_count in vote_counts.items():
            # Get product embedding
            product_emb = db.query(ProductEmbedding).filter(
                ProductEmbedding.product_id == product_id
            ).first()

            # Build feature vector
            feature_vector = self._build_blend_features(
                db, blend_id, product_id, product_emb
            )

            # Label based on vote count
            label = 1 if vote_count >= positive_threshold else 0

            features.append(feature_vector)
            labels.append(label)

            # Add negative samples for positive examples
            if label == 1:
                for _ in range(negative_ratio):
                    # Sample random product
                    random_product = db.query(Product).filter(
                        Product.is_active == True,
                        Product.id != product_id,
                    ).order_by(func.random()).first()

                    if random_product:
                        random_emb = db.query(ProductEmbedding).filter(
                            ProductEmbedding.product_id == random_product.id
                        ).first()

                        neg_feature = self._build_blend_features(
                            db, blend_id, random_product.id, random_emb
                        )
                        features.append(neg_feature)
                        labels.append(0)

        return np.array(features), np.array(labels)

    def train(
        self,
        db: Session,
        validation_split: float = 0.2,
        num_rounds: int = 100,
    ):
        """Train blend preference model.

        Args:
            db: Database session
            validation_split: Validation split ratio
            num_rounds: Number of training rounds
        """
        logger.info("Starting blend model training...")

        # Build dataset
        features, labels = self._build_training_dataset(db)

        if len(features) == 0:
            logger.error("No training data available")
            return None

        logger.info(f"Training dataset size: {len(features)} samples")

        # Split train/validation
        split_idx = int(len(features) * (1 - validation_split))
        X_train, X_val = features[:split_idx], features[split_idx:]
        y_train, y_val = labels[:split_idx], labels[split_idx:]

        # Train model
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

        # Evaluate
        val_pred = model.predict(X_val)
        accuracy = np.mean(val_pred == y_val)
        logger.info(f"Validation accuracy: {accuracy:.4f}")

        # Save model
        model_path = self.model_dir / f"blend_{datetime.now().strftime('%Y%m%d')}.pkl"
        with open(model_path, 'wb') as f:
            pickle.dump(model, f)

        logger.info(f"Model saved to {model_path}")

        return model

    def predict(
        self,
        model,
        db: Session,
        blend_id: int,
        product_id: int,
    ) -> float:
        """Predict group preference for a product.

        Args:
            model: Trained model
            db: Database session
            blend_id: Blend ID
            product_id: Product ID

        Returns:
            Preference score (0-1)
        """
        product_emb = db.query(ProductEmbedding).filter(
            ProductEmbedding.product_id == product_id
        ).first()

        feature_vector = self._build_blend_features(
            db, blend_id, product_id, product_emb
        ).reshape(1, -1)

        if hasattr(model, 'predict_proba'):
            return model.predict_proba(feature_vector)[0][1]
        else:
            return float(model.predict(feature_vector)[0])

    def rank_products_for_blend(
        self,
        model,
        db: Session,
        blend_id: int,
        limit: int = 20,
    ) -> List[Tuple[int, float]]:
        """Rank products for a blend using trained model.

        Args:
            model: Trained model
            db: Database session
            blend_id: Blend ID
            limit: Number of products to return

        Returns:
            List of (product_id, score) tuples
        """
        # Get candidate products
        products = db.query(Product).filter(
            Product.is_active == True
        ).limit(200).all()

        # Get all product embeddings
        product_ids = [p.id for p in products]
        product_embeddings = db.query(ProductEmbedding).filter(
            ProductEmbedding.product_id.in_(product_ids),
            ProductEmbedding.combined_embedding.isnot(None),
        ).all()

        emb_map = {pe.product_id: pe for pe in product_embeddings}

        # Score each product
        scored = []
        for product in products:
            score = self.predict(model, db, blend_id, product.id)
            scored.append((product.id, score))

        # Sort by score
        scored.sort(key=lambda x: x[1], reverse=True)

        return scored[:limit]