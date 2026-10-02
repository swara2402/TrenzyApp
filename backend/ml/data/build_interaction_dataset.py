"""Build interaction dataset for ML training.

Extracts user-product interactions from the database and creates labeled datasets
for training recommendation models.

Labeling logic:
- view → 0 (negative/neutral)
- like → 1 (positive)
- wishlist → 1 (positive)
- cart → 1 (positive)
- purchase → 1 (positive)
- dislike → 0 (negative)
"""

import logging
import sys
from pathlib import Path
from datetime import datetime, timedelta
from typing import List, Dict, Tuple
import pandas as pd

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from app.db import SessionLocal
from app.ai.models_ai import InteractionEvent
from app.models import User, Product

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class InteractionDatasetBuilder:
    """Builds labeled interaction datasets for ML training."""

    def __init__(self):
        """Initialize dataset builder."""
        self.event_weights = {
            "view_product": 0.0,
            "like_product": 1.0,
            "dislike_product": 0.0,
            "wishlist": 1.0,
            "remove_wishlist": 0.0,
            "cart_add": 1.0,
            "cart_remove": 0.0,
            "purchase": 1.0,
            "swipe": 0.5,  # Will be determined by score
        }

    def get_interactions(
        self,
        start_date: datetime,
        end_date: datetime,
        min_interactions_per_user: int = 5,
    ) -> pd.DataFrame:
        """Get interactions within a date range.

        Args:
            start_date: Start date for interactions
            end_date: End date for interactions
            min_interactions_per_user: Minimum interactions per user to include

        Returns:
            DataFrame of interactions
        """
        db = SessionLocal()

        try:
            # Query interactions
            events = db.query(InteractionEvent).filter(
                InteractionEvent.created_at >= start_date,
                InteractionEvent.created_at <= end_date,
                InteractionEvent.entity_type == "product",
                InteractionEvent.entity_id.isnot(None),
            ).all()

            logger.info(f"Found {len(events)} interactions between {start_date} and {end_date}")

            # Convert to DataFrame
            data = []
            for event in events:
                label = self._get_label(event)

                if label is not None:
                    data.append({
                        "user_id": event.user_id,
                        "product_id": event.entity_id,
                        "event_type": event.event_type,
                        "timestamp": event.created_at,
                        "label": label,
                        "context": event.context,
                    })

            df = pd.DataFrame(data)

            if df.empty:
                logger.warning("No interactions found after labeling")
                return df

            # Filter users with minimum interactions
            user_counts = df["user_id"].value_counts()
            valid_users = user_counts[user_counts >= min_interactions_per_user].index
            df = df[df["user_id"].isin(valid_users)]

            logger.info(f"Filtered to {len(df)} interactions from {len(valid_users)} users")

            return df

        finally:
            db.close()

    def _get_label(self, event: InteractionEvent) -> Optional[float]:
        """Get label for an event based on event type and context.

        Args:
            event: InteractionEvent instance

        Returns:
            Label (0 or 1) or None if event should be skipped
        """
        event_type = event.event_type

        # Handle swipe events (check score in context)
        if event_type == "swipe":
            score = event.context.get("score", 0)
            return 1.0 if score > 0 else 0.0

        # Use predefined weights
        return self.event_weights.get(event_type, None)

    def build_training_dataset(
        self,
        train_start: datetime,
        train_end: datetime,
        val_start: datetime,
        val_end: datetime,
        test_start: datetime,
        test_end: datetime,
        output_dir: Path,
    ):
        """Build train/validation/test splits with time-based splitting.

        Args:
            train_start: Training data start date
            train_end: Training data end date
            val_start: Validation data start date
            val_end: Validation data end date
            test_start: Test data start date
            test_end: Test data end date
            output_dir: Directory to save datasets
        """
        output_dir.mkdir(parents=True, exist_ok=True)

        logger.info("Building training dataset...")
        train_df = self.get_interactions(train_start, train_end)
        train_df.to_parquet(output_dir / "train.parquet")
        logger.info(f"Training dataset: {len(train_df)} interactions")

        logger.info("Building validation dataset...")
        val_df = self.get_interactions(val_start, val_end)
        val_df.to_parquet(output_dir / "val.parquet")
        logger.info(f"Validation dataset: {len(val_df)} interactions")

        logger.info("Building test dataset...")
        test_df = self.get_interactions(test_start, test_end)
        test_df.to_parquet(output_dir / "test.parquet")
        logger.info(f"Test dataset: {len(test_df)} interactions")

        # Save metadata
        metadata = {
            "train_size": len(train_df),
            "val_size": len(val_df),
            "test_size": len(test_df),
            "train_period": f"{train_start} to {train_end}",
            "val_period": f"{val_start} to {val_end}",
            "test_period": f"{test_start} to {test_end}",
            "created_at": datetime.utcnow().isoformat(),
        }

        import json
        with open(output_dir / "metadata.json", "w") as f:
            json.dump(metadata, f, indent=2)

        logger.info(f"Datasets saved to {output_dir}")

    def build_features_dataset(
        self,
        df: pd.DataFrame,
        db: Session,
    ) -> pd.DataFrame:
        """Build feature-rich dataset with user and product attributes.

        Args:
            df: Interaction DataFrame
            db: Database session

        Returns:
            DataFrame with features
        """
        # Get unique user IDs and product IDs
        user_ids = df["user_id"].unique()
        product_ids = df["product_id"].unique()

        # Fetch user attributes
        users = db.query(User).filter(User.id.in_(user_ids)).all()
        user_attrs = {u.id: {
            "created_at": u.created_at,
        } for u in users}

        # Fetch product attributes
        products = db.query(Product).filter(Product.id.in_(product_ids)).all()
        product_attrs = {p.id: {
            "category": p.category.name if p.category else None,
            "brand": p.brand.name if p.brand else None,
            "price": p.price,
            "color": p.color,
            "style": p.style,
        } for p in products}

        # Add features to DataFrame
        df["user_created_at"] = df["user_id"].map(lambda x: user_attrs.get(x, {}).get("created_at"))
        df["product_category"] = df["product_id"].map(lambda x: product_attrs.get(x, {}).get("category"))
        df["product_brand"] = df["product_id"].map(lambda x: product_attrs.get(x, {}).get("brand"))
        df["product_price"] = df["product_id"].map(lambda x: product_attrs.get(x, {}).get("price"))
        df["product_color"] = df["product_id"].map(lambda x: product_attrs.get(x, {}).get("color"))
        df["product_style"] = df["product_id"].map(lambda x: product_attrs.get(x, {}).get("style"))

        return df


def main():
    """Main entry point."""
    builder = InteractionDatasetBuilder()

    # Define time periods (adjust based on your data)
    # Example: 3 months training, 1 month validation, 1 month test
    end_date = datetime.utcnow()
    test_start = end_date - timedelta(days=30)
    test_end = end_date

    val_start = test_start - timedelta(days=30)
    val_end = test_start

    train_start = val_start - timedelta(days=90)
    train_end = val_start

    output_dir = Path(__file__).parent / "processed"

    builder.build_training_dataset(
        train_start=train_start,
        train_end=train_end,
        val_start=val_start,
        val_end=val_end,
        test_start=test_start,
        test_end=test_end,
        output_dir=output_dir,
    )

    logger.info("Dataset building complete")


if __name__ == "__main__":
    main()
