"""Model loader for recommendation model.

Loads trained model artifacts and provides inference interface.

The trained models are produced by the ``ml/`` training package
(``ml.recommendation.features.RecommendationFeatureBuilder``) so prediction
must use the SAME feature layout or the model silently mispredicts.
"""

from __future__ import annotations

import logging
import os
import pickle
import sys
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

# The ``ml/`` package lives at repo root (alongside ``backend/``). Make it
# importable regardless of cwd (uvicorn run dir, tests, etc.).
_REPO_ROOT = Path(__file__).resolve().parent.parent.parent.parent
for _p in (str(_REPO_ROOT), str(_REPO_ROOT / "backend")):
    if _p not in sys.path:
        sys.path.insert(0, _p)


class RecommendationModelLoader:
    """Loads and manages trained recommendation models."""

    def __init__(self, model_dir: str = "models/recommendation"):
        """Initialize model loader.

        Args:
            model_dir: Directory containing trained models
        """
        self.model_dir = Path(model_dir)
        self.model = None
        self.metadata = None
        self.version = None
        self._feature_builder = None

    def load_model(self, version: Optional[str] = None) -> bool:
        """Load trained model from disk.

        IMPORTANT: Unpickling the model spawns OpenMP threads that crash if torch
        has already been loaded into the process (duplicate libomp on macOS). This
        must only be called at startup, BEFORE any torch import (see ModelManager).
        Use ``from_registered()`` to reuse a model that was loaded at startup.

        Args:
            version: Model version to load. If None, the production version is
                     auto-discovered from the registry (latest if none marked
                     production).

        Returns:
            True if loaded successfully, False otherwise
        """
        if version is None:
            version = self._discover_production_version()
            if version is None:
                logger.warning("No production recommendation model version on disk")
                return False

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

            # Load metadata
            metadata_path = version_dir / "metadata.json"
            if metadata_path.exists():
                import json
                with open(metadata_path, 'r') as f:
                    self.metadata = json.load(f)

            self.version = version
            self._feature_builder = None
            logger.info(f"Loaded model {version} from {model_path}")
            return True

        except Exception as e:
            logger.error(f"Failed to load model: {e}")
            return False

    @classmethod
    def from_registered(cls, reg, model_dir: Optional[str] = None) -> "RecommendationModelLoader":
        """Build a loader around a model already loaded by the ModelManager.

        Never re-unpickles: it reuses the process-loaded model so request handling
        stays safe (unpickling after torch import is unsafe). The manager loads
        models at startup (before torch), so this is the request-time fast path.
        """
        loader = cls(model_dir=model_dir or "models/recommendation")
        loader.model = reg.model
        loader.version = reg.version
        loader._feature_builder = None

        try:
            version_dir = loader.model_dir / str(reg.version)
            metadata_path = version_dir / "metadata.json"
            if not metadata_path.exists() and reg.artifact_path:
                version_dir = Path(reg.artifact_path).parent
                metadata_path = version_dir / "metadata.json"
            if metadata_path.exists():
                import json
                with open(metadata_path, 'r') as f:
                    loader.metadata = json.load(f)
        except Exception as e:
            logger.warning("Could not read metadata for %s: %s", reg.version, e)
            loader.metadata = None

        return loader

    def _discover_production_version(self) -> Optional[str]:
        """Find the production (or latest) version on disk via the registry."""
        try:
            from app.ai.registry import RegistryDisk
        except Exception:
            from app.ai.registry import RegistryDisk
        disk = RegistryDisk(self.model_dir.parent)
        entry = disk.get_production("recommendation")
        return entry.version if entry else None

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

    def get_metadata(self) -> Optional[dict]:
        """Get model metadata.

        Returns:
            Model metadata or None if not loaded
        """
        return self.metadata

    def get_feature_builder(self, db=None):
        """Lazily create the feature builder matching the trained model's layout."""
        if self._feature_builder is None:
            from ml.recommendation.features import RecommendationFeatureBuilder
            from ml.recommendation.features import FEATURE_SCHEMA_VERSION
            if not self.metadata or "embedding_dim" not in self.metadata:
                raise ValueError("Model metadata is missing required 'embedding_dim' field. Production models only support 512-dim FashionCLIP embeddings.")
            dim = int(self.metadata["embedding_dim"])
            if dim != 512:
                raise ValueError(f"Invalid embedding dimension {dim}. Only 512-dim FashionCLIP embeddings are supported in production. Legacy 384-dim models are retired.")
            self._feature_builder = RecommendationFeatureBuilder(
                embedding_dim=dim, include_embedding=True,
            )
        return self._feature_builder

    def predict(
        self,
        db,
        user_id: int,
        product,
    ) -> float:
        """Predict P(user engages this product) using the trained model.

        Uses the exact feature pipeline the model was trained on
        (``ml.recommendation.features``). Returns 0.5 if the model isn't loaded
        (callers should route to fallbacks instead).

        Args:
            db: Database session.
            user_id: User id.
            product: Product ORM object.

        Returns:
            Prediction score (0-1) or 0.5 if model not loaded.
        """
        if not self.is_loaded():
            logger.warning("Model not loaded, returning default score")
            return 0.5

        try:
            builder = self.get_feature_builder()
            vec = builder.build(db, user_id, product)
            if hasattr(self.model, "predict_proba"):
                return float(self.model.predict_proba(vec.reshape(1, -1))[0][1])
            return float(self.model.predict(vec.reshape(1, -1))[0])
        except Exception as e:
            logger.error("Prediction failed: %s", e)
            return 0.5