"""Outfit compatibility model loader.

Loads trained compatibility model and provides inference interface.
"""

from __future__ import annotations

import logging
import pickle
from pathlib import Path
from typing import Optional
import lightgbm as lgb

logger = logging.getLogger(__name__)


class OutfitCompatibilityModelLoader:
    """Loads and manages trained outfit compatibility models."""

    def __init__(self, model_dir: str = "models/outfit_compatibility"):
        """Initialize model loader.

        Args:
            model_dir: Directory containing trained models
        """
        self.model_dir = Path(model_dir)
        self.model = None
        self.version = None

    def load_model(self, version: str = "v1.0") -> bool:
        """Load trained compatibility model from disk.

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
            logger.info(f"Loaded outfit compatibility model {version} from {model_path}")
            return True

        except Exception as e:
            logger.error(f"Failed to load outfit compatibility model: {e}")
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

    def predict_compatibility(
        self,
        feature_vector: np.ndarray,
    ) -> float:
        """Predict compatibility score for an outfit.

        Args:
            feature_vector: Outfit feature vector

        Returns:
            Compatibility score (0-1)
        """
        if not self.is_loaded():
            logger.warning("Outfit compatibility model not loaded, returning default score")
            return 0.5

        if hasattr(self.model, 'predict_proba'):
            return self.model.predict_proba(feature_vector.reshape(1, -1))[0][1]
        else:
            return float(self.model.predict(feature_vector.reshape(1, -1))[0])
