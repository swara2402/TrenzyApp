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


def _has_valid_price(product: dict) -> bool:
    try:
        return float(product.get("price") or 0) > 0
    except (TypeError, ValueError):
        return False


def audit_catalog(path: Path = CATALOG_PATH) -> dict[str, int]:
    """Return catalog quality counts and fail on missing required fields."""
    products = json.loads(path.read_text(encoding="utf-8"))
    ids = [product.get("id") for product in products]
    image_urls = [product.get("image_url") for product in products]
    duplicate_ids = sum(count > 1 for count in Counter(ids).values())
    active_products = [product for product in products if not product.get("is_archived", False)]
    unknown = {"", "unknown", "uncategorized", "none", "null"}
    unclassified = [
        product for product in active_products
        if str(product.get("category") or "").strip().lower() in unknown
        or str(product.get("subcategory") or "").strip().lower() in unknown
        or str(product.get("gender") or "").strip().lower() in unknown
        or not canonical_category(product.get("subcategory"))
    ]
    classified = [product for product in active_products if product not in unclassified]
    stats = {
        "records": len(products),
        "active_records": len(active_products),
        "unique_ids": len(set(ids)),
        "unique_image_urls": len(set(image_urls)),
        "missing_ids": sum(not product.get("id") for product in products),
        "missing_image_urls": sum(not product.get("image_url") for product in products),
        "missing_legal_metadata": sum(
            not product.get("source") or not product.get("source_license")
            for product in products
        ),
        "duplicate_id_values": duplicate_ids,
        "active_unclassified_products": len(unclassified),
        "active_missing_tags": sum(not isinstance(product.get("tags"), list) or not product.get("tags") for product in classified),
        "active_placeholder_names": sum(
            str(product.get("name") or "").strip().lower().startswith("product ")
            for product in active_products
        ),
        # Prices are reported separately because beta commerce is disabled; never invent them.
        "active_missing_prices": sum(not _has_valid_price(product) for product in active_products),
    }

    failure_keys = {
        "missing_ids", "missing_image_urls", "missing_legal_metadata",
        "duplicate_id_values", "active_unclassified_products",
        "active_missing_tags", "active_placeholder_names",
    }
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
