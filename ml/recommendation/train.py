"""Recommendation model training (Phase 5.2 / 5.5).

Trains a LightGBM (or XGBoost) classifier predicting
``P(user positively interacts with product)`` using:

- Time-based train/validation/test split (no temporal leakage).
- Feature builder from ``features.py``.
- Saves versioned artifacts + metadata + evaluation metrics.
- Registers the version in the Model Registry.

Artifacts layout:
    models/recommendation/<version>/model.<lightgbm|xgboost>
    models/recommendation/<version>/metadata.json
    models/recommendation/<version>/features.json
    models/recommendation/<version>/metrics.json
"""

from __future__ import annotations

import json
import logging
import pickle
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional, Tuple

import lightgbm as lgb
import numpy as np
from sqlalchemy.orm import Session

from ..config import models_dir_for, DEFAULT_DATASET_VERSION, DEFAULT_FEATURE_VERSION
from ..data.build_interaction_dataset import InteractionDatasetBuilder
from .features import RecommendationFeatureBuilder, FEATURE_SCHEMA_VERSION

logger = logging.getLogger(__name__)


def _utcnow_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class RecommendationTrainer:
    """Trains Trenzy's proprietary recommendation model."""

    def __init__(
        self,
        model_type: str = "lightgbm",
        embedding_dim: int = 512,
        feature_version: str = FEATURE_SCHEMA_VERSION,
        dataset_version: str = DEFAULT_DATASET_VERSION,
        negative_ratio: int = 3,
    ):
        self.model_type = model_type
        self.embedding_dim = embedding_dim
        self.feature_version = feature_version
        self.dataset_version = dataset_version
        self.negative_ratio = negative_ratio
        self.feature_builder = RecommendationFeatureBuilder(
            embedding_dim=embedding_dim, include_embedding=True
        )

    def build_xy(
        self,
        db: Session,
        samples,
    ) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
        """Build feature matrix + labels + sample weights from dataset samples."""
        from app.models import Product

        X = []
        y = []
        w = []
        for s in samples:
            product = db.get(Product, s.product_id)
            if product is None:
                continue
            vec = self.feature_builder.build(db, s.user_id, product, before_ts=s.timestamp)
            X.append(vec)
            y.append(s.label)
            w.append(s.weight)

        if not X:
            return (
                np.zeros((0, self.feature_dim), dtype=np.float32),
                np.zeros(0),
                np.zeros(0),
            )
        return np.vstack(X), np.asarray(y), np.asarray(w)

    @property
    def feature_dim(self) -> int:
        return self.feature_builder.feature_dim()

    def train(
        self,
        db: Session,
        version: str = "v1",
        num_rounds: int = 120,
        val_frac: float = 0.2,
        test_frac: float = 0.2,
        model_dir: Optional[Path] = None,
    ) -> dict:
        """Train the model on the interaction dataset.

        Returns:
            Summary dict with metrics + artifact paths.
        """
        logger.info("Building interaction dataset...")
        self.feature_builder.reset_profile_cache()
        builder = InteractionDatasetBuilder()
        samples = builder.build_samples(db)
        samples = builder.add_negative_samples(samples, db, negative_ratio=self.negative_ratio)
        train, val, test = builder.time_split(samples, val_frac, test_frac)

        if not train:
            logger.error("No training samples — aborting.")
            return {}

        X_train, y_train, w_train = self.build_xy(db, train)
        X_val, y_val, w_val = self.build_xy(db, val)
        X_test, y_test, w_test = self.build_xy(db, test)

        if len(X_train) == 0:
            logger.error("Empty training matrix — aborting.")
            return {}

        logger.info(
            "Training %s: train=%d val=%d test=%d (features=%d)",
            self.model_type, len(X_train), len(X_val), len(X_test), self.feature_dim,
        )

        # Train
        if self.model_type == "lightgbm":
            model = lgb.LGBMClassifier(
                n_estimators=num_rounds,
                learning_rate=0.05,
                max_depth=7,
                num_leaves=31,
                min_child_samples=10,
                subsample=0.9,
                colsample_bytree=0.8,
                random_state=42,
                verbose=-1,
            )
            model.fit(
                X_train, y_train,
                sample_weight=w_train,
                eval_X=X_val,
                eval_y=y_val,
                eval_metric=["auc", "binary_logloss"],
                callbacks=[lgb.early_stopping(stopping_rounds=20)],
            )
        elif self.model_type == "xgboost":
            import xgboost as xgb
            model = xgb.XGBClassifier(
                n_estimators=num_rounds,
                learning_rate=0.05,
                max_depth=7,
                subsample=0.9,
                colsample_bytree=0.8,
                random_state=42,
                eval_metric="auc",
                early_stopping_rounds=20,
            )
            model.fit(X_train, y_train, sample_weight=w_train, eval_set=[(X_val, y_val)], verbose=False)
        else:
            raise ValueError(f"Unsupported model_type: {self.model_type}")

        # Evaluate on test set (held-out, temporally separate)
        metrics = evaluate_model(model, self.feature_builder, db, test, X_test, y_test)

        # Save artifacts
        version_dir = (model_dir or models_dir_for("recommendation")) / version
        version_dir.mkdir(parents=True, exist_ok=True)

        artifact_path = version_dir / f"model.{self.model_type}"
        with open(artifact_path, "wb") as f:
            pickle.dump(model, f)

        # Validation AUC for early stopping info
        val_proba = model.predict_proba(X_val)[:, 1]
        from sklearn.metrics import roc_auc_score
        val_auc = float(roc_auc_score(y_val, val_proba))

        metadata = {
            "model_name": "recommendation",
            "version": version,
            "model_type": self.model_type,
            "training_date": _utcnow_iso(),
            "num_rounds": num_rounds,
            "negative_ratio": self.negative_ratio,
            "feature_version": self.feature_version,
            "dataset_version": self.dataset_version,
            "feature_dim": self.feature_dim,
            "embedding_dim": self.embedding_dim,
            "val_auc": val_auc,
            "metrics": metrics,
            "status": "development",
        }

        # Write features.json schema
        (version_dir / "features.json").write_text(json.dumps({
            "schema_version": self.feature_version,
            "dim": self.feature_dim,
            "names": self.feature_builder.feature_names(),
        }, indent=2))

        # Write metrics.json
        (version_dir / "metrics.json").write_text(json.dumps(metrics, indent=2))

        # Write metadata.json + register in registry
        metadata["artifact_path"] = str(artifact_path)
        (version_dir / "metadata.json").write_text(json.dumps(metadata, indent=2, default=str))

        from app.ai.registry import ModelRegistry
        from ..config import USE_SQLITE
        if not USE_SQLITE:
            ModelRegistry.register(
                model_name="recommendation",
                version=version,
                artifact_path=str(artifact_path),
                model_type=self.model_type,
                training_date=metadata["training_date"],
                dataset_version=self.dataset_version,
                feature_version=self.feature_version,
                metrics=metrics,
                status="development",
            )
        else:
            # SQLite demo mode: still persist disk metadata (already done above).
            logger.info("SQLite demo mode — registry persisted to disk only")

        logger.info("Trained & saved recommendation %s → %s", version, artifact_path)
        logger.info("Test metrics: %s", {k: round(v, 4) if isinstance(v, float) else v for k, v in metrics.items()})
        return metadata


def evaluate_model(model, feature_builder, db, test_samples, X_test, y_test) -> dict:
    """Compute classification + ranking metrics on held-out test samples."""
    from sklearn.metrics import (
        roc_auc_score, precision_score, recall_score, f1_score, log_loss,
    )

    proba = model.predict_proba(X_test)[:, 1]
    y_pred = (proba >= 0.5).astype(int)

    metrics = {
        "auc": float(roc_auc_score(y_test, proba)),
        "precision": float(precision_score(y_test, y_pred, zero_division=0)),
        "recall": float(recall_score(y_test, y_pred, zero_division=0)),
        "f1": float(f1_score(y_test, y_pred, zero_division=0)),
        "test_samples": int(len(y_test)),
        "positive_rate": float(y_test.mean()),
        "average_score": float(proba.mean()),
    }
    try:
        metrics["log_loss"] = float(log_loss(y_test, proba))
    except Exception:
        metrics["log_loss"] = None

    # Ranking metrics: group by user, rank candidates by predicted proba.
    # Compute Precision@5, Precision@10, Recall@10, NDCG@10, HitRate@10.
    from collections import defaultdict
    user_products: dict[int, list] = defaultdict(list)
    for idx, s in enumerate(test_samples):
        user_products[s.user_id].append({
            "product_id": s.product_id,
            "label": int(y_test[idx]),
            "score": float(proba[idx]),
        })

    from ..evaluation.recommendation import ranking_metrics_for_user
    all_pk5, all_rk10, all_ndcg10, all_hit10, all_cov = ([] for _ in range(5))
    for uid, items in user_products.items():
        data = ranking_metrics_for_user(items, tops=[5, 10])
        all_pk5.append(data["precision@5"])
        all_rk10.append(data["recall@10"])
        all_ndcg10.append(data["ndcg@10"])
        all_hit10.append(data["hit_rate@10"])
        all_cov.append(data["coverage"])

    metrics.update({
        "precision@5": float(np.mean(all_pk5)) if all_pk5 else 0.0,
        "recall@10": float(np.mean(all_rk10)) if all_rk10 else 0.0,
        "ndcg@10": float(np.mean(all_ndcg10)) if all_ndcg10 else 0.0,
        "hit_rate@10": float(np.mean(all_hit10)) if all_hit10 else 0.0,
        "coverage": float(np.mean(all_cov)) if all_cov else 0.0,
        "num_users_evaluated": len(user_products),
    })

    return metrics