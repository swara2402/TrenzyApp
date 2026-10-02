"""Feature extraction pipeline for recommendation modeling."""

from typing import Dict, List, Optional
import numpy as np

from app.models import Product
from app.ai.models_ai import UserStyleProfile
from ..config.settings import FEATURE_NAMES


class FeatureExtractor:
    """Extracts tabular features for user-product ranking."""

    STYLE_CATEGORIES = [
        "streetwear", "minimal", "classic", "boho", "casual",
        "formal", "sporty", "ethnic", "vintage", "modern",
    ]
    COLOR_KEYS = [
        "black", "white", "gray", "navy", "beige",
        "brown", "red", "blue", "green", "pink",
    ]
    FIT_CATEGORIES = ["oversized", "relaxed", "slim", "regular", "athletic"]
    CATEGORIES = [
        "tops", "bottoms", "dresses", "outerwear",
        "footwear", "accessories", "bags", "jewelry",
    ]

    def extract(
        self,
        user_profile: Optional[UserStyleProfile],
        product: Product,
    ) -> np.ndarray:
        """Extract a single feature vector matching FEATURE_NAMES."""
        features: List[float] = []

        # User style scores (10)
        style_scores = user_profile.style_scores if (user_profile and user_profile.style_scores) else {}
        for s in self.STYLE_CATEGORIES:
            features.append(float(style_scores.get(s, 0.1)))

        # User color scores (10)
        color_scores = user_profile.color_scores if (user_profile and user_profile.color_scores) else {}
        for c in self.COLOR_KEYS:
            features.append(float(color_scores.get(c, 0.0)))

        # User fit scores (5)
        fit_scores = user_profile.fit_scores if (user_profile and user_profile.fit_scores) else {}
        for f in self.FIT_CATEGORIES:
            features.append(float(fit_scores.get(f, 0.2)))

        # User price sensitivity (1)
        price_sens = user_profile.price_sensitivity if user_profile else 0.5
        features.append(float(price_sens))

        # Product normalized price (1)
        price_val = float(product.price or 0.0)
        features.append(min(price_val / 10000.0, 5.0))

        # Product category one-hot (8)
        prod_cat = (product.category or "").lower()
        for cat in self.CATEGORIES:
            features.append(1.0 if prod_cat == cat else 0.0)

        res = np.array(features, dtype=np.float32)
        assert len(res) == len(FEATURE_NAMES), (
            f"Feature dimension {len(res)} != expected {len(FEATURE_NAMES)}"
        )
        return res
