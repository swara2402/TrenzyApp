"""Feature metadata registry."""

from typing import List, Dict, Any
from ..config.settings import FEATURE_NAMES


class FeatureRegistry:
    """Registry documenting feature names, definitions, and versions."""

    VERSION = "v1"

    @classmethod
    def get_feature_names(cls) -> List[str]:
        return list(FEATURE_NAMES)

    @classmethod
    def get_feature_count(cls) -> int:
        return len(FEATURE_NAMES)

    @classmethod
    def describe_features(cls) -> Dict[str, str]:
        descriptions = {}
        for name in FEATURE_NAMES:
            if name.startswith("user_style_"):
                descriptions[name] = f"User preference score for {name.replace('user_style_', '')} style"
            elif name.startswith("user_color_"):
                descriptions[name] = f"User preference score for {name.replace('user_color_', '')} color"
            elif name.startswith("user_fit_"):
                descriptions[name] = f"User preference score for {name.replace('user_fit_', '')} fit"
            elif name == "user_price_sensitivity":
                descriptions[name] = "User price sensitivity score [0.0 - 1.0]"
            elif name == "product_price_norm":
                descriptions[name] = "Product price normalized by 10,000 INR baseline"
            elif name.startswith("prod_cat_"):
                descriptions[name] = f"One-hot indicator for category {name.replace('prod_cat_', '')}"
            else:
                descriptions[name] = "Generic feature"
        return descriptions
