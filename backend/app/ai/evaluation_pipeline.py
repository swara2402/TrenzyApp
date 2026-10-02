"""Model evaluation pipeline.

Automated evaluation of ML models using offline metrics and online feedback.
"""

from __future__ import annotations

import logging
from typing import Dict, List, Optional, Tuple
from datetime import datetime, timedelta
from pathlib import Path
import json

from sqlalchemy.orm import Session
from sqlalchemy import func

from .registry import ModelRegistry
from .feedback_loop import FeedbackLoop

logger = logging.getLogger(__name__)


class EvaluationPipeline:
    """Automated evaluation pipeline for ML models."""

    def __init__(
        self,
        model_registry: Optional[ModelRegistry] = None,
        feedback_loop: Optional[FeedbackLoop] = None,
    ):
        """Initialize evaluation pipeline.

        Args:
            model_registry: Model registry instance
            feedback_loop: Feedback loop instance
        """
        self.model_registry = model_registry or ModelRegistry()
        self.feedback_loop = feedback_loop or FeedbackLoop()
        self.evaluator = RecommendationEvaluator()

    def evaluate_model_offline(
        self,
        db: Session,
        model_name: str,
        version: str,
        test_data_path: Optional[str] = None,
    ) -> Dict[str, float]:
        """Evaluate model using offline metrics.

        Args:
            db: Database session
            model_name: Name of the model
            version: Model version
            test_data_path: Path to test dataset

        Returns:
            Dictionary of evaluation metrics
        """
        logger.info(f"Evaluating {model_name} version {version} offline...")

        if model_name == "recommendation":
            return self._evaluate_recommendation_offline(db, version, test_data_path)
        else:
            logger.warning(f"Offline evaluation not implemented for {model_name}")
            return {}

    def _evaluate_recommendation_offline(
        self,
        db: Session,
        version: str,
        test_data_path: Optional[str],
    ) -> Dict[str, float]:
        """Evaluate recommendation model offline.

        Args:
            db: Database session
            version: Model version
            test_data_path: Path to test dataset

        Returns:
            Dictionary of evaluation metrics
        """
        # Load test data
        if test_data_path and Path(test_data_path).exists():
            with open(test_data_path, 'r') as f:
                test_data = json.load(f)
        else:
            # Use interaction events for evaluation
            from ..models_ai import InteractionEvent
            test_data = []

            # Get recent interactions for evaluation
            week_ago = datetime.utcnow() - timedelta(days=7)
            events = db.query(InteractionEvent).filter(
                InteractionEvent.event_type.in_(["like_product", "wishlist"]),
                InteractionEvent.created_at >= week_ago,
            ).limit(1000).all()

            for event in events:
                test_data.append({
                    "user_id": event.user_id,
                    "product_id": event.entity_id,
                    "label": 1,  # Positive interaction
                })

        # Run evaluation
        metrics = self.evaluator.evaluate(
            test_data=test_data,
            model_version=version,
        )

        return metrics

    def evaluate_model_online(
        self,
        db: Session,
        model_name: str,
        version: str,
        days: int = 7,
    ) -> Dict[str, float]:
        """Evaluate model using online feedback metrics.

        Args:
            db: Database session
            model_name: Name of the model
            version: Model version
            days: Number of days to evaluate

        Returns:
            Dictionary of online metrics
        """
        logger.info(f"Evaluating {model_name} version {version} online...")

        start_date = datetime.utcnow() - timedelta(days=days)
        end_date = datetime.utcnow()

        metrics = self.feedback_loop.get_feedback_metrics(
            db=db,
            model_version=version,
            start_date=start_date,
            end_date=end_date,
        )

        return metrics

    def compare_models(
        self,
        db: Session,
        model_name: str,
        version_a: str,
        version_b: str,
        days: int = 7,
    ) -> Dict[str, Dict[str, float]]:
        """Compare two model versions.

        Args:
            db: Database session
            model_name: Name of the model
            version_a: First version
            version_b: Second version
            days: Number of days to evaluate

        Returns:
            Dictionary comparing metrics for both versions
        """
        logger.info(f"Comparing {model_name} versions {version_a} vs {version_b}...")

        metrics_a = self.evaluate_model_online(db, model_name, version_a, days)
        metrics_b = self.evaluate_model_online(db, model_name, version_b, days)

        comparison = {
            "version_a": version_a,
            "version_b": version_b,
            "metrics_a": metrics_a,
            "metrics_b": metrics_b,
            "improvement": {},
        }

        # Calculate improvement
        for key in metrics_a:
            if key in metrics_b and metrics_b[key] > 0:
                improvement = (metrics_a[key] - metrics_b[key]) / metrics_b[key] * 100
                comparison["improvement"][key] = improvement

        return comparison

    def generate_evaluation_report(
        self,
        db: Session,
        model_name: str,
        version: str,
        output_path: Optional[str] = None,
    ) -> str:
        """Generate comprehensive evaluation report.

        Args:
            db: Database session
            model_name: Name of the model
            version: Model version
            output_path: Path to save report

        Returns:
            Report content
        """
        logger.info(f"Generating evaluation report for {model_name} version {version}...")

        # Get model info
        model_info = self.model_registry.get_model_info(model_name, version)

        # Get offline metrics
        offline_metrics = self.evaluate_model_offline(db, model_name, version)

        # Get online metrics
        online_metrics = self.evaluate_model_online(db, model_name, version)

        # Build report
        report = f"""
# Model Evaluation Report

**Model**: {model_name}
**Version**: {version}
**Generated**: {datetime.utcnow().isoformat()}

## Model Information
- **Status**: {model_info.get('status', 'unknown') if model_info else 'unknown'}
- **Training Date**: {model_info.get('training_date', 'unknown') if model_info else 'unknown'}
- **Dataset Version**: {model_info.get('dataset_version', 'unknown') if model_info else 'unknown'}
- **Feature Version**: {model_info.get('feature_version', 'unknown') if model_info else 'unknown'}

## Offline Metrics
"""

        for metric, value in offline_metrics.items():
            report += f"- **{metric}**: {value:.4f}\n"

        report += "\n## Online Metrics (Last 7 Days)\n"

        for metric, value in online_metrics.items():
            report += f"- **{metric}**: {value:.4f}\n"

        report += "\n## Recommendations\n"

        # Simple recommendations based on metrics
        ctr = online_metrics.get("click_through_rate", 0.0)
        if ctr > 0.05:
            report += "- Model performing well (CTR > 5%)\n"
        elif ctr > 0.02:
            report += "- Model performing adequately (CTR > 2%)\n"
        else:
            report += "- Model needs improvement (CTR < 2%)\n"

        # Save report
        if output_path:
            Path(output_path).parent.mkdir(parents=True, exist_ok=True)
            with open(output_path, 'w') as f:
                f.write(report)
            logger.info(f"Report saved to {output_path}")

        return report

    def run_daily_evaluation(
        self,
        db: Session,
        model_name: str,
    ) -> Dict[str, Dict[str, float]]:
        """Run daily evaluation for production model.

        Args:
            db: Database session
            model_name: Name of the model

        Returns:
            Dictionary of evaluation results
        """
        logger.info(f"Running daily evaluation for {model_name}...")

        # Get production version
        version = self.model_registry.get_production_version(model_name)

        if not version:
            logger.warning(f"No production version found for {model_name}")
            return {}

        # Evaluate
        metrics = self.evaluate_model_online(db, model_name, version, days=1)

        return {
            "model_name": model_name,
            "version": version,
            "metrics": metrics,
            "evaluated_at": datetime.utcnow().isoformat(),
        }
