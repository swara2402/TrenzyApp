"""Blend ML model loader.

Loads trained blend model and provides inference interface.
"""

from __future__ import annotations

import logging
import pickle
from pathlib import Path
from typing import Optional
import lightgbm as lgb

logger = logging.getLogger(__name__)


class BlendModelLoader:
    """Loads and manages trained blend models."""

    def __init__(self, model_dir: str = "models/blend"):
        """Initialize model loader.

        Args:
            model_dir: Directory containing trained models
        """
        self.model_dir = Path(model_dir)
        self.model = None
        self.version = None

    def load_model(self, version: str = "v1.0") -> bool:
        """Load trained blend model from disk.

        Args:
            version: Model version to load

        Returns:
            True if loaded successfully, False otherwise
        """
        version_dir = self.model_dir / version

        if not version_dir.exists():
            logger.warning(f"Model version directory not found: {version_dir}")
            return False

        # Load model artifact
        model_path = version_dir / "model.lightgbm"
        if not model_path.exists():
            model_path = version_dir / "model.xgboost"

        if not model_path.exists():
            logger.warning(f"Model artifact not found in {version_dir}")
            return False

        try:
            with open(model_path, 'rb') as f:
                self.model = pickle.load(f)

            self.version = version
            logger.info(f"Loaded blend model {version} from {model_path}")
            return True

        except Exception as e:
            logger.error(f"Failed to load blend model: {e}")
            return False

    def is_loaded(self) -> bool:
        """Check if model is loaded.

        Returns:
            True if model is loaded
        """
        return self.model is not None

    def get_version(self) -> Optional[str]:
        """Get current model version.

        Returns:
            Model version or None if not loaded
        """
        return self.version

    def predict_group_preference(
        self,
        feature_vector: np.ndarray,
    ) -> float:
        """Predict group preference score for a product.

        Args:
            feature_vector: Group feature vector

        Returns:
            Preference score (0-1)
        """
        if not self.is_loaded():
            logger.warning("Blend model not loaded, returning default score")
            return 0.5

        if hasattr(self.model, 'predict_proba'):
            return self.model.predict_proba(feature_vector.reshape(1, -1))[0][1]
        else:
            return float(self.model.predict(feature_vector.reshape(1, -1))[0])
