"""AI evaluation metrics tracking.

Tracks performance metrics for:
- Recommendations (precision@K, recall@K, NDCG@K, CTR, conversion)
- Outfit generation (compatibility, acceptance)
- AI stylist (relevance, acceptance, completion)
- Trend prediction (MAE, RMSE, directional accuracy)
"""

from __future__ import annotations

from typing import List, Dict, Optional
import logging
import numpy as np
from datetime import datetime, timedelta

from sqlalchemy.orm import Session
from sqlalchemy import func, and_

from ...models import Product
from ..models_ai import (
    RecommendationEvent,
    OutfitGeneration,
    ModelEvaluation,
)

logger = logging.getLogger(__name__)


class RecommendationMetrics:
    """Metrics for recommendation systems."""

    @staticmethod
    def precision_at_k(
        recommended: List[int],
        relevant: List[int],
        k: int,
    ) -> float:
        """Compute Precision@K.

        Args:
            recommended: List of recommended item IDs
            relevant: List of relevant item IDs
            k: Cutoff position

        Returns:
            Precision@K score
        """
        recommended_at_k = recommended[:k]
        relevant_at_k = [item for item in recommended_at_k if item in relevant]

        return len(relevant_at_k) / k if k > 0 else 0.0

    @staticmethod
    def recall_at_k(
        recommended: List[int],
        relevant: List[int],
        k: int,
    ) -> float:
        """Compute Recall@K.

        Args:
            recommended: List of recommended item IDs
            relevant: List of relevant item IDs
            k: Cutoff position

        Returns:
            Recall@K score
        """
        recommended_at_k = recommended[:k]
        relevant_at_k = [item for item in recommended_at_k if item in relevant]

        return len(relevant_at_k) / len(relevant) if relevant else 0.0

    @staticmethod
    def ndcg_at_k(
        recommended: List[int],
        relevant: List[int],
        k: int,
    ) -> float:
        """Compute NDCG@K (Normalized Discounted Cumulative Gain).

        Args:
            recommended: List of recommended item IDs
            relevant: List of relevant item IDs
            k: Cutoff position

        Returns:
            NDCG@K score
        """
        def dcg_at_k(relevances: List[int], k: int) -> float:
            """Compute DCG@K."""
            return sum(
                (2**relevances[i] - 1) / np.log2(i + 2)
                for i in range(min(k, len(relevances)))
            )

        # Create relevance scores (1 if relevant, 0 otherwise)
        relevances = [1 if item in relevant else 0 for item in recommended[:k]]

        # Compute DCG
        dcg = dcg_at_k(relevances, k)

        # Compute ideal DCG (all relevant)
        ideal_relevances = [1] * min(k, len(relevant))
        idcg = dcg_at_k(ideal_relevances, k)

        return dcg / idcg if idcg > 0 else 0.0

    @staticmethod
    def diversity(
        recommended: List[int],
        db: Session,
    ) -> float:
        """Compute diversity of recommendations.

        Measures how different the recommended items are from each other.

        Args:
            recommended: List of recommended product IDs
            db: Database session

        Returns:
            Diversity score (0-1)
        """
        if len(recommended) < 2:
            return 0.0

        products = db.query(Product).filter(Product.id.in_(recommended)).all()

        # Simple diversity based on categories
        categories = set(p.category_id for p in products if p.category_id)
        brands = set(p.brand_id for p in products if p.brand_id)

        # Diversity as ratio of unique categories/brands to total
        category_diversity = len(categories) / len(products) if products else 0
        brand_diversity = len(brands) / len(products) if products else 0

        return (category_diversity + brand_diversity) / 2


class OutfitMetrics:
    """Metrics for outfit generation."""

    @staticmethod
    def compute_compatibility_score(
        outfit_items: List[Dict],
    ) -> float:
        """Compute outfit compatibility score.

        Args:
            outfit_items: List of outfit items with attributes

        Returns:
            Compatibility score (0-1)
        """
        # This would use the OutfitCompatibilityScorer
        # Placeholder implementation
        return 0.8

    @staticmethod
    def compute_acceptance_rate(
        db: Session,
        model_version: str,
        days: int = 30,
    ) -> float:
        """Compute outfit generation acceptance rate.

        Args:
            db: Database session
            model_version: Model version
            days: Number of days to look back

        Returns:
            Acceptance rate (0-1)
        """
        cutoff = datetime.utcnow() - timedelta(days=days)

        generations = db.query(OutfitGeneration).filter(
            OutfitGeneration.model_version == model_version,
            OutfitGeneration.created_at >= cutoff,
        ).all()

        if not generations:
            return 0.0

        saved_count = sum(1 for g in generations if g.saved)
        return saved_count / len(generations)


class TrendMetrics:
    """Metrics for trend prediction."""

    @staticmethod
    def compute_mae(
        predicted: List[float],
        actual: List[float],
    ) -> float:
        """Compute Mean Absolute Error.

        Args:
            predicted: Predicted values
            actual: Actual values

        Returns:
            MAE
        """
        if len(predicted) != len(actual) or len(predicted) == 0:
            return 0.0

        return np.mean(np.abs(np.array(predicted) - np.array(actual)))

    @staticmethod
    def compute_rmse(
        predicted: List[float],
        actual: List[float],
    ) -> float:
        """Compute Root Mean Square Error.

        Args:
            predicted: Predicted values
            actual: Actual values

        Returns:
            RMSE
        """
        if len(predicted) != len(actual) or len(predicted) == 0:
            return 0.0

        return np.sqrt(np.mean((np.array(predicted) - np.array(actual)) ** 2))

    @staticmethod
    def compute_directional_accuracy(
        predicted: List[float],
        actual: List[float],
    ) -> float:
        """Compute directional accuracy.

        Measures if predictions correctly predicted the direction of change.

        Args:
            predicted: Predicted values
            actual: Actual values

        Returns:
            Directional accuracy (0-1)
        """
        if len(predicted) != len(actual) or len(predicted) < 2:
            return 0.0

        correct = 0
        for i in range(1, len(predicted)):
            pred_change = predicted[i] - predicted[i-1]
            actual_change = actual[i] - actual[i-1]

            if (pred_change > 0 and actual_change > 0) or (pred_change < 0 and actual_change < 0):
                correct += 1

        return correct / (len(predicted) - 1)


class ModelEvaluator:
    """Main evaluator for tracking AI model performance."""

    def __init__(self):
        """Initialize model evaluator."""
        self.rec_metrics = RecommendationMetrics()
        self.outfit_metrics = OutfitMetrics()
        self.trend_metrics = TrendMetrics()

    def evaluate_recommendation_model(
        self,
        db: Session,
        model_name: str,
        model_version: str,
        days: int = 30,
    ) -> ModelEvaluation:
        """Evaluate recommendation model performance.

        Args:
            db: Database session
            model_name: Model name
            model_version: Model version
            days: Number of days to evaluate

        Returns:
            ModelEvaluation instance
        """
        cutoff = datetime.utcnow() - timedelta(days=days)

        # Get recommendation events
        events = db.query(RecommendationEvent).filter(
            RecommendationEvent.model_version == model_version,
            RecommendationEvent.created_at >= cutoff,
        ).all()

        if not events:
            logger.warning(f"No recommendation events found for {model_version}")
            return None

        # Compute metrics
        total_clicks = 0
        total_impressions = 0
        total_conversions = 0

        for event in events:
            feedback = event.feedback or {}
            clicked = feedback.get("clicked", [])
            total_impressions += len(event.recommended_products)
            total_clicks += len(clicked)

            # Count conversions (purchases)
            conversions = feedback.get("conversions", [])
            total_conversions += len(conversions)

        ctr = total_clicks / total_impressions if total_impressions > 0 else 0.0
        conversion_rate = total_conversions / total_impressions if total_impressions > 0 else 0.0

        # Compute NDCG@10 for a sample
        ndcg_scores = []
        for event in events[:100]:  # Sample 100 events
            feedback = event.feedback or {}
            clicked = feedback.get("clicked", [])
            ndcg = self.rec_metrics.ndcg_at_k(event.recommended_products, clicked, 10)
            ndcg_scores.append(ndcg)

        avg_ndcg = np.mean(ndcg_scores) if ndcg_scores else 0.0

        # Create evaluation record
        evaluation = ModelEvaluation(
            model_name=model_name,
            model_version=model_version,
            evaluation_type="recommendation",
            metrics={
                "ctr": ctr,
                "conversion_rate": conversion_rate,
                "ndcg@10": avg_ndcg,
                "sample_size": len(events),
            },
            evaluation_period_start=cutoff,
            evaluation_period_end=datetime.utcnow(),
            sample_size=len(events),
        )

        db.add(evaluation)
        db.commit()

        logger.info(f"Evaluated {model_name} v{model_version}: CTR={ctr:.3f}, NDCG@10={avg_ndcg:.3f}")

        return evaluation

    def evaluate_outfit_model(
        self,
        db: Session,
        model_name: str,
        model_version: str,
        days: int = 30,
    ) -> ModelEvaluation:
        """Evaluate outfit generation model performance.

        Args:
            db: Database session
            model_name: Model name
            model_version: Model version
            days: Number of days to evaluate

        Returns:
            ModelEvaluation instance
        """
        cutoff = datetime.utcnow() - timedelta(days=days)

        generations = db.query(OutfitGeneration).filter(
            OutfitGeneration.model_version == model_version,
            OutfitGeneration.created_at >= cutoff,
        ).all()

        if not generations:
            logger.warning(f"No outfit generations found for {model_version}")
            return None

        # Compute metrics
        saved_count = sum(1 for g in generations if g.saved)
        modified_count = sum(1 for g in generations if g.modified)
        avg_compatibility = np.mean([g.compatibility_score for g in generations])

        acceptance_rate = saved_count / len(generations)
        modification_rate = modified_count / len(generations)

        evaluation = ModelEvaluation(
            model_name=model_name,
            model_version=model_version,
            evaluation_type="outfit_generation",
            metrics={
                "acceptance_rate": acceptance_rate,
                "modification_rate": modification_rate,
                "avg_compatibility": avg_compatibility,
                "total_generations": len(generations),
            },
            evaluation_period_start=cutoff,
            evaluation_period_end=datetime.utcnow(),
            sample_size=len(generations),
        )

        db.add(evaluation)
        db.commit()

        logger.info(f"Evaluated {model_name} v{model_version}: Acceptance={acceptance_rate:.3f}")

        return evaluation

    def get_model_performance_history(
        self,
        db: Session,
        model_name: str,
        evaluation_type: str,
        limit: int = 10,
    ) -> List[ModelEvaluation]:
        """Get performance history for a model.

        Args:
            db: Database session
            model_name: Model name
            evaluation_type: Type of evaluation
            limit: Number of records to return

        Returns:
            List of ModelEvaluation instances
        """
        return db.query(ModelEvaluation).filter(
            ModelEvaluation.model_name == model_name,
            ModelEvaluation.evaluation_type == evaluation_type,
        ).order_by(ModelEvaluation.created_at.desc()).limit(limit).all()
