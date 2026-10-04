"""Model versioning and deployment automation.

DEPRECATED: This module is consolidated into registry.py. Use registry.ModelRegistry instead.
This file maintains backward compatibility for existing code.
"""

from __future__ import annotations

import logging
import warnings
from typing import Optional, Dict, List
from datetime import datetime
from pathlib import Path
import shutil

from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

# Emit deprecation warning
warnings.warn(
    "model_versioning.py is deprecated. Use registry.ModelRegistry instead.",
    DeprecationWarning,
    stacklevel=2
)

# Import from the consolidated registry for backward compatibility
from .registry import ModelRegistry as _ConsolidatedModelRegistry
from .contracts import ModelStatus


class ModelVersioning:
    """Backward compatibility wrapper for model versioning operations."""
    
    def __init__(
        self,
        model_registry: Optional[_ConsolidatedModelRegistry] = None,
        evaluation_pipeline: Optional = None,  # Kept for compatibility but not used
    ):
        """Initialize model versioning with consolidated registry."""
        self.model_registry = model_registry or _ConsolidatedModelRegistry()
        self.evaluation_pipeline = evaluation_pipeline  # Not used in consolidated system
    
    def create_new_version(
        self,
        model_name: str,
        artifact_path: str,
        metrics: Optional[Dict] = None,
        dataset_version: Optional[str] = None,
        feature_version: Optional[str] = None,
    ) -> str:
        """Create a new model version."""
        # Get current versions to determine next version number
        versions = self.model_registry.list_versions(model_name)
        version_count = len(versions)
        new_version = f"v{version_count + 1}.0"
        
        # Register new version
        self.model_registry.register(
            model_name=model_name,
            version=new_version,
            artifact_path=artifact_path,
            metrics=metrics,
            dataset_version=dataset_version,
            feature_version=feature_version,
            status="development",  # Start in development
        )
        
        logger.info(f"Created new version {new_version} for {model_name}")
        return new_version
    
    def promote_to_production(
        self,
        model_name: str,
        version: str,
        require_evaluation: bool = True,
        min_metrics: Optional[Dict[str, float]] = None,
    ) -> bool:
        """Promote a model version to production."""
        logger.info(f"Promoting {model_name} version {version} to production...")
        
        # Check if version exists
        entry = self.model_registry._disk.get_version(model_name, version)
        if not entry:
            logger.error(f"Model version {version} not found")
            return False
        
        # In consolidated system, we use promote_if_better or direct set_status
        # For backward compatibility, we'll use set_status directly
        success = self.model_registry.set_status(model_name, version, "production")
        
        if success:
            logger.info(f"Promoted {model_name} version {version} to production")
        else:
            logger.error(f"Failed to promote {model_name} version {version}")
        
        return success
    
    def rollback(
        self,
        model_name: str,
        target_version: Optional[str] = None,
    ) -> bool:
        """Rollback to a previous version."""
        logger.info(f"Rolling back {model_name}...")
        
        # Get current production version
        current = self.model_registry._disk.get_production(model_name)
        if not current:
            logger.warning(f"No production version found for {model_name}")
            return False
        
        # Get target version
        if target_version is None:
            versions = self.model_registry.list_versions(model_name)
            try:
                current_idx = next(i for i, v in enumerate(versions) if v.version == current.version)
                if current_idx == 0:
                    logger.warning("No previous version available for rollback")
                    return False
                target_version = versions[current_idx - 1].version
            except StopIteration:
                logger.warning("Current version not found in version list")
                return False
        
        # Promote target version
        success = self.model_registry.set_status(model_name, target_version, "production")
        
        if success:
            # Demote current version
            self.model_registry.set_status(model_name, current.version, "staging")
            logger.info(f"Rolled back {model_name} from {current.version} to {target_version}")
        
        return success
    
    def auto_promote(
        self,
        db: Session,
        model_name: str,
        staging_version: str,
        production_version: Optional[str] = None,
        improvement_threshold: float = 0.05,
    ) -> bool:
        """Automatically promote if staging version outperforms production."""
        logger.info(f"Auto-promoting {model_name} version {staging_version}...")
        
        # Use the consolidated promote_if_better method
        return self.model_registry.promote_if_better(
            model_name=model_name,
            candidate_version=staging_version,
            metric="ndcg@10",
            higher_is_better=True,
        )
    
    def cleanup_old_versions(
        self,
        model_name: str,
        keep_versions: int = 5,
    ) -> int:
        """Clean up old model versions."""
        logger.info(f"Cleaning up old versions for {model_name}...")
        
        versions = self.model_registry.list_versions(model_name)
        if len(versions) <= keep_versions:
            logger.info(f"Only {len(versions)} versions, keeping all")
            return 0
        
        # In consolidated system, we don't auto-delete artifacts
        # This is a safety feature - manual cleanup required
        logger.info(f"Manual cleanup required for {len(versions) - keep_versions} old versions")
        return 0
    
    def get_version_history(
        self,
        model_name: str,
    ) -> List[Dict]:
        """Get version history for a model."""
        versions = self.model_registry.list_versions(model_name)
        return [
            {
                "version": v.version,
                "status": v.status,
                "artifact_path": v.artifact_path,
                "metrics": v.metrics,
                "training_date": v.training_date,
            }
            for v in versions
        ]


class ModelVersioning:
    """Automated model versioning and deployment."""

    def __init__(
        self,
        model_registry: Optional[ModelRegistry] = None,
        evaluation_pipeline: Optional[EvaluationPipeline] = None,
    ):
        """Initialize model versioning.

        Args:
            model_registry: Model registry instance
            evaluation_pipeline: Evaluation pipeline instance
        """
        self.model_registry = model_registry or ModelRegistry()
        self.evaluation_pipeline = evaluation_pipeline or EvaluationPipeline()

    def create_new_version(
        self,
        model_name: str,
        artifact_path: str,
        metrics: Optional[Dict] = None,
        dataset_version: Optional[str] = None,
        feature_version: Optional[str] = None,
    ) -> str:
        """Create a new model version.

        Args:
            model_name: Name of the model
            artifact_path: Path to model artifact
            metrics: Evaluation metrics
            dataset_version: Dataset version used
            feature_version: Feature version used

        Returns:
            New version string
        """
        # Get current versions
        versions = self.model_registry.list_versions(model_name)
        version_count = len(versions)

        # Generate new version number
        new_version = f"v{version_count + 1}.0"

        # Register new version
        self.model_registry.register_model(
            model_name=model_name,
            version=new_version,
            artifact_path=artifact_path,
            status=ModelStatus.STAGING,
            metrics=metrics,
            dataset_version=dataset_version,
            feature_version=feature_version,
        )

        logger.info(f"Created new version {new_version} for {model_name}")

        return new_version

    def promote_to_production(
        self,
        model_name: str,
        version: str,
        require_evaluation: bool = True,
        min_metrics: Optional[Dict[str, float]] = None,
    ) -> bool:
        """Promote a model version to production.

        Args:
            model_name: Name of the model
            version: Version to promote
            require_evaluation: Whether to require evaluation before promotion
            min_metrics: Minimum required metrics for promotion

        Returns:
            True if promoted successfully
        """
        logger.info(f"Promoting {model_name} version {version} to production...")

        # Check if version exists
        model_info = self.model_registry.get_model_info(model_name, version)
        if not model_info:
            logger.error(f"Model version {version} not found")
            return False

        # Check evaluation if required
        if require_evaluation:
            from ..db import get_session
            db = next(get_session())

            try:
                # Get online metrics
                metrics = self.evaluation_pipeline.evaluate_model_online(
                    db=db,
                    model_name=model_name,
                    version=version,
                    days=7,
                )

                # Check minimum metrics
                if min_metrics:
                    for metric, min_value in min_metrics.items():
                        if metrics.get(metric, 0.0) < min_value:
                            logger.warning(
                                f"Metric {metric} ({metrics.get(metric, 0.0)}) below minimum ({min_value})"
                            )
                            return False

                logger.info(f"Evaluation passed for version {version}")
            finally:
                db.close()

        # Promote to production
        self.model_registry.set_production_version(model_name, version)

        logger.info(f"Promoted {model_name} version {version} to production")

        return True

    def rollback(
        self,
        model_name: str,
        target_version: Optional[str] = None,
    ) -> bool:
        """Rollback to a previous version.

        Args:
            model_name: Name of the model
            target_version: Target version (uses previous if None)

        Returns:
            True if rolled back successfully
        """
        logger.info(f"Rolling back {model_name}...")

        # Get current production version
        current_version = self.model_registry.get_production_version(model_name)

        if not current_version:
            logger.warning(f"No production version found for {model_name}")
            return False

        # Get target version
        if target_version is None:
            # Get previous version
            versions = self.model_registry.list_versions(model_name)
            current_idx = next(
                (i for i, v in enumerate(versions) if v["version"] == current_version),
                None,
            )

            if current_idx is None or current_idx == len(versions) - 1:
                logger.warning("No previous version available for rollback")
                return False

            target_version = versions[current_idx + 1]["version"]

        # Promote target version
        success = self.promote_to_production(
            model_name=model_name,
            version=target_version,
            require_evaluation=False,  # Skip evaluation for rollback
        )

        if success:
            # Deprecate rolled-back version
            self.model_registry.deprecate_version(model_name, current_version)
            logger.info(f"Rolled back {model_name} from {current_version} to {target_version}")

        return success

    def auto_promote(
        self,
        db: Session,
        model_name: str,
        staging_version: str,
        production_version: Optional[str] = None,
        improvement_threshold: float = 0.05,
    ) -> bool:
        """Automatically promote if staging version outperforms production.

        Args:
            db: Database session
            model_name: Name of the model
            staging_version: Staging version to evaluate
            production_version: Current production version
            improvement_threshold: Minimum improvement required

        Returns:
            True if promoted successfully
        """
        logger.info(f"Auto-promoting {model_name} version {staging_version}...")

        # Get production version
        if production_version is None:
            production_version = self.model_registry.get_production_version(model_name)

        if not production_version:
            # No production version, promote staging
            return self.promote_to_production(
                model_name=model_name,
                version=staging_version,
                require_evaluation=True,
            )

        # Compare versions
        comparison = self.evaluation_pipeline.compare_models(
            db=db,
            model_name=model_name,
            version_a=staging_version,
            version_b=production_version,
            days=7,
        )

        # Check improvement
        ctr_improvement = comparison["improvement"].get("click_through_rate", 0.0)

        if ctr_improvement >= improvement_threshold:
            logger.info(f"Staging version improves CTR by {ctr_improvement:.2%}, promoting")
            return self.promote_to_production(
                model_name=model_name,
                version=staging_version,
                require_evaluation=False,
            )
        else:
            logger.info(
                f"Staging version does not meet improvement threshold "
                f"({ctr_improvement:.2%} < {improvement_threshold:.2%})"
            )
            return False

    def cleanup_old_versions(
        self,
        model_name: str,
        keep_versions: int = 5,
    ) -> int:
        """Clean up old model versions.

        Args:
            model_name: Name of the model
            keep_versions: Number of versions to keep

        Returns:
            Number of versions deleted
        """
        logger.info(f"Cleaning up old versions for {model_name}...")

        versions = self.model_registry.list_versions(model_name)

        if len(versions) <= keep_versions:
            logger.info(f"Only {len(versions)} versions, keeping all")
            return 0

        # Delete old versions (except production and recent ones)
        production_version = self.model_registry.get_production_version(model_name)
        deleted_count = 0

        for version_info in versions[keep_versions:]:
            version = version_info["version"]

            # Don't delete production version
            if version == production_version:
                continue

            # Delete from registry
            self.model_registry.delete_version(model_name, version)

            # Delete artifact files
            model_dir = Path(self.model_registry.registry_path).parent / model_name / version
            if model_dir.exists():
                shutil.rmtree(model_dir)

            deleted_count += 1
            logger.info(f"Deleted version {version}")

        return deleted_count

    def get_version_history(
        self,
        model_name: str,
    ) -> List[Dict]:
        """Get version history for a model.

        Args:
            model_name: Name of the model

        Returns:
            List of version information
        """
        return self.model_registry.list_versions(model_name)
