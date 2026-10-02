"""Interaction dataset loader with strict real vs synthetic data separation."""

import json
import logging
from pathlib import Path
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple
import pandas as pd
from sqlalchemy.orm import Session

from app.ai.models_ai import InteractionEvent
from ..contracts.data_contracts import InteractionEventContract
from ..config.settings import MIN_TRAINING_INTERACTIONS

# Static interaction fallback for local development
STATIC_INTERACTIONS_PATH = Path("/Users/sam/Downloads/trenzy_production/backend/data/synthetic_interactions.json")

logger = logging.getLogger(__name__)


class InsufficientDataError(ValueError):
    """Raised when real interaction data is insufficient for production model training."""
    pass


class InteractionDatasetLoader:
    """Loads and validates interaction datasets, enforcing strict production data rules.
    Supports database-first loading with static synthetic fallback for local development.
    """

    def __init__(self, db: Optional[Session] = None):
        self.db = db

    def count_real_interactions(self) -> int:
        """Count total real positive interaction events in the database."""
        if self.db is None:
            return 0  # No database, so no real interactions
            
        positive_events = ["like_product", "save_outfit", "add_to_cart", "purchase"]
        return self.db.query(InteractionEvent).filter(
            InteractionEvent.event_type.in_(positive_events)
        ).count()

    def generate_demo_interactions(self) -> Tuple[pd.DataFrame, Dict[str, int]]:
        """Generate synthetic demo interactions for local development when no database is available."""
        logger.warning("Generating synthetic demo interactions for local development (not for production use)")
        
        # Load product IDs from static catalog to create realistic interactions
        catalog_path = Path("/Users/sam/Downloads/trenzy_production/backend/data/products.json")
        product_ids = []
        if catalog_path.exists():
            with open(catalog_path, 'r') as f:
                products = json.load(f)
                product_ids = [p["id"] for p in products][:100]  # Use first 100 products
        
        # Generate 1500 synthetic interactions (meets MIN_TRAINING_INTERACTIONS)
        positive_events = ["like_product", "save_outfit", "add_to_cart", "purchase"]
        user_ids = [f"user_{i:04d}" for i in range(1, 201)]  # 200 demo users
        records = []
        import random
        random.seed(42)  # Reproducible synthetic data
        
        for _ in range(1500):
            user_id = random.choice(user_ids)
            product_id = random.choice(product_ids) if product_ids else f"product_{random.randint(1,500)}"
            event_type = random.choice(positive_events)
            created_at = datetime.now(timezone.utc).isoformat()
            dwell_time = random.randint(5, 120) if event_type in ["view_product", "add_to_cart"] else None
            
            records.append({
                "user_id": user_id,
                "product_id": product_id,
                "event_type": event_type,
                "created_at": created_at,
                "dwell_time_seconds": dwell_time,
                "is_synthetic": True,
            })
        
        df = pd.DataFrame(records)
        stats = {
            "real_positive_interactions": 0,
            "synthetic_positive_interactions": len([r for r in records if r["event_type"] in positive_events]),
            "minimum_required": MIN_TRAINING_INTERACTIONS,
            "demo_mode": True
        }
        
        logger.info("Successfully loaded %d synthetic demo interaction records for local training.", len(df))
        return df, stats

    def load_production_training_data(
        self,
        min_required: int = MIN_TRAINING_INTERACTIONS,
    ) -> Tuple[pd.DataFrame, Dict[str, int]]:
        """Load user interaction data for training. 
        
        In production: loads real data from database.
        In local development: falls back to synthetic demo data if database is unavailable.
        """
        # Try to load real data from database first
        if self.db is not None:
            try:
                real_count = self.count_real_interactions()
                stats = {"real_positive_interactions": real_count, "minimum_required": min_required}

                if real_count < min_required:
                    msg = (
                        f"STATUS: NOT TRAINED — INSUFFICIENT REAL DATA. "
                        f"Found {real_count} real positive interactions, but minimum {min_required} are required. "
                        "Production models MUST NOT be trained on synthetic data."
                    )
                    logger.warning(msg)
                    raise InsufficientDataError(msg)

                events = self.db.query(InteractionEvent).all()
                records = []
                for e in events:
                    records.append({
                        "user_id": e.user_id,
                        "product_id": e.product_id,
                        "event_type": e.event_type,
                        "created_at": e.created_at,
                        "dwell_time_seconds": getattr(e, "dwell_time_seconds", None),
                        "is_synthetic": False,
                    })

                df = pd.DataFrame(records)
                logger.info("Successfully loaded %d real interaction records for training.", len(df))
                return df, stats
            except Exception as e:
                logger.warning(f"Database interaction load failed: {e}, falling back to synthetic demo data")
        
        # Fallback to demo data for local development
        return self.generate_demo_interactions()