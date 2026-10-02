"""Outfit compatibility model training pipeline.

Trains Trenzy's proprietary outfit compatibility model using:
- FashionCLIP embeddings for individual items
- Historical outfit interaction data (saved, modified, accepted)
- Color harmony rules as features
- Style coherence features
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

from ...models import Product
from ..models_ai import ProductEmbedding, OutfitGeneration

logger = logging.getLogger(__name__)


class OutfitCompatibilityTrainer:
    """Trains Trenzy's proprietary outfit compatibility model."""

    def __init__(
        self,
        model_dir: str = "models/outfit_compatibility",
    ):
        """Initialize trainer.

        Args:
            model_dir: Directory to save trained models
        """
        self.model_dir = Path(model_dir)
        self.model_dir.mkdir(parents=True, exist_ok=True)

    def _build_outfit_features(
        self,
        products: List[Product],
        product_embeddings: Dict[int, np.ndarray],
    ) -> np.ndarray:
        """Build feature vector for an outfit.

        Args:
            products: List of products in outfit
            product_embeddings: Dictionary of product embeddings

        Returns:
            Feature vector
        """
        features = []

        # Get embeddings for each item
        embeddings = []
        for product in products:
            if product.id in product_embeddings:
                embeddings.append(product_embeddings[product.id])

        if len(embeddings) < 2:
            logger.warning(f"Cannot build outfit features: only {len(embeddings)} valid embeddings found (needs at least 2)")
            return None

        # Average embedding
        avg_embedding = np.mean(embeddings, axis=0)
        features.extend(avg_embedding[:64])  # First 64 dimensions

        # Color compatibility features
        colors = [p.color for p in products if p.color]
        color_features = self._compute_color_features(colors)
        features.extend(color_features)

        # Style coherence features
        styles = [p.style for p in products if p.style]
        style_features = self._compute_style_features(styles)
        features.extend(style_features)

        # Fit compatibility
        fits = [p.fit for p in products if p.fit]
        fit_features = self._compute_fit_features(fits)
        features.extend(fit_features)

        # Occasion match
        occasions = [p.occasion for p in products if p.occasion]
        occasion_features = self._compute_occasion_features(occasions)
        features.extend(occasion_features)

        return np.array(features)

    def _compute_color_features(self, colors: List[str]) -> List[float]:
        """Compute color compatibility features.

        Args:
            colors: List of colors

        Returns:
            Color feature vector
        """
        # Color harmony rules
        harmonious_pairs = {
            ("black", "white"), ("black", "gray"), ("black", "navy"),
            ("white", "gray"), ("white", "blue"), ("white", "red"),
            ("navy", "white"), ("navy", "beige"), ("navy", "yellow"),
            ("gray", "black"), ("gray", "white"), ("gray", "navy"),
        }

        if len(colors) < 2:
            return [0.0] * 10

        # Count harmonious pairs
        harmonious_count = 0
        total_pairs = 0

        for i in range(len(colors)):
            for j in range(i + 1, len(colors)):
                total_pairs += 1
                if (colors[i], colors[j]) in harmonious_pairs or (colors[j], colors[i]) in harmonious_pairs:
                    harmonious_count += 1

        harmony_ratio = harmonious_count / total_pairs if total_pairs > 0 else 0.0

        # Color diversity
        unique_colors = len(set(colors))
        diversity = unique_colors / len(colors)

        # Neutral color presence
        neutrals = ["black", "white", "gray", "beige", "cream", "navy"]
        neutral_count = sum(1 for c in colors if c in neutrals)
        neutral_ratio = neutral_count / len(colors)

        return [harmony_ratio, diversity, neutral_ratio] + [0.0] * 7

    def _compute_style_features(self, styles: List[str]) -> List[float]:
        """Compute style coherence features.

        Args:
            styles: List of styles

        Returns:
            Style feature vector
        """
        style_coherence = {
            "casual": ["casual", "streetwear"],
            "formal": ["formal", "classic"],
            "streetwear": ["casual", "streetwear", "sporty"],
            "sporty": ["casual", "sporty", "streetwear"],
            "boho": ["boho", "casual"],
            "classic": ["formal", "classic", "casual"],
        }

        if len(styles) < 2:
            return [0.0] * 10

        coherent_count = 0
        total_pairs = 0

        for i in range(len(styles)):
            for j in range(i + 1, len(styles)):
                total_pairs += 1
                s1, s2 = styles[i].lower(), styles[j].lower()

                if s1 in style_coherence and s2 in style_coherence[s1]:
                    coherent_count += 1

        coherence_ratio = coherent_count / total_pairs if total_pairs > 0 else 0.0

        # Style diversity
        unique_styles = len(set(styles))
        diversity = unique_styles / len(styles)

        return [coherence_ratio, diversity] + [0.0] * 8

    def _compute_fit_features(self, fits: List[str]) -> List[float]:
        """Compute fit compatibility features.

        Args:
            fits: List of fits

        Returns:
            Fit feature vector
        """
        fit_compatibility = {
            "oversized": ["oversized", "relaxed"],
            "relaxed": ["oversized", "relaxed", "regular"],
            "slim": ["slim", "regular"],
            "regular": ["relaxed", "slim", "regular"],
            "athletic": ["athletic", "relaxed"],
        }

        if len(fits) < 2:
            return [0.0] * 10

        compatible_count = 0
        total_pairs = 0

        for i in range(len(fits)):
            for j in range(i + 1, len(fits)):
                total_pairs += 1
                f1, f2 = fits[i].lower(), fits[j].lower()

                if f1 in fit_compatibility and f2 in fit_compatibility[f1]:
                    compatible_count += 1

        compatibility_ratio = compatible_count / total_pairs if total_pairs > 0 else 0.0

        return [compatibility_ratio] + [0.0] * 9

    def _compute_occasion_features(self, occasions: List[str]) -> List[float]:
        """Compute occasion match features.

        Args:
            occasions: List of occasions

        Returns:
            Occasion feature vector
        """
        if len(occasions) < 2:
            return [0.0] * 10

        # Check if all occasions match
        all_match = len(set(occasions)) == 1
        match_score = 1.0 if all_match else 0.0

        return [match_score] + [0.0] * 9

    def _build_training_dataset(
        self,
        db: Session,
    ) -> Tuple[np.ndarray, np.ndarray]:
        """Build training dataset from outfit generation history.

        Args:
            db: Database session

        Returns:
            Tuple of (features, compatibility_scores)
        """
        logger.info("Building outfit compatibility training dataset...")

        # Get historical outfit generations
        generations = db.query(OutfitGeneration).filter(
            OutfitGeneration.compatibility_score.isnot(None),
        ).all()

        if not generations:
            logger.warning("No outfit generation data found")
            return np.array([]), np.array([])

        # Get product embeddings
        all_product_ids = set()
        for gen in generations:
            for item in gen.outfit_items:
                all_product_ids.add(item["product_id"])

        product_embeddings = db.query(ProductEmbedding).filter(
            ProductEmbedding.product_id.in_(all_product_ids),
            ProductEmbedding.combined_embedding.isnot(None),
        ).all()

        emb_map = {pe.product_id: np.array(pe.combined_embedding) for pe in product_embeddings}

        # Build features
        features = []
        labels = []

        for gen in generations:
            product_ids = [item["product_id"] for item in gen.outfit_items]
            products = db.query(Product).filter(Product.id.in_(product_ids)).all()

            if len(products) < 2:
                continue

            feature_vector = self._build_outfit_features(products, emb_map)
            features.append(feature_vector)
            labels.append(gen.compatibility_score)

        return np.array(features), np.array(labels)

    def train(
        self,
        db: Session,
        validation_split: float = 0.2,
        num_rounds: int = 100,
    ):
        """Train outfit compatibility model.

        Args:
            db: Database session
            validation_split: Validation split ratio
            num_rounds: Number of training rounds
        """
        logger.info("Starting outfit compatibility model training...")

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

        # Train model (regression for compatibility score)
        model = lgb.LGBMRegressor(
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
        mae = np.mean(np.abs(val_pred - y_val))
        logger.info(f"Validation MAE: {mae:.4f}")

        # Save model
        model_path = self.model_dir / f"compatibility_{datetime.now().strftime('%Y%m%d')}.pkl"
        with open(model_path, 'wb') as f:
            pickle.dump(model, f)

        logger.info(f"Model saved to {model_path}")

        return model

    def predict(
        self,
        model,
        products: List[Product],
        product_embeddings: Dict[int, np.ndarray],
    ) -> float:
        """Predict outfit compatibility score.

        Args:
            model: Trained model
            products: List of products in outfit
            product_embeddings: Dictionary of product embeddings

        Returns:
            Compatibility score (0-1)
        """
        feature_vector = self._build_outfit_features(products, product_embeddings).reshape(1, -1)
        prediction = model.predict(feature_vector)[0]
        return max(0.0, min(1.0, float(prediction)))