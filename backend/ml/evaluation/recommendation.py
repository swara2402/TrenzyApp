"""Evaluation metrics for recommendation model.

Compares ML model performance against rule-based baseline.
"""

import logging
import sys
from pathlib import Path
from typing import Dict, List, Tuple
import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from app.db import SessionLocal
from app.ai.models_ai import InteractionEvent
from app.ai.evaluation.metrics import RecommendationMetrics

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class RecommendationEvaluator:
    """Evaluates recommendation model against baseline."""

    def __init__(self):
        """Initialize evaluator."""
        self.metrics_calculator = RecommendationMetrics()

    def evaluate_model(
        self,
        predictions: List[int],
        labels: List[int],
        k: int = 10,
    ) -> Dict[str, float]:
        """Evaluate model predictions.

        Args:
            predictions: Predicted labels
            labels: Ground truth labels
            k: K for precision/recall metrics

        Returns:
            Dictionary of metrics
        """
        metrics = {}

        # Precision@K
        precision_k = self.metrics_calculator.precision_at_k(predictions, labels, k)
        metrics[f"precision_at_{k}"] = precision_k

        # Recall@K
        recall_k = self.metrics_calculator.recall_at_k(predictions, labels, k)
        metrics[f"recall_at_{k}"] = recall_k

        # NDCG@K
        ndcg_k = self.metrics_calculator.ndcg_at_k(predictions, labels, k)
        metrics[f"ndcg_at_{k}"] = ndcg_k

        # Hit Rate@K
        hit_rate_k = self.metrics_calculator.hit_rate_at_k(predictions, labels, k)
        metrics[f"hit_rate_at_{k}"] = hit_rate_k

        # Overall accuracy
        accuracy = np.mean(np.array(predictions) == np.array(labels))
        metrics["accuracy"] = accuracy

        return metrics

    def evaluate_baseline(
        self,
        db: Session,
        user_id: int,
        k: int = 10,
    ) -> Dict[str, float]:
        """Evaluate rule-based baseline performance.

        Args:
            db: Database session
            user_id: User ID to evaluate
            k: Number of recommendations

        Returns:
            Dictionary of baseline metrics
        """
        # Get user's actual likes
        cutoff_date = datetime.utcnow() - timedelta(days=7)
        actual_likes = db.query(InteractionEvent).filter(
            InteractionEvent.user_id == user_id,
            InteractionEvent.event_type == "like_product",
            InteractionEvent.created_at >= cutoff_date,
        ).all()

        actual_product_ids = {e.entity_id for e in actual_likes if e.entity_id}

        # Simulate baseline recommendations (e.g., popularity-based)
        # This would need to be implemented based on actual baseline logic
        baseline_recommendations = self._get_baseline_recommendations(db, user_id, k)

        # Calculate metrics
        recommended_ids = {r["id"] for r in baseline_recommendations}
        hits = len(actual_product_ids & recommended_ids)

        metrics = {
            "precision_at_k": hits / k if k > 0 else 0.0,
            "recall_at_k": hits / len(actual_product_ids) if actual_product_ids else 0.0,
            "hit_rate_at_k": 1.0 if hits > 0 else 0.0,
        }

        return metrics

    def _get_baseline_recommendations(
        self,
        db: Session,
        user_id: int,
        k: int,
    ) -> List[Dict]:
        """Get baseline rule-based recommendations.

        Args:
            db: Database session
            user_id: User ID
            k: Number of recommendations

        Returns:
            List of recommended products
        """
        # This should match the actual baseline logic in recommendations.py
        # For now, return top-rated products as a simple baseline
        from app.models import Product

        products = db.query(Product).filter(
            Product.is_active == True
        ).order_by(Product.rating.desc()).limit(k).all()

        return [{"id": p.id, "rating": p.rating} for p in products]

    def compare_with_baseline(
        self,
        model_metrics: Dict[str, float],
        baseline_metrics: Dict[str, float],
    ) -> Dict[str, float]:
        """Compare model metrics against baseline.

        Args:
            model_metrics: Model performance metrics
            baseline_metrics: Baseline performance metrics

        Returns:
            Dictionary of improvements (positive = model better)
        """
        improvements = {}

        for metric in model_metrics:
            if metric in baseline_metrics:
                improvement = model_metrics[metric] - baseline_metrics[metric]
                improvements[f"{metric}_improvement"] = improvement
                improvements[f"{metric}_relative"] = (
                    improvement / baseline_metrics[metric] * 100
                    if baseline_metrics[metric] != 0 else 0.0
                )

        return improvements

    def generate_report(
        self,
        model_metrics: Dict[str, float],
        baseline_metrics: Dict[str, float],
        improvements: Dict[str, float],
        output_path: Path,
    ):
        """Generate evaluation report.

        Args:
            model_metrics: Model performance metrics
            baseline_metrics: Baseline performance metrics
            improvements: Improvement metrics
            output_path: Path to save report
        """
        report = {
            "evaluation_date": datetime.utcnow().isoformat(),
            "model_metrics": model_metrics,
            "baseline_metrics": baseline_metrics,
            "improvements": improvements,
            "summary": {
                "model_better": sum(1 for v in improvements.values() if v > 0),
                "total_metrics": len(improvements),
            },
        }

        import json
        with open(output_path, 'w') as f:
            json.dump(report, f, indent=2)

        logger.info(f"Evaluation report saved to {output_path}")


def main():
    """Main entry point."""
    evaluator = RecommendationEvaluator()

    # Example evaluation (would be run with actual model predictions)
    predictions = [1, 0, 1, 1, 0, 1, 0, 1, 0, 1]
    labels = [1, 0, 1, 0, 0, 1, 1, 1, 0, 1]

    model_metrics = evaluator.evaluate_model(predictions, labels, k=10)
    logger.info(f"Model metrics: {model_metrics}")

    # Baseline evaluation would require actual user data
    # baseline_metrics = evaluator.evaluate_baseline(db, user_id=1, k=10)

    # improvements = evaluator.compare_with_baseline(model_metrics, baseline_metrics)
    # logger.info(f"Improvements: {improvements}")


if __name__ == "__main__":
    main()
