"""Production model registry with automated gate enforcement."""

import logging
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Dict, List, Optional, Any
from sqlalchemy.orm import Session

from app.ai.models_ai import ModelVersion
from ..evaluation.gates import ModelQualityGates, GateCheckResult

logger = logging.getLogger(__name__)


@dataclass
class ModelMetadata:
    """Metadata container for registered models."""
    model_name: str
    version: str
    artifact_path: str
    model_type: str
    metrics: Dict[str, Any]
    status: str = "development"
    feature_version: str = "v1"
    dataset_version: str = "v1"
    training_date: Optional[datetime] = None


class ProductionModelRegistry:
    """Manages model versions and enforces production promotion criteria."""

    def __init__(self, db: Session):
        self.db = db
        self.gate_evaluator = ModelQualityGates()

    def register_candidate(
        self,
        model_name: str,
        version: str,
        artifact_path: str,
        model_type: str,
        metrics: Dict[str, Any],
        dataset_version: str = "v1",
        feature_version: str = "v1",
    ) -> ModelVersion:
        """Register a new candidate model in development status."""
        now = datetime.now(timezone.utc)
        record = ModelVersion(
            model_name=model_name,
            version=version,
            artifact_path=artifact_path,
            model_type=model_type,
            training_date=now,
            dataset_version=dataset_version,
            feature_version=feature_version,
            metrics=metrics,
            status="development",
            created_at=now,
        )
        self.db.add(record)
        self.db.commit()
        self.db.refresh(record)
        logger.info("Registered model candidate %s:%s in status 'development'", model_name, version)
        return record

    def promote_to_production(
        self,
        model_name: str,
        version: str,
        total_interactions: int = 0,
    ) -> GateCheckResult:
        """Evaluate gate requirements and promote only if all gates pass."""
        record = self.db.query(ModelVersion).filter(
            ModelVersion.model_name == model_name,
            ModelVersion.version == version,
        ).first()

        if not record:
            raise ValueError(f"Model version {model_name}:{version} not found")

        # Evaluate quality gates
        metrics = record.metrics or {}
        gate_result = self.gate_evaluator.evaluate(
            metrics=metrics,
            model_version=f"{model_name}:{version}",
            total_interactions=total_interactions,
        )

        if not gate_result.passed:
            logger.warning(
                "Model %s:%s FAILED quality gates and CANNOT be promoted:\n%s",
                model_name, version, gate_result.summary()
            )
            return gate_result

        # Demote current production model if any
        current_prod = self.db.query(ModelVersion).filter(
            ModelVersion.model_name == model_name,
            ModelVersion.status == "production",
        ).all()
        for p in current_prod:
            p.status = "archived"

        # Promote
        record.status = "production"
        record.promoted_at = datetime.now(timezone.utc)
        self.db.commit()
        logger.info("PROMOTED model %s:%s to production!", model_name, version)
        return gate_result

    def get_production_model(self, model_name: str) -> Optional[ModelVersion]:
        """Fetch the active production model version."""
        return self.db.query(ModelVersion).filter(
            ModelVersion.model_name == model_name,
            ModelVersion.status == "production",
        ).first()
