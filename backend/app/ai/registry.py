"""Model Registry and versioning.

Tracks every Trenzy ML model, its versions, artifact paths, training metadata,
metrics, and deployment status. The registry is the single source of truth for
which model version is in ``production`` vs ``staging`` vs ``development``.

Two layers:
- **Disk layer**: scans ``models/`` for versioned artifact directories and reads
  each version's ``metadata.json``.
- **DB layer**: persists a ``model_versions`` row per trained version so status
  transitions (promotion) are durable and auditable.

Promotion policy (Phase 19):
    ``new_model_metric > production_metric`` triggers promotion. This module exposes
    ``promote`` which atomically flips status rows and updates the on-disk pointer.
"""

from __future__ import annotations

import json
import logging
import shutil
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

# Directory layout (relative to repo root / backend run dir):
#   models/<model_name>/<version>/model.<ext>
#   models/<model_name>/<version>/metadata.json
DEFAULT_MODELS_DIR = Path(__file__).resolve().parent.parent.parent.parent / "models"


@dataclass
class ModelVersionEntry:
    """A single versioned model artifact on disk."""
    model_name: str
    version: str
    artifact_path: str
    model_type: Optional[str] = None
    training_date: Optional[str] = None
    dataset_version: Optional[str] = None
    feature_version: Optional[str] = None
    metrics: Optional[dict] = None
    status: Optional[str] = None  # development | staging | production | deprecated
    metadata: Optional[dict] = None


def _utcnow_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class RegistryDisk:
    """Scans and manages model artifacts on disk."""

    def __init__(self, models_dir: Optional[Path] = None):
        self.models_dir = Path(models_dir or DEFAULT_MODELS_DIR)

    def list_versions(self, model_name: str) -> list[ModelVersionEntry]:
        """List all versioned artifacts for a model on disk."""
        model_dir = self.models_dir / model_name
        if not model_dir.exists():
            return []
        entries: list[ModelVersionEntry] = []
        for version_dir in sorted(model_dir.iterdir()):
            if not version_dir.is_dir():
                continue
            artifact = self._find_artifact(version_dir)
            if artifact is None:
                continue
            metadata = self._read_metadata(version_dir)
            entry = ModelVersionEntry(
                model_name=model_name,
                version=version_dir.name,
                artifact_path=str(artifact),
                model_type=metadata.get("model_type") if metadata else None,
                training_date=metadata.get("training_date") if metadata else None,
                dataset_version=metadata.get("dataset_version") if metadata else None,
                feature_version=metadata.get("feature_version") if metadata else None,
                metrics=metadata.get("metrics") if metadata else None,
                status=metadata.get("status") if metadata else None,
                metadata=metadata,
            )
            entries.append(entry)
        return sorted(entries, key=lambda e: e.version)

    def get_version(self, model_name: str, version: str) -> Optional[ModelVersionEntry]:
        """Get a specific versioned artifact."""
        for entry in self.list_versions(model_name):
            if entry.version == version:
                return entry
        return None

    def get_production(self, model_name: str) -> Optional[ModelVersionEntry]:
        """Get the production version for a model.
        
        STRICT PROMOTION POLICY: Only returns explicitly marked production models.
        Never falls back to latest/highest version (prevents dev models from 
        accidentally being used in production).
        
        Returns None if no production model exists - callers must use baselines.
        """
        entries = self.list_versions(model_name)
        for entry in entries:
            status = (entry.status or "").lower()
            if status == "production":
                return entry
        # No production model found - return None to trigger fallback chain
        logger.warning("No explicitly marked production model found for %s - will use baseline", model_name)
        return None

    def write_metadata(self, model_name: str, version: str, metadata: dict) -> Path:
        """Write metadata.json for a version."""
        version_dir = self.models_dir / model_name / version
        version_dir.mkdir(parents=True, exist_ok=True)
        path = version_dir / "metadata.json"
        path.write_text(json.dumps(metadata, indent=2, default=str))
        return path

    def _find_artifact(self, version_dir: Path) -> Optional[Path]:
        for suffix in ("lightgbm", "xgboost", "joblib", "pkl"):
            candidate = version_dir / f"model.{suffix}"
            if candidate.exists():
                return candidate
        return None

    def _read_metadata(self, version_dir: Path) -> Optional[dict]:
        path = version_dir / "metadata.json"
        if not path.exists():
            return None
        try:
            return json.loads(path.read_text())
        except Exception as e:
            logger.warning("Failed to read metadata %s: %s", path, e)
            return None


class ModelRegistry:
    """Stable interface over disk + DB registry."""

    _disk = RegistryDisk()

    @classmethod
    def _db_available(cls) -> bool:
        try:
            from ..db import SessionLocal  # noqa: F401
            return True
        except Exception:
            return False

    @classmethod
    def register(
        cls,
        model_name: str,
        version: str,
        artifact_path: str,
        model_type: Optional[str] = None,
        training_date: Optional[str] = None,
        dataset_version: Optional[str] = None,
        feature_version: Optional[str] = None,
        metrics: Optional[dict] = None,
        status: str = "development",
    ) -> dict:
        """Register a trained model version.

        Persists a disk metadata.json and (when available) a DB row.
        """
        # Disk metadata
        metadata = {
            "model_name": model_name,
            "version": version,
            "artifact_path": artifact_path,
            "model_type": model_type,
            "training_date": training_date or _utcnow_iso(),
            "dataset_version": dataset_version,
            "feature_version": feature_version,
            "metrics": metrics or {},
            "status": status,
            "registered_at": _utcnow_iso(),
        }
        cls._disk.write_metadata(model_name, version, metadata)

        # DB row (best-effort)
        db_entry = None
        if cls._db_available():
            try:
                from sqlalchemy.orm import Session as ORMSession
                from ..db import SessionLocal
                from .models_ai import ModelVersion
                db = SessionLocal()
                try:
                    row = db.query(ModelVersion).filter_by(
                        model_name=model_name, version=version
                    ).first()
                    if row:
                        row.artifact_path = artifact_path
                        row.status = status
                        row.metrics = metrics or {}
                    else:
                        db.add(ModelVersion(
                            model_name=model_name,
                            version=version,
                            artifact_path=artifact_path,
                            model_type=model_type,
                            training_date=(
                                datetime.fromisoformat(training_date) if training_date else None
                            ),
                            dataset_version=dataset_version,
                            feature_version=feature_version,
                            metrics=metrics or {},
                            status=status,
                        ))
                    db.commit()
                    db.refresh(row) if row is not None else None
                except Exception as e:
                    logger.warning("DB registry write failed (continuing on disk): %s", e)
                    db.rollback()
                finally:
                    db.close()
            except Exception as e:
                logger.warning("DB registry unavailable (continuing on disk): %s", e)

        return metadata

    @classmethod
    def get(cls, model_name: str) -> Optional[ModelVersionEntry]:
        """Get the current (best) version for a model: production > latest."""
        return cls._disk.get_production(model_name)

    @classmethod
    def list_versions(cls, model_name: str) -> list[ModelVersionEntry]:
        """List all versions for a model."""
        return cls._disk.list_versions(model_name)

    @classmethod
    def set_status(cls, model_name: str, version: str, status: str) -> Optional[ModelVersionEntry]:
        """Set the deployment status of a model version. Promotes/demotes atomically."""
        entry = cls._disk.get_version(model_name, version)
        if entry is None:
            logger.error("Cannot set status: %s %s not found on disk", model_name, version)
            return None

        # If promoting to production, demote previous production first.
        if status == "production":
            for other in cls._disk.list_versions(model_name):
                if other.version != version and (other.status or "").lower() == "production":
                    self = cls()
                    self._update_status(model_name, other.version, "staging")

        self = cls()
        self._update_status(model_name, version, status)
        return cls._disk.get_version(model_name, version)

    def _update_status(self, model_name: str, version: str, status: str) -> None:
        """Update status in disk metadata + DB row (best-effort)."""
        entry = self._disk.get_version(model_name, version)
        if entry is None:
            return
        metadata = entry.metadata or {}
        metadata["status"] = status
        metadata["promoted_at"] = _utcnow_iso()
        self._disk.write_metadata(model_name, version, metadata)

        if self._db_available():
            try:
                from ..db import SessionLocal
                from .models_ai import ModelVersion
                db = SessionLocal()
                try:
                    row = db.query(ModelVersion).filter_by(
                        model_name=model_name, version=version
                    ).first()
                    if row:
                        row.status = status
                        db.commit()
                except Exception as e:
                    logger.warning("DB registry status update failed: %s", e)
                    db.rollback()
                finally:
                    db.close()
            except Exception as e:
                logger.warning("DB registry unavailable for status update: %s", e)

    @classmethod
    def promote_if_better(
        cls,
        model_name: str,
        candidate_version: str,
        metric: str = "ndcg@10",
        higher_is_better: bool = True,
    ) -> bool:
        """Promote a candidate version if it beats the current production version.

        Promotion condition (Phase 19):
            ``new_model_metric > production_metric`` (for higher_is_better=True)

        Args:
            model_name: Model name.
            candidate_version: Version to consider for promotion.
            metric: Metric name to compare.
            higher_is_better: Whether a larger metric value is better.

        Returns:
            True if promoted.
        """
        candidate = cls._disk.get_version(model_name, candidate_version)
        if candidate is None or not candidate.metrics:
            logger.info("No metrics for candidate %s %s; not promoting", model_name, candidate_version)
            return False

        production = cls._disk.get_production(model_name)
        candidate_value = candidate.metrics.get(metric)
        if candidate_value is None:
            logger.info("Candidate %s has no metric %r; not promoting", candidate_version, metric)
            return False

        if production is None:
            logger.info("No production model; promoting %s %s (first)", model_name, candidate_version)
            cls.set_status(model_name, candidate_version, "production")
            return True

        production_value = (production.metrics or {}).get(metric)
        if production_value is None and production.version == candidate_version:
            cls.set_status(model_name, candidate_version, "production")
            return True

        if production_value is None:
            logger.info("Production has no metric %r; promoting candidate", metric)
            cls.set_status(model_name, candidate_version, "production")
            return True

        better = candidate_value > production_value if higher_is_better else candidate_value < production_value
        if better:
            logger.info(
                "Promoting %s %s (metric %s: %.4f > %.4f)",
                model_name, candidate_version, metric, candidate_value, production_value,
            )
            cls.set_status(model_name, candidate_version, "production")
            return True

        logger.info(
            "Not promoting %s %s (metric %s: %.4f <= production %.4f)",
            model_name, candidate_version, metric, candidate_value, production_value,
        )
        return False

    @classmethod
    def summary(cls) -> dict:
        """Summarize all registered models and their production versions."""
        model_names = [
            "recommendation", "style_dna", "outfit_compatibility", "blend", "trend"
        ]
        result = {}
        for name in model_names:
            production = cls._disk.get_production(name)
            versions = cls._disk.list_versions(name)
            result[name] = {
                "production": production.version if production else None,
                "versions": [v.version for v in versions],
                "artifact": production.artifact_path if production else None,
                "metrics": production.metrics if production else None,
            }
        return result