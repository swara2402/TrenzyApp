"""Train recommendation model on real PostgreSQL production data.

This script trains the recommendation model using real user interaction data
from PostgreSQL instead of demo SQLite data. It implements proper temporal
splitting and fair evaluation against the baseline.

Usage:
    python -m ml.recommendation.train_production --version v2 --rounds 120
    python -m ml.recommendation.train_production --version v2 --evaluate-baseline
"""

from __future__ import annotations

import logging
import sys
from pathlib import Path
from datetime import datetime
from typing import Optional

# Add backend to path
backend_dir = Path(__file__).parent.parent.parent / "backend"
sys.path.insert(0, str(backend_dir))

from app.db import SessionLocal, engine
from app.ai.registry import ModelRegistry
from app.ai.models_ai import InteractionEvent
from app.ai.model_metadata import (
    generate_standard_metadata,
    save_metadata,
    create_model_card,
)
from ml.data.build_interaction_dataset import InteractionDatasetBuilder
from ml.evaluation.recommendation import (
    ranking_metrics_for_user,
    aggregate_over_users,
    RuleBaseLineRecommender,
    evaluate_rule_baseline,
    compute_historical_user_preferences,
)
from ml.recommendation.features import RecommendationFeatureBuilder
import lightgbm as lgb
import numpy as np
import pickle
import json

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class ProductionRecommendationTrainer:
    """Train recommendation model on real production data."""

    def __init__(
        self,
        model_type: str = "lightgbm",
        models_dir: str = "models/recommendation",
    ):
        """Initialize production trainer.

        Args:
            model_type: Model type (lightgbm or xgboost)
            models_dir: Directory to save trained models
        """
        self.model_type = model_type
        self.models_dir = Path(models_dir)
        self.models_dir.mkdir(parents=True, exist_ok=True)
        self.registry = ModelRegistry()

    def check_production_data_availability(self, db) -> dict:
        """Check if we have sufficient production data for training.

        Args:
            db: Database session

        Returns:
            dict with data availability statistics
        """
        logger.info("Checking production data availability...")

        # Count interaction events
        interaction_count = db.query(InteractionEvent).filter(
            InteractionEvent.entity_type == "product"
        ).count()

        # Count unique users
        user_count = db.query(InteractionEvent.user_id).distinct().count()

        # Count products with interactions
        product_count = db.query(InteractionEvent.entity_id).distinct().count()

        # Get date range
        from sqlalchemy import func
        date_range = db.query(
            func.min(InteractionEvent.created_at),
            func.max(InteractionEvent.created_at)
        ).first()

        stats = {
            "interaction_count": interaction_count,
            "user_count": user_count,
            "product_count": product_count,
            "date_range": {
                "min": str(date_range[0]) if date_range[0] else None,
                "max": str(date_range[1]) if date_range[1] else None,
            }
        }

        logger.info(f"Production data stats: {stats}")
        return stats

    def train(
        self,
        db,
        version: str = "v2.0",
        num_rounds: int = 120,
        validation_split: float = 0.2,
        test_split: float = 0.2,
        negative_ratio: int = 3,
        evaluate_baseline: bool = True,
    ) -> dict:
        """Train recommendation model on production data.

        Args:
            db: Database session
            version: Model version string
            num_rounds: Number of training rounds
            validation_split: Validation split ratio
            test_split: Test split ratio
            negative_ratio: Negative samples per positive
            evaluate_baseline: Whether to evaluate against baseline

        Returns:
            Training results dict
        """
        logger.info(f"Starting production recommendation model training (version {version})...")

        # Check data availability
        stats = self.check_production_data_availability(db)
        if stats["interaction_count"] < 100:
            logger.warning(
                f"Insufficient production data: {stats['interaction_count']} interactions. "
                "Consider using demo data or collecting more interactions."
            )

        # Build interaction dataset
        logger.info("Building interaction dataset from production data...")
        dataset_builder = InteractionDatasetBuilder()
        samples = dataset_builder.build_samples(db)

        if len(samples) == 0:
            logger.error("No interaction samples found. Cannot train.")
            return {"status": "failed", "reason": "no_samples"}

        logger.info(f"Built {len(samples)} interaction samples")

        # Time-based split
        logger.info("Performing time-based train/validation/test split...")
        train_samples, val_samples, test_samples = dataset_builder.time_split(
            samples, val_frac=validation_split, test_frac=test_split
        )

        logger.info(f"Split: train={len(train_samples)}, val={len(val_samples)}, test={len(test_samples)}")

        # Add negative samples
        logger.info(f"Adding negative samples (ratio={negative_ratio})...")
        train_samples = dataset_builder.add_negative_samples(
            train_samples, db, negative_ratio=negative_ratio
        )

        # Build features
        logger.info("Building features...")
        feature_builder = RecommendationFeatureBuilder(embedding_dim=512, include_embedding=True)

        X_train, y_train = self._build_features_and_labels(train_samples, db, feature_builder)
        X_val, y_val = self._build_features_and_labels(val_samples, db, feature_builder)

        if len(X_train) == 0:
            logger.error("No training features built. Cannot train.")
            return {"status": "failed", "reason": "no_features"}

        logger.info(f"Feature shapes: train={X_train.shape}, val={X_val.shape}")

        # Train model
        logger.info(f"Training {self.model_type} model...")
        if self.model_type == "lightgbm":
            model = lgb.LGBMClassifier(
                n_estimators=num_rounds,
                learning_rate=0.1,
                max_depth=8,
                num_leaves=31,
                random_state=42,
                verbose=-1,
            )
            model.fit(
                X_train, y_train,
                eval_set=[(X_val, y_val)],
                callbacks=[lgb.early_stopping(stopping_rounds=10)],
            )
        else:
            import xgboost as xgb
            model = xgb.XGBClassifier(
                n_estimators=num_rounds,
                learning_rate=0.1,
                max_depth=8,
                random_state=42,
            )
            model.fit(
                X_train, y_train,
                eval_set=[(X_val, y_val)],
                early_stopping_rounds=10,
                verbose=False,
            )

        # Evaluate on validation set
        val_pred = model.predict(X_val)
        val_accuracy = np.mean(val_pred == y_val)
        logger.info(f"Validation accuracy: {val_accuracy:.4f}")

        # Evaluate on test set
        X_test, y_test = self._build_features_and_labels(test_samples, db, feature_builder)
        test_pred = model.predict(X_test)
        test_accuracy = np.mean(test_pred == y_test)
        logger.info(f"Test accuracy: {test_accuracy:.4f}")

        # Evaluate ranking metrics
        test_metrics = self._evaluate_ranking_metrics(test_samples, db, feature_builder, model)
        logger.info(f"Test ranking metrics: {test_metrics}")

        # Evaluate baseline if requested
        baseline_metrics = {}
        if evaluate_baseline:
            logger.info("Evaluating baseline...")
            # Get temporal cutoff for fair baseline evaluation
            if len(test_samples) > 0:
                temporal_cutoff = test_samples[0].timestamp
                user_ids = {s.user_id for s in test_samples}
                user_preferences = compute_historical_user_preferences(db, user_ids, temporal_cutoff)
                baseline_metrics = evaluate_rule_baseline(
                    test_samples, user_preferences, feature_builder, db,
                    temporal_cutoff=temporal_cutoff
                )
                logger.info(f"Baseline metrics: {baseline_metrics}")

        # Save model
        version_dir = self.models_dir / version
        version_dir.mkdir(parents=True, exist_ok=True)

        model_path = version_dir / f"model.{self.model_type}"
        with open(model_path, 'wb') as f:
            pickle.dump(model, f)

        # Save standardized metadata
        metadata = generate_standard_metadata(
            model_name="recommendation",
            version=version,
            model_type=self.model_type,
            artifact_path=model_path,
            dataset_version="production_v1",
            feature_version="v1",
            data_source="production_postgresql",
            status="staging",
            metrics=test_metrics,
            embedding_dim=512,
            feature_dim=X_train.shape[1] if len(X_train) > 0 else 0,
            training_samples=len(X_train),
            validation_samples=len(X_val),
            test_samples=len(X_test),
            hyperparameters={
                "num_rounds": num_rounds,
                "validation_split": validation_split,
                "test_split": test_split,
                "negative_ratio": negative_ratio,
            },
            description=f"Recommendation model trained on real production data. {len(X_train)} training samples.",
        )

        # Add additional metrics
        metadata["validation_accuracy"] = float(val_accuracy)
        metadata["test_accuracy"] = float(test_accuracy)
        metadata["baseline_metrics"] = baseline_metrics

        save_metadata(metadata, version_dir / "metadata.json")
        
        # Create model card
        create_model_card(metadata, version_dir / "MODEL_CARD.md")

        # Register in model registry
        self.registry.register(
            model_name="recommendation",
            version=version,
            artifact_path=str(model_path),
            model_type=self.model_type,
            training_date=metadata["training_date"],
            dataset_version=metadata["dataset_version"],
            feature_version=metadata["feature_version"],
            metrics=metadata["test_metrics"],
            status="staging",  # Start in staging, promote after validation
        )

        logger.info(f"Model saved to {model_path}")
        logger.info(f"Metadata saved to {metadata_path}")
        logger.info(f"Registered in registry as {version} (staging)")

        return {
            "status": "success",
            "version": version,
            "model_path": str(model_path),
            "validation_accuracy": float(val_accuracy),
            "test_accuracy": float(test_accuracy),
            "test_metrics": test_metrics,
            "baseline_metrics": baseline_metrics,
            "metadata": metadata,
        }

    def _build_features_and_labels(self, samples, db, feature_builder):
        """Build feature matrix and labels from samples.

        Args:
            samples: List of InteractionSample objects
            db: Database session
            feature_builder: Feature builder instance

        Returns:
            Tuple of (X, y) numpy arrays
        """
        X = []
        y = []

        for sample in samples:
            try:
                features = feature_builder.build_features(
                    db, sample.user_id, sample.product_id
                )
                if features is not None:
                    X.append(features)
                    y.append(sample.label)
            except Exception as e:
                logger.warning(f"Failed to build features for sample {sample.user_id}-{sample.product_id}: {e}")
                continue

        return np.array(X), np.array(y)

    def _evaluate_ranking_metrics(self, samples, db, feature_builder, model):
        """Evaluate ranking metrics on test samples.

        Args:
            samples: Test samples
            db: Database session
            feature_builder: Feature builder
            model: Trained model

        Returns:
            Dict of ranking metrics
        """
        from collections import defaultdict

        user_items = defaultdict(list)

        for sample in samples:
            try:
                features = feature_builder.build_features(db, sample.user_id, sample.product_id)
                if features is not None:
                    score = model.predict_proba([features])[0][1] if hasattr(model, 'predict_proba') else float(model.predict([features])[0])
                    user_items[sample.user_id].append({
                        "product_id": sample.product_id,
                        "label": sample.label,
                        "score": float(score),
                    })
            except Exception as e:
                logger.warning(f"Failed to score sample {sample.user_id}-{sample.product_id}: {e}")
                continue

        per_user = [ranking_metrics_for_user(items, tops=(5, 10)) for items in user_items.values()]
        return aggregate_over_users(per_user)


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Train recommendation model on production data")
    parser.add_argument("--version", default="v2.0", help="Model version")
    parser.add_argument("--rounds", type=int, default=120, help="Number of training rounds")
    parser.add_argument("--model", default="lightgbm", choices=["lightgbm", "xgboost"])
    parser.add_argument("--evaluate-baseline", action="store_true", help="Evaluate against baseline")
    args = parser.parse_args()

    db = SessionLocal()

    try:
        trainer = ProductionRecommendationTrainer(model_type=args.model)
        result = trainer.train(
            db,
            version=args.version,
            num_rounds=args.rounds,
            evaluate_baseline=args.evaluate_baseline,
        )

        if result["status"] == "success":
            print(f"\n✅ Training successful!")
            print(f"Version: {result['version']}")
            print(f"Model path: {result['model_path']}")
            print(f"Test accuracy: {result['test_accuracy']:.4f}")
            print(f"Test metrics: {result['test_metrics']}")
            if result['baseline_metrics']:
                print(f"Baseline metrics: {result['baseline_metrics']}")
            print(f"\nModel registered in staging. Promote to production after validation.")
        else:
            print(f"\n❌ Training failed: {result.get('reason', 'unknown')}")
            sys.exit(1)

    finally:
        db.close()


if __name__ == "__main__":
    main()