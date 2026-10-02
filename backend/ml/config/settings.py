"""Central settings for Trenzy ML pipelines."""

import os
from pathlib import Path
from dataclasses import dataclass, field
from typing import Dict, List, Any

# Inherit canonical embedding dimension
try:
    from app.ai.ml_config import EMBEDDING_DIM
except Exception:
    EMBEDDING_DIM = 512

EMBEDDING_MODEL_NAME = "fashionclip"
EMBEDDING_VERSION = "1.0"

# Minimum required interactions before any model may be trained
MIN_TRAINING_INTERACTIONS = 1000

# Strict quality gate thresholds for model promotion
EVALUATION_GATES: Dict[str, float] = {
    "min_precision_at_10": 0.15,
    "min_recall_at_10": 0.20,
    "min_ndcg_at_10": 0.25,
    "min_hit_rate_at_10": 0.30,
    "min_catalog_coverage": 0.10,
    "max_duplicate_rate": 0.0,
}

FEATURE_NAMES: List[str] = [
    # User Style Scores (10)
    "user_style_streetwear", "user_style_minimal", "user_style_classic", "user_style_boho",
    "user_style_casual", "user_style_formal", "user_style_sporty", "user_style_ethnic",
    "user_style_vintage", "user_style_modern",
    # User Color Scores (10)
    "user_color_black", "user_color_white", "user_color_gray", "user_color_navy",
    "user_color_beige", "user_color_brown", "user_color_red", "user_color_blue",
    "user_color_green", "user_color_pink",
    # User Fit Scores (5)
    "user_fit_oversized", "user_fit_relaxed", "user_fit_slim", "user_fit_regular",
    "user_fit_athletic",
    # User Price Sensitivity (1)
    "user_price_sensitivity",
    # Product Normalized Price (1)
    "product_price_norm",
    # Product Category One-Hot (8)
    "prod_cat_tops", "prod_cat_bottoms", "prod_cat_dresses", "prod_cat_outerwear",
    "prod_cat_footwear", "prod_cat_accessories", "prod_cat_bags", "prod_cat_jewelry",
]


@dataclass
class MLSettings:
    """Dataclass holding ML environment settings."""
    embedding_dim: int = EMBEDDING_DIM
    embedding_model: str = EMBEDDING_MODEL_NAME
    embedding_version: str = EMBEDDING_VERSION
    min_training_interactions: int = MIN_TRAINING_INTERACTIONS
    eval_gates: Dict[str, float] = field(default_factory=lambda: dict(EVALUATION_GATES))
    artifacts_dir: Path = field(
        default_factory=lambda: Path(os.getenv("ML_ARTIFACTS_DIR", "models"))
    )
    reports_dir: Path = field(
        default_factory=lambda: Path(os.getenv("ML_REPORTS_DIR", "reports"))
    )


_settings_instance = None


def get_ml_settings() -> MLSettings:
    """Get singleton MLSettings instance."""
    global _settings_instance
    if _settings_instance is None:
        _settings_instance = MLSettings()
    return _settings_instance
