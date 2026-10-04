#!/usr/bin/env python3
"""Phase 29: Train the full recommendation model (ML production pipeline).

Usage:
    python -m ml.train_all --model lightgbm --version v2 --rounds 120
    python -m ml.train_all --model xgboost --version v1 --rounds 100
"""

from __future__ import annotations

import argparse

from ml.engine.runner import bootstrap_demo_db, setup_logging
from ml.recommendation.train import RecommendationTrainer
from ml.config import get_data_source_info, validate_data_source_for_training


def main():
    parser = argparse.ArgumentParser(description="Train Trenzy recommendation model")
    parser.add_argument("--model", default="lightgbm", choices=["lightgbm", "xgboost"])
    parser.add_argument("--version", default="v1")
    parser.add_argument("--rounds", type=int, default=120)
    parser.add_argument("--products", type=int, default=2000)
    parser.add_argument("--users", type=int, default=30)
    parser.add_argument("--events", type=int, default=30)
    parser.add_argument("--negative-ratio", type=int, default=3)
    parser.add_argument("--use-production-db", action="store_true", help="Use real PostgreSQL instead of demo SQLite")
    args = parser.parse_args()

    setup_logging()

    # Log data source configuration
    data_source_info = get_data_source_info()
    print(f"Data source configuration: {data_source_info}")
    
    # Validate data source and warn if not using production data
    warnings = validate_data_source_for_training()
    if warnings:
        print("⚠️  DATA SOURCE WARNINGS:")
        for warning in warnings:
            print(f"  - {warning}")
        print("To use production PostgreSQL: export ML_USE_POSTGRES=1")
    
    # If explicitly using production DB, skip demo bootstrap
    if args.use_production_db or data_source_info["ml_use_postgres"]:
        import sys
        from pathlib import Path
        backend_dir = Path(__file__).parent.parent / "backend"
        sys.path.insert(0, str(backend_dir))
        from app.db import SessionLocal, engine
        db = SessionLocal()
        stats = {"products": "production", "users": "production", "mode": "production"}
        print(f"Using production PostgreSQL database")
    else:
        db, engine, stats = bootstrap_demo_db(
            max_products=args.products, users=args.users, events_per_user=args.events,
        )
        print(f"Demo DB ready: {stats}")

    trainer = RecommendationTrainer(
        model_type=args.model,
        negative_ratio=args.negative_ratio,
    )
    result = trainer.train(db, version=args.version, num_rounds=args.rounds)
    if not result:
        raise SystemExit("Training failed — no samples.")
    print(f"\nTraining complete. Version {result['version']} → {result['artifact_path']}")


if __name__ == "__main__":
    main()