"""Style DNA model loader.

Loads trained style classifiers and provides inference interface.
"""

from __future__ import annotations

import logging
import pickle
from pathlib import Path
from typing import Optional, Dict
import lightgbm as lgb

logger = logging.getLogger(__name__)


class StyleDNAModelLoader:
    """Loads and manages trained Style DNA models."""

    def __init__(self, model_dir: str = "models/style_dna"):
        """Initialize model loader.

        Args:
            model_dir: Directory containing trained models
        """
        self.model_dir = Path(model_dir)
        self.classifiers: Optional[Dict[str, lgb.LGBMClassifier]] = None
        self.version = None

    def load_model(self, version: str = "v1.0") -> bool:
        """Load trained style classifiers from disk.

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
        model_path = version_dir / "style_classifiers.pkl"
        if not model_path.exists():
            logger.warning(f"Model artifact not found in {version_dir}")
            return False

        try:
            with open(model_path, 'rb') as f:
                self.classifiers = pickle.load(f)

            self.version = version
            logger.info(f"Loaded Style DNA model {version} from {model_path}")
            return True

        except Exception as e:
            logger.error(f"Failed to load Style DNA model: {e}")
            return False

    def is_loaded(self) -> bool:
        """Check if model is loaded.

        Returns:
            True if model is loaded
        """
        return self.classifiers is not None

    def get_version(self) -> Optional[str]:
        """Get current model version.

        Returns:
            Model version or None if not loaded
        """
        return self.version

    def predict_style_scores(
        self,
        style_vector: np.ndarray,
    ) -> Dict[str, float]:
        """Predict style scores for a style vector.

        Args:
            style_vector: Aggregate style vector from user embeddings

        Returns:
            Dictionary of style scores
        """
        if not self.is_loaded():
            logger.warning("Style DNA model not loaded, returning default scores")
            return {style: 0.1 for style in self.STYLE_CATEGORIES}

        style_scores = {}

        for style, clf in self.classifiers.items():
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
