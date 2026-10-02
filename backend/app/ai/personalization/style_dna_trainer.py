"""Style DNA training pipeline using FashionCLIP embeddings.

Trains Trenzy's proprietary Style DNA model:
- Uses FashionCLIP embeddings for product representations
- Aggregates user's liked product embeddings
- Trains a classifier to predict style preferences
- Outputs learned style scores (Trenzy Style DNA™)
"""

from __future__ import annotations

from typing import List, Dict, Optional
import logging
import numpy as np
import pickle
from datetime import datetime
from pathlib import Path

from sqlalchemy.orm import Session
from sqlalchemy import and_, func

import lightgbm as lgb
from sklearn.cluster import KMeans

from ...models import Product
from ..models_ai import UserStyleProfile, ProductEmbedding, InteractionEvent

logger = logging.getLogger(__name__)


class StyleDNATrainer:
    """Trains Trenzy's proprietary Style DNA model."""

    STYLE_CATEGORIES = [
        "streetwear", "minimal", "classic", "boho", "casual",
        "formal", "sporty", "ethnic", "vintage", "modern"
    ]

    def __init__(
        self,
        model_dir: str = "models/style_dna",
    ):
        """Initialize Style DNA trainer.

        Args:
            model_dir: Directory to save trained models
        """
        self.model_dir = Path(model_dir)
        self.model_dir.mkdir(parents=True, exist_ok=True)

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
            logger.error("No valid embeddings provided to compute style representation")
            raise ValueError("Cannot compute style representation from empty embeddings list - zero vectors are prohibited")

        # Average the embeddings
        return np.mean(embeddings, axis=0)

    def _train_style_classifier(
        self,
        db: Session,
    ) -> Dict[str, lgb.LGBMClassifier]:
        """Train style classifiers using product catalog.

        Args:
            db: Database session

        Returns:
            Dictionary mapping style to trained classifier
        """
        logger.info("Training style classifiers...")

        # Get products with style labels
        products = db.query(Product).filter(
            Product.is_active == True,
            Product.style.isnot(None),
        ).all()

        if not products:
            logger.warning("No products with style labels found")
            return {}

        # Get product embeddings
        product_ids = [p.id for p in products]
        product_embeddings = db.query(ProductEmbedding).filter(
            ProductEmbedding.product_id.in_(product_ids),
            ProductEmbedding.combined_embedding.isnot(None),
        ).all()

        emb_map = {pe.product_id: np.array(pe.combined_embedding) for pe in product_embeddings}

        # Train a classifier for each style
        classifiers = {}

        for style in self.STYLE_CATEGORIES:
            # Build training data
            X = []
            y = []

            for product in products:
                if product.id in emb_map and product.style:
                    X.append(emb_map[product.id])
                    y.append(1 if product.style.lower() == style else 0)

            if len(X) < 50:  # Need minimum samples
                continue

            X = np.array(X)
            y = np.array(y)

            # Train classifier
            clf = lgb.LGBMClassifier(
                n_estimators=100,
                learning_rate=0.1,
                max_depth=6,
                random_state=42,
                verbose=-1,
            )
            clf.fit(X, y)

            classifiers[style] = clf
            logger.info(f"Trained classifier for {style}")

        return classifiers

    def compute_style_dna(
        self,
        db: Session,
        user_id: int,
        classifiers: Dict[str, lgb.LGBMClassifier],
    ) -> Dict[str, float]:
        """Compute Style DNA for a user using trained classifiers.

        Args:
            db: Database session
            user_id: User ID
            classifiers: Trained style classifiers

        Returns:
            Dictionary of style scores
        """
        # Get user's product embeddings
        user_embeddings = self._get_user_product_embeddings(db, user_id)

        if len(user_embeddings) == 0:
            # Return default scores for new users
            return {style: 0.1 for style in self.STYLE_CATEGORIES}

        # Compute aggregate representation
        style_vector = self._compute_style_representation(user_embeddings)

        # Score against each style classifier
        style_scores = {}

        for style, clf in classifiers.items():
            if hasattr(clf, 'predict_proba'):
                score = clf.predict_proba(style_vector.reshape(1, -1))[0][1]
            else:
                score = float(clf.predict(style_vector.reshape(1, -1))[0])
            style_scores[style] = score

        # Normalize scores
        total = sum(style_scores.values())
        if total > 0:
            style_scores = {k: v / total for k, v in style_scores.items()}

        return style_scores

    def train_and_save(
        self,
        db: Session,
    ):
        """Train style classifiers and save to disk.

        Args:
            db: Database session
        """
        logger.info("Training Style DNA model...")

        # Train classifiers
        classifiers = self._train_style_classifier(db)

        if not classifiers:
            logger.error("Failed to train style classifiers")
            return

        # Save classifiers
        model_path = self.model_dir / f"style_classifiers_{datetime.now().strftime('%Y%m%d')}.pkl"
        with open(model_path, 'wb') as f:
            pickle.dump(classifiers, f)

        logger.info(f"Style classifiers saved to {model_path}")

        return classifiers

    def load_classifiers(
        self,
        model_path: str,
    ) -> Dict[str, lgb.LGBMClassifier]:
        """Load trained style classifiers.

        Args:
            model_path: Path to saved model

        Returns:
            Dictionary of style classifiers
        """
        with open(model_path, 'rb') as f:
            return pickle.load(f)

    def update_user_style_dna(
        self,
        db: Session,
        user_id: int,
        classifiers: Dict[str, lgb.LGBMClassifier],
    ) -> UserStyleProfile:
        """Update a user's Style DNA using trained model.

        Args:
            db: Database session
            user_id: User ID
            classifiers: Trained style classifiers

        Returns:
            Updated UserStyleProfile
        """
        # Compute Style DNA
        style_scores = self.compute_style_dna(db, user_id, classifiers)

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

        logger.info(f"Updated Style DNA for user {user_id}")

        return profile