"""AI Model Registry.

Manages model versions, deployment status, and metadata for all Trenzy ML models.

DEPRECATED: This module now delegates to the consolidated registry.py system.
Use registry.ModelRegistry directly for new code. This file maintains backward compatibility.
"""

from __future__ import annotations

import logging
import warnings
from typing import Dict, List, Optional
from pathlib import Path

logger = logging.getLogger(__name__)

# Emit deprecation warning
warnings.warn(
    "model_registry.py is deprecated. Use registry.ModelRegistry instead.",
    DeprecationWarning,
    stacklevel=2
)

# Import from the consolidated registry for backward compatibility
from .registry import (
    ModelRegistry as _ConsolidatedModelRegistry,
    ModelVersionEntry as _ConsolidatedModelVersionEntry,
    RegistryDisk,
    DEFAULT_MODELS_DIR,
)
from .contracts import ModelStatus

# Re-export for backward compatibility
ModelVersionEntry = _ConsolidatedModelVersionEntry

# Create a compatibility wrapper class
class ModelRegistry:
    """Backward compatibility wrapper for the consolidated ModelRegistry."""
    
    def __init__(self, registry_path: str = "models/registry.json"):
        """Initialize with old-style registry_path for compatibility."""
        self._consolidated = _ConsolidatedModelRegistry()
        self.registry_path = registry_path
        logger.info("Using consolidated registry system (model_registry.py is deprecated)")
    
    # Delegate all methods to the consolidated registry
    def register(self, *args, **kwargs):
        """Delegate to consolidated registry."""
        return self._consolidated.register(*args, **kwargs)
    
    def register_model(self, *args, **kwargs):
        """Backward compatibility for register_model method."""
        return self.register(*args, **kwargs)
    
    def get(self, model_name: str):
        """Delegate to consolidated registry."""
        return self._consolidated.get(model_name)
    
    def get_model_info(self, model_name: str, version: Optional[str] = None) -> Optional[Dict]:
        """Backward compatibility for get_model_info method."""
        entry = self.get(model_name)
        if entry:
            return {
                "model_name": entry.model_name,
                "version": entry.version,
                "artifact_path": entry.artifact_path,
                "model_type": entry.model_type,
                "training_date": entry.training_date,
                "dataset_version": entry.dataset_version,
                "feature_version": entry.feature_version,
                "metrics": entry.metrics,
                "status": entry.status,
                "metadata": entry.metadata,
            }
        return None
    
    def get_production_version(self, model_name: str) -> Optional[str]:
        """Delegate to consolidated registry."""
        entry = self._consolidated.get(model_name)
        return entry.version if entry else None
    
    def set_production_version(self, model_name: str, version: str):
        """Delegate to consolidated registry."""
        return self._consolidated.set_status(model_name, version, "production")
    
    def list_versions(self, model_name: str) -> List[Dict]:
        """Delegate to consolidated registry."""
        entries = self._consolidated.list_versions(model_name)
        return [
            {
                "version": entry.version,
                "status": entry.status,
                "artifact_path": entry.artifact_path,
                "metrics": entry.metrics,
            }
            for entry in entries
        ]
    
    def list_models(self) -> Dict[str, List[str]]:
        """Delegate to consolidated registry."""
        return self._consolidated.summary()


class ModelRegistry:
    """Registry for managing ML model versions and deployment status."""

    def __init__(self, registry_path: str = "models/registry.json"):
        """Initialize model registry.

        Args:
            registry_path: Path to registry JSON file
        """
        self.registry_path = Path(registry_path)
        self.registry_path.parent.mkdir(parents=True, exist_ok=True)
        self.registry: Dict[str, Dict] = self._load_registry()

    def _load_registry(self) -> Dict[str, Dict]:
        """Load registry from disk.

        Returns:
            Registry dictionary
        """
        if self.registry_path.exists():
            try:
                with open(self.registry_path, 'r') as f:
                    return json.load(f)
            except Exception as e:
                logger.warning(f"Failed to load registry: {e}")
                return {}
        return {}

    def _save_registry(self):
        """Save registry to disk."""
        with open(self.registry_path, 'w') as f:
            json.dump(self.registry, f, indent=2)

    def register_model(
        self,
        model_name: str,
        version: str,
        artifact_path: str,
        status: ModelStatus = ModelStatus.DEVELOPMENT,
        metrics: Optional[Dict] = None,
        dataset_version: Optional[str] = None,
        feature_version: Optional[str] = None,
    ):
        """Register a new model version.

        Args:
            model_name: Name of the model
            version: Model version string
            artifact_path: Path to model artifact
            status: Deployment status
            metrics: Evaluation metrics
            dataset_version: Dataset version used for training
            feature_version: Feature version used for training
        """
        if model_name not in self.registry:
            self.registry[model_name] = {}

        self.registry[model_name][version] = {
            "artifact_path": artifact_path,
            "status": status.value,
            "training_date": datetime.utcnow().isoformat(),
            "metrics": metrics or {},
            "dataset_version": dataset_version,
            "feature_version": feature_version,
        }

        self._save_registry()
        logger.info(f"Registered model {model_name} version {version}")

    def get_production_version(self, model_name: str) -> Optional[str]:
        """Get production version for a model.

        Args:
            model_name: Name of the model

        Returns:
            Production version or None
        """
        if model_name not in self.registry:
            return None

        for version, info in self.registry[model_name].items():
            if info.get("status") == ModelStatus.PRODUCTION.value:
                return version

        return None

    def set_production_version(self, model_name: str, version: str):
        """Set production version for a model.

        Args:
            model_name: Name of the model
            version: Version to set as production
        """
        if model_name not in self.registry or version not in self.registry[model_name]:
            logger.warning(f"Model {model_name} version {version} not found")
            return

        # Demote current production version
        current_prod = self.get_production_version(model_name)
        if current_prod:
            self.registry[model_name][current_prod]["status"] = ModelStatus.STAGING.value

        # Promote new version
        self.registry[model_name][version]["status"] = ModelStatus.PRODUCTION.value
        self._save_registry()

        logger.info(f"Set {model_name} version {version} as production")

    def get_model_info(
        self,
        model_name: str,
        version: Optional[str] = None,
    ) -> Optional[Dict]:
        """Get model information.

        Args:
            model_name: Name of the model
            version: Specific version (uses production if None)

        Returns:
            Model info dictionary or None
        """
        if model_name not in self.registry:
            return None

        if version is None:
            version = self.get_production_version(model_name)

        if version is None or version not in self.registry[model_name]:
            return None

        return self.registry[model_name][version]

    def list_models(self) -> Dict[str, List[str]]:
        """List all registered models and their versions.

        Returns:
            Dictionary mapping model names to version lists
        """
        result = {}
        for model_name, versions in self.registry.items():
            result[model_name] = list(versions.keys())
        return result

    def list_versions(self, model_name: str) -> List[Dict]:
        """List all versions of a model with status.

        Args:
            model_name: Name of the model

        Returns:
            List of version info dictionaries
        """
        if model_name not in self.registry:
            return []

        versions = []
        for version, info in self.registry[model_name].items():
            versions.append({
                "version": version,
                "status": info.get("status"),
                "training_date": info.get("training_date"),
                "metrics": info.get("metrics", {}),
            })

        return sorted(versions, key=lambda x: x["training_date"], reverse=True)

    def deprecate_version(self, model_name: str, version: str):
        """Deprecate a model version.

        Args:
            model_name: Name of the model
            version: Version to deprecate
        """
        if model_name in self.registry and version in self.registry[model_name]:
            self.registry[model_name][version]["status"] = ModelStatus.DEPRECATED.value
            self._save_registry()
            logger.info(f"Deprecated {model_name} version {version}")

    def delete_version(self, model_name: str, version: str):
        """Delete a model version from registry.

        Args:
            model_name: Name of the model
            version: Version to delete
        """
        if model_name in self.registry and version in self.registry[model_name]:
            del self.registry[model_name][version]
            if not self.registry[model_name]:
                del self.registry[model_name]
            self._save_registry()
            logger.info(f"Deleted {model_name} version {version}")


# Singleton instance
_registry_instance: Optional[ModelRegistry] = None


def get_model_registry() -> ModelRegistry:
    """Get singleton model registry instance.

    Returns:
        ModelRegistry instance
    """
    global _registry_instance

    if _registry_instance is None:
        _registry_instance = ModelRegistry()

    return _registry_instance
