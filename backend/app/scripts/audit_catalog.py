"""Validate catalog identity, legal metadata, and image uniqueness.

Usage:
    python -m app.scripts.audit_catalog
"""

from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path


CATALOG_PATH = Path(__file__).resolve().parents[2] / "data" / "products.json"


def audit_catalog(path: Path = CATALOG_PATH) -> dict[str, int]:
    """Return catalog quality counts and fail on missing required fields."""
    products = json.loads(path.read_text(encoding="utf-8"))
    ids = [product.get("id") for product in products]
    image_urls = [product.get("image_url") for product in products]
    duplicate_ids = sum(count > 1 for count in Counter(ids).values())
    stats = {
        "records": len(products),
        "unique_ids": len(set(ids)),
        "unique_image_urls": len(set(image_urls)),
        "missing_ids": sum(not product.get("id") for product in products),
        "missing_image_urls": sum(not product.get("image_url") for product in products),
        "missing_legal_metadata": sum(
            not product.get("source") or not product.get("source_license")
            for product in products
        ),
        "duplicate_id_values": duplicate_ids,
    }

    failure_keys = {"missing_ids", "missing_image_urls", "missing_legal_metadata", "duplicate_id_values"}
    failures = {
        key: value
        for key, value in stats.items()
        if key in failure_keys and value > 0
    }
    if stats["unique_image_urls"] != stats["records"]:
        failures["reused_image_urls"] = stats["records"] - stats["unique_image_urls"]
    if stats["unique_ids"] != stats["records"]:
        failures["duplicate_ids"] = stats["records"] - stats["unique_ids"]

    print(json.dumps(stats, indent=2))
    if failures:
        print("Catalog audit failed:", json.dumps(failures), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(audit_catalog())
