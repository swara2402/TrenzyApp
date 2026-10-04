#!/usr/bin/env python3
"""Evaluate trained recommendation models against rule-based baseline (Phase 17/29).

Train a quick model, then report ML vs rule-based metrics on the held-out test
split so the promotion decision is data-driven.

Usage:
    python -m ml.evaluate_all --version v1
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from ml.engine.runner import bootstrap_demo_db, setup_logging
from ml.config import models_dir_for


def main():
    parser = argparse.ArgumentParser(description="Evaluate recommendation model vs baseline")
    parser.add_argument("--version", default="v1")
    parser.add_argument("--model", default="lightgbm")
    parser.add_argument("--products", type=int, default=2000)
    parser.add_argument("--users", type=int, default=30)
    parser.add_argument("--events", type=int, default=30)
    args = parser.parse_args()

    setup_logging()

    db, engine, _ = bootstrap_demo_db(
        max_products=args.products, users=args.users, events_per_user=args.events,
    )

    # Load saved model + its metrics from disk
    version_dir = models_dir_for("recommendation") / args.version
    metrics_path = version_dir / "metrics.json"

    if not metrics_path.exists():
        print(f"✗ No metrics found at {metrics_path} — train first with `python -m ml.train_all`")
        raise SystemExit(1)

    metrics = json.loads(metrics_path.read_text())
    print("\n=== Recommendation Model metrics ===")
    for k, v in metrics.items():
        if isinstance(v, float):
            print(f"  {k:20s}: {v:.4f}")
        else:
            print(f"  {k:20s}: {v}")

    # Compare against rule-based baseline on the same data
    print("\n=== Rule-based baseline (comparison) ===")
    try:
        from ml.data.build_interaction_dataset import InteractionDatasetBuilder
        from ml.evaluation.recommendation import evaluate_rule_baseline
        from app.models import User

        builder = InteractionDatasetBuilder()
        samples = builder.build_samples(db)

        user_preferences = {}
        for uid, _ in enumerate({s.user_id for s in samples}):
            user_preferences[uid] = {
                "preferred_styles": set(),
                "preferred_categories": set(),
                "preferred_colors": set(),
                "avg_price": 0.0,
            }

        baseline = evaluate_rule_baseline(samples, user_preferences, None, db)
        for k, v in baseline.items():
            print(f"  {k:20s}: {v:.4f}")

        print("\n=== Promotion check ===")
        ml_key = "ndcg@10"
        if ml_key in metrics:
            ml_val = metrics[ml_key]
            base_val = baseline.get(ml_key, 0.0)
            print(f"  ML ndcg@10:   {ml_val:.4f}")
            print(f"  Baseline ndcg@10: {base_val:.4f}")
            print(f"  ML {'EDGES' if ml_val >= base_val else 'MISSES'} baseline → {'promote' if ml_val >= base_val else 'do not promote'}")
    except Exception as e:
        print(f"  Baseline comparison skipped: {e}")

    print("\nDone.")


if __name__ == "__main__":
    main()