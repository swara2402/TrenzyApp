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

from sqlalchemy import func

from ..db import SessionLocal
from ..models import Product
from ..catalog_categories import canonical_category

CATALOG_PATH = Path(__file__).resolve().parents[2] / "data" / "products.json"
UNKNOWN = {"", "unknown", "uncategorized", "none", "null"}


def is_unclassified(product: dict[str, Any]) -> bool:
    """A product must have a meaningful category and subcategory to be listed."""
    category = str(product.get("category") or "").strip().lower()
    subcategory = str(product.get("subcategory") or "").strip().lower()
    gender = str(product.get("gender") or "").strip().lower()
    return category in UNKNOWN or subcategory in UNKNOWN or gender in UNKNOWN or not canonical_category(subcategory)


def grounded_tags(product: dict[str, Any]) -> list[str]:
    """Create tags only from metadata already present on the record."""
    values = (
        product.get("subcategory"),
        product.get("category"),
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
            product["tags"] = grounded_tags(product)
        CATALOG_PATH.write_text(json.dumps(products, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"JSON catalog updated; backup: {backup}")

    if args.apply_db:
        db = SessionLocal()
        try:
            unknown_expr = func.lower(func.trim(func.coalesce(Product.category, ""))).in_(UNKNOWN)
            unknown_subcategory = func.lower(func.trim(func.coalesce(Product.subcategory, ""))).in_(UNKNOWN)
            unknown_gender = func.lower(func.trim(func.coalesce(Product.gender, ""))).in_(UNKNOWN)
            query = db.query(Product).filter(unknown_expr | unknown_subcategory | unknown_gender)
            rows = query.all()
            for product in rows:
                product.is_archived = True
            db.commit()
            print(f"Archived {len(rows)} unclassified database products (no rows deleted).")
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
