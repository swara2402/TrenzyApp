"""Feature engineering for recommendation model.

Builds user, product, and user×product features for training the recommendation model.
"""

import logging
import sys
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import numpy as np
import pandas as pd

from sqlalchemy.orm import Session
from app.db import SessionLocal
from app.models import User, Product
from app.ai.models_ai import InteractionEvent, UserStyleProfile, ProductEmbedding

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class RecommendationFeatureBuilder:
    """Builds features for recommendation model training."""

    def __init__(self):
        """Initialize feature builder."""
        self.style_categories = ["streetwear", "minimal", "classic", "boho", "casual",
                                 "formal", "sporty", "ethnic", "vintage", "modern"]

    def build_user_features(
        self,
        db: Session,
        user_id: int,
        cutoff_date: datetime,
    ) -> Dict[str, float]:
        """Build user-level features.

        Args:
            db: Database session
            user_id: User ID
            cutoff_date: Cutoff date for feature calculation

        Returns:
            Dictionary of user features
        """
        features = {}

        # Get interaction counts
        cutoff_7d = cutoff_date - timedelta(days=7)
        cutoff_30d = cutoff_date - timedelta(days=30)

        # Recent positive interactions
        likes_7d = db.query(InteractionEvent).filter(
            InteractionEvent.user_id == user_id,
            InteractionEvent.event_type == "like_product",
            InteractionEvent.created_at >= cutoff_7d,
        ).count()

        likes_30d = db.query(InteractionEvent).filter(
            InteractionEvent.user_id == user_id,
            InteractionEvent.event_type == "like_product",
            InteractionEvent.created_at >= cutoff_30d,
        ).count()

        views_7d = db.query(InteractionEvent).filter(
            InteractionEvent.user_id == user_id,
            InteractionEvent.event_type == "view_product",
            InteractionEvent.created_at >= cutoff_7d,
        ).count()

        # Wishlist count
        wishlist_count = db.query(InteractionEvent).filter(
            InteractionEvent.user_id == user_id,
            InteractionEvent.event_type == "wishlist",
        ).count()

        # Purchase count
        purchase_count = db.query(InteractionEvent).filter(
            InteractionEvent.user_id == user_id,
            InteractionEvent.event_type == "purchase",
        ).count()

        features.update({
            "likes_7d": float(likes_7d),
            "likes_30d": float(likes_30d),
            "views_7d": float(views_7d),
            "wishlist_count": float(wishlist_count),
            "purchase_count": float(purchase_count),
        })

        # Get average price from purchases
        purchases = db.query(InteractionEvent).filter(
            InteractionEvent.user_id == user_id,
            InteractionEvent.event_type == "purchase",
        ).all()

        if purchases:
            prices = [p.context.get("price", 0) for p in purchases if p.context.get("price")]
            features["average_price"] = float(np.mean(prices)) if prices else 0.0
        else:
            features["average_price"] = 0.0

        # Get Style DNA
        style_profile = db.query(UserStyleProfile).filter(
            UserStyleProfile.user_id == user_id
        ).first()

        if style_profile:
            # Style distribution
            for style in self.style_categories:
                features[f"style_{style}"] = style_profile.style_scores.get(style, 0.0)

            # Price sensitivity
            features["price_sensitivity"] = style_profile.price_sensitivity

            # Confidence
            features["style_confidence"] = style_profile.confidence

            # Interaction count
            features["interaction_count"] = float(style_profile.interaction_count)
        else:
            # Default values for new users
            for style in self.style_categories:
                features[f"style_{style}"] = 0.0
            features["price_sensitivity"] = 0.5
            features["style_confidence"] = 0.0
            features["interaction_count"] = 0.0

        return features

    def build_product_features(
        self,
        db: Session,
        product_id: int,
    ) -> Dict[str, float]:
        """Build product-level features.

        Args:
            db: Database session
            product_id: Product ID

        Returns:
            Dictionary of product features
        """
        features = {}

        product = db.query(Product).filter(Product.id == product_id).first()

        if not product:
            return features

        # Basic attributes
        features["price"] = float(product.price) if product.price else 0.0

        # Category one-hot
        categories = ["tops", "bottoms", "dresses", "outerwear", "footwear",
                     "accessories", "bags", "jewelry"]
        for cat in categories:
            features[f"category_{cat}"] = 1.0 if product.category and product.category.name.lower() == cat else 0.0

        # Style one-hot
        for style in self.style_categories:
            features[f"style_{style}"] = 1.0 if product.style and product.style.lower() == style else 0.0

        # Get popularity (recent views)
        cutoff_7d = datetime.utcnow() - timedelta(days=7)
        views_7d = db.query(InteractionEvent).filter(
            InteractionEvent.entity_id == product_id,
            InteractionEvent.entity_type == "product",
            InteractionEvent.event_type == "view_product",
            InteractionEvent.created_at >= cutoff_7d,
        ).count()

        features["popularity_7d"] = float(views_7d)

        # Get FashionCLIP embedding
        product_emb = db.query(ProductEmbedding).filter(
            ProductEmbedding.product_id == product_id
        ).first()

        if product_emb and product_emb.combined_embedding:
            # Add embedding features (first 128 dimensions for efficiency)
            emb = np.array(product_emb.combined_embedding)
            for i in range(min(128, len(emb))):
                features[f"emb_{i}"] = float(emb[i])
        else:
            # Zero embedding if not available
            for i in range(128):
                features[f"emb_{i}"] = 0.0

        return features

    def build_user_product_features(
        self,
        db: Session,
        user_id: int,
        product_id: int,
        cutoff_date: datetime,
    ) -> Dict[str, float]:
        """Build user×product interaction features.

        Args:
            db: Database session
            user_id: User ID
            product_id: Product ID
            cutoff_date: Cutoff date for feature calculation

        Returns:
            Dictionary of user×product features
        """
        features = {}

        # Previous interactions with this product
        previous_views = db.query(InteractionEvent).filter(
            InteractionEvent.user_id == user_id,
            InteractionEvent.entity_id == product_id,
            InteractionEvent.entity_type == "product",
            InteractionEvent.event_type == "view_product",
            InteractionEvent.created_at < cutoff_date,
        ).count()

        previous_likes = db.query(InteractionEvent).filter(
            InteractionEvent.user_id == user_id,
            InteractionEvent.entity_id == product_id,
            InteractionEvent.entity_type == "product",
            InteractionEvent.event_type == "like_product",
            InteractionEvent.created_at < cutoff_date,
        ).count()

        previous_dislikes = db.query(InteractionEvent).filter(
            InteractionEvent.user_id == user_id,
            InteractionEvent.entity_id == product_id,
            InteractionEvent.entity_type == "product",
            InteractionEvent.event_type == "dislike_product",
            InteractionEvent.created_at < cutoff_date,
        ).count()

        features.update({
            "previous_views": float(previous_views),
            "previous_likes": float(previous_likes),
            "previous_dislikes": float(previous_dislikes),
        })

        # Get product and user for affinity calculations
        product = db.query(Product).filter(Product.id == product_id).first()
        user_style_profile = db.query(UserStyleProfile).filter(
            UserStyleProfile.user_id == user_id
        ).first()

        if product and user_style_profile:
            # Category affinity
            if product.category:
                features["category_affinity"] = user_style_profile.category_scores.get(
                    product.category.name, 0.0
                )
            else:
                features["category_affinity"] = 0.0

            # Brand affinity
            if product.brand:
                features["brand_affinity"] = user_style_profile.brand_scores.get(
                    product.brand.name, 0.0
                )
            else:
                features["brand_affinity"] = 0.0

            # Color affinity
            if product.color:
                features["color_affinity"] = user_style_profile.color_scores.get(
                    product.color, 0.0
                )
            else:
                features["color_affinity"] = 0.0

            # Style affinity
            if product.style:
                features["style_affinity"] = user_style_profile.style_scores.get(
                    product.style.lower(), 0.0
                )
            else:
                features["style_affinity"] = 0.0

            # Price distance
            avg_price = user_style_profile.style_scores.get("average_price", 0.0)
            if product.price:
                features["price_distance"] = abs(float(product.price) - avg_price) / (avg_price + 1.0)
            else:
                features["price_distance"] = 0.0
        else:
            features.update({
                "category_affinity": 0.0,
                "brand_affinity": 0.0,
                "color_affinity": 0.0,
                "style_affinity": 0.0,
                "price_distance": 0.0,
            })

        # Embedding similarity
        user_emb = db.query(UserStyleProfile).filter(
            UserStyleProfile.user_id == user_id
        ).first()

        product_emb = db.query(ProductEmbedding).filter(
            ProductEmbedding.product_id == product_id
        ).first()

        if user_emb and product_emb and product_emb.combined_embedding:
            # Compute cosine similarity
            # Note: UserStyleProfile doesn't store embedding directly, so we'd need to
            # compute it from liked products. For now, use 0.0
            features["embedding_similarity"] = 0.0
        else:
            features["embedding_similarity"] = 0.0

        return features

    def build_features_for_row(
        self,
        row: pd.Series,
        db: Session,
    ) -> Dict[str, float]:
        """Build all features for a single interaction row.

        Args:
            row: DataFrame row with user_id, product_id, timestamp
            db: Database session

        Returns:
            Dictionary of all features
        """
        user_id = row["user_id"]
        product_id = row["product_id"]
        timestamp = row["timestamp"]

        features = {}

        # User features
        user_features = self.build_user_features(db, user_id, timestamp)
        features.update({f"user_{k}": v for k, v in user_features.items()})

        # Product features
        product_features = self.build_product_features(db, product_id)
        features.update({f"product_{k}": v for k, v in product_features.items()})

        # User×Product features
        user_product_features = self.build_user_product_features(
            db, user_id, product_id, timestamp
        )
        features.update({f"interaction_{k}": v for k, v in user_product_features.items()})

        return features

    def build_feature_dataset(
        self,
        df: pd.DataFrame,
        output_path: Path,
    ):
        """Build feature dataset from interaction DataFrame.

        Args:
            df: Interaction DataFrame
            output_path: Path to save feature dataset
        """
        db = SessionLocal()

        try:
            logger.info(f"Building features for {len(df)} interactions...")

            features_list = []
            for idx, row in df.iterrows():
                if idx % 100 == 0:
                    logger.info(f"Processing {idx}/{len(df)}...")

                features = self.build_features_for_row(row, db)
                features["label"] = row["label"]
                features_list.append(features)

            feature_df = pd.DataFrame(features_list)
            feature_df.to_parquet(output_path)

            logger.info(f"Feature dataset saved to {output_path}")
            logger.info(f"Feature shape: {feature_df.shape}")

        finally:
            db.close()


def main():
    """Main entry point."""
    import pandas as pd

    # Load interaction dataset
    data_dir = Path(__file__).parent.parent / "data" / "processed"
    train_df = pd.read_parquet(data_dir / "train.parquet")

    # Build features
    builder = RecommendationFeatureBuilder()
    output_path = data_dir / "train_features.parquet"
    builder.build_feature_dataset(train_df, output_path)

    logger.info("Feature building complete")


if __name__ == "__main__":
    main()
