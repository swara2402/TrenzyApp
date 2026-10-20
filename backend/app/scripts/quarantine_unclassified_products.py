"""Safely quarantine unclassified legacy products.

Run from backend/:
  python -m app.scripts.quarantine_unclassified_products
  python -m app.scripts.quarantine_unclassified_products --apply-json
  python -m app.scripts.quarantine_unclassified_products --apply-db

Default mode is a read-only report. Unknown/placeholder catalog entries are
archived, never deleted. The JSON operation creates a timestamped backup.
"""
from __future__ import annotations

import argparse
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from ..db import SessionLocal
from ..models import Product
from ..catalog_categories import canonical_category

CATALOG_PATH = Path(__file__).resolve().parents[2] / "data" / "products.json"
UNKNOWN = {"", "unknown", "uncategorized", "none", "null"}


def is_unclassified(product: dict[str, Any]) -> bool:
    """A product must have a meaningful category and subcategory to be listed."""
    return not canonical_category(product.get("subcategory"))


def grounded_tags(product: dict[str, Any]) -> list[str]:
    """Create tags only from metadata already present on the record."""
    values = (
        product.get("subcategory"),
        canonical_category(product.get("subcategory")) or product.get("category"),
        product.get("style"),
        product.get("color"),
        product.get("gender"),
    )
    tags: list[str] = []
    seen: set[str] = set()
    for value in values:
        label = str(value or "").strip()
        if not label or label.lower() in UNKNOWN or label.casefold() in seen:
            continue
        tags.append(label)
        seen.add(label.casefold())
    return tags


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply-json", action="store_true", help="Archive unclassified JSON records and add grounded tags; creates a backup")
    parser.add_argument("--apply-db", action="store_true", help="Archive unclassified rows in the configured database")
    args = parser.parse_args()

    products = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    unclassified = [p for p in products if is_unclassified(p)]
    classified = [p for p in products if not is_unclassified(p)]
    print(f"Catalog records: {len(products)}")
    print(f"Unclassified records to quarantine: {len(unclassified)}")
    print(f"Classified records eligible for grounded tags: {len(classified)}")

    if args.apply_json:
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        backup = CATALOG_PATH.with_name(CATALOG_PATH.name + f".pre_quarantine_{stamp}.bak")
        shutil.copy2(CATALOG_PATH, backup)
        for product in unclassified:
            product["is_archived"] = True
        for product in classified:
            product["category"] = canonical_category(product.get("subcategory"))
            product["tags"] = grounded_tags(product)
        CATALOG_PATH.write_text(json.dumps(products, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"JSON catalog updated; backup: {backup}")

    if args.apply_db:
        db = SessionLocal()
        try:
            rows = db.query(Product).all()
            archived_count = 0
            normalized_count = 0
            for product in rows:
                category = canonical_category(product.subcategory)
                if not category:
                    if not product.is_archived:
                        product.is_archived = True
                        archived_count += 1
                    continue

                if product.category != category:
                    product.category = category
                    normalized_count += 1
                product.tags = grounded_tags({
                    "category": category,
                    "subcategory": product.subcategory,
                    "style": product.style,
                    "color": product.color,
                    "gender": product.gender,
                })
            db.commit()
            print(f"Archived {archived_count} unclassified database products (no rows deleted).")
            print(f"Normalized categories/tags on {normalized_count} classified database products.")
        except Exception:
            db.rollback()
            raise
        finally:
            db.close()

    if not args.apply_json and not args.apply_db:
        print("Dry run only. Re-run with --apply-json and/or --apply-db to apply the reversible quarantine.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
