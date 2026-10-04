#!/usr/bin/env python3
"""Phase 29: Promote a trained model version to production in the registry.

Usage:
    python -m ml.promote_model --model recommendation --version v1
"""

from __future__ import annotations

import argparse
import json

from ml.engine.runner import setup_logging
from ml.config import models_dir_for, USE_SQLITE


def main():
    parser = argparse.ArgumentParser(description="Promote a model version to production")
    parser.add_argument("--model", default="recommendation")
    parser.add_argument("--version", default="v1")
    parser.add_argument("--force", action="store_true",
                        help="Promote even if the candidate underperforms the current production model.")
    args = parser.parse_args()

    setup_logging()

    version_dir = models_dir_for(args.model) / args.version
    if not (version_dir / "metadata.json").exists():
        print(f"✗ No version {args.version} of '{args.model}' — train first.")
        raise SystemExit(1)

    metadata = json.loads((version_dir / "metadata.json").read_text())
    metrics = metadata.get("metrics", {})
    print(f"Candidate: {args.model}/{args.version} → {metadata['artifact_path']}")
    print(f"  ndcg@10={metrics.get('ndcg@10')}, auc={metrics.get('auc')}")

    if USE_SQLITE:
        # SQLite demo mode: registry disk metadata already written; promote the
        # disk artifact by setting status="production" in metadata.json and
        # writing the registry index file.
        metadata["status"] = "production"
        (version_dir / "metadata.json").write_text(
            json.dumps(metadata, indent=2, default=str)
        )
        reg = models_dir_for(args.model).parent / "registry.json"
        registry = json.loads(reg.read_text()) if reg.exists() else {}
        entry = registry.setdefault(args.model, {})
        entry[args.version] = {"status": "production", "metrics": metrics}
        reg.write_text(json.dumps(registry, indent=2, default=str))
        print(f"✓ Promoted {args.model}/{args.version} → production (SQLite disk registry)")
        return

    from app.ai.registry import ModelRegistry
    promoted = ModelRegistry.promote_if_better(
        model_name=args.model,
        version=args.version,
        metric_name="ndcg@10",
        new_model_metric=metrics.get("ndcg@10"),
        force=args.force,
    )
    print(f"{'✓' if promoted else '✗'} Promote result: {promoted}")


if __name__ == "__main__":
    main()