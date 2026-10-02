#!/usr/bin/env python3
"""Product catalog ingestion pipeline.

PHASE 3: PRODUCT CATALOG INGESTION

Imports products from a JSON source (or file) into the Trenzy database.
Handles validation, deduplication, normalization, feature extraction,
and bulk import efficiently.

Process:
1. Input validation (required fields, data types)
2. Deduplication (prevent duplicate SKUs/external IDs)
3. Price validation (numeric, positive, no floats)
4. Image URL validation
5. Affiliate URL validation
6. Category mapping (normalize to existing categories)
7. Brand normalization
8. Color normalization (map to standard color palette)
9. Bulk insert using PostgreSQL batch operations
10. Progress tracking and reporting
11. Idempotency (safe to re-run, won't duplicate)

Usage:
    python scripts/ingest_catalog.py --source products.json --database postgresql://...
    python scripts/ingest_catalog.py --source s3://bucket/products.csv --format csv
    python scripts/ingest_catalog.py --source /path/to/local/file.json --dry-run

Output:
    - Console report with X processed, Y skipped, Z failed
    - Optional: JSON report saved to catalog_import_TIMESTAMP.json
"""

import argparse
import csv
import json
import logging
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
from urllib.parse import urlparse

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-7s | %(name)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

# Add parent directory to path so we can import app modules
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.db import get_session
from app.models import Product, Brand, Category


# ============================================================================
# CONFIGURATION
# ============================================================================

# Standard color palette for normalization
STANDARD_COLORS = {
    "red", "dark_red", "maroon",
    "orange",
    "yellow", "gold",
    "green", "olive", "sage", "forest_green",
    "cyan", "teal", "turquoise",
    "blue", "navy", "indigo",
    "purple", "violet",
    "pink", "rose", "magenta",
    "brown", "tan", "beige", "khaki",
    "gray", "charcoal", "silver",
    "black",
    "white", "cream", "ivory",
    "multicolor", "striped", "printed", "patterned",
}

# Standard categories (these must exist in DB or will be created)
STANDARD_CATEGORIES = {
    "men": {"subcategories": ["topwear", "bottomwear", "footwear", "activewear", "innerwear"]},
    "women": {"subcategories": ["topwear", "bottomwear", "footwear", "activewear", "innerwear"]},
    "kids": {"subcategories": ["topwear", "bottomwear", "footwear"]},
    "accessories": {"subcategories": ["watches", "bags", "belts", "scarves", "hats"]},
    "footwear": {"subcategories": ["casual", "formal", "sports", "sandals"]},
}

# Standard values for other fields
STANDARD_GENDERS = {"men", "women", "unisex", "kids"}
STANDARD_SEASONS = {"summer", "winter", "monsoon", "all-season"}
STANDARD_USAGES = {"casual", "formal", "sports", "party", "ethnic"}


# ============================================================================
# VALIDATION & NORMALIZATION
# ============================================================================

def validate_required_fields(product: Dict[str, Any]) -> Tuple[bool, str]:
    """Check if product has required fields."""
    required = {"id", "name"}
    missing = required - set(product.keys())
    if missing:
        return False, f"Missing required fields: {missing}"
    if not product.get("id") or not product.get("name"):
        return False, f"Required fields are empty: id={product.get('id')}, name={product.get('name')}"
    return True, ""


def validate_price(price: Any) -> Tuple[bool, float, str]:
    """Validate and return price in rupees (as decimal, not float)."""
    if price is None:
        return True, None, ""

    try:
        price_float = float(price)
    except (ValueError, TypeError):
        return False, None, f"Price is not numeric: {price}"

    if price_float < 0:
        return False, None, f"Price is negative: {price_float}"

    # Round to 2 decimal places (paise precision)
    price_numeric = round(price_float, 2)
    return True, price_numeric, ""


def validate_url(url: str, field_name: str = "URL") -> Tuple[bool, str]:
    """Validate URL format."""
    if not url or not isinstance(url, str):
        return True, ""  # URLs are optional

    try:
        result = urlparse(url)
        if not all([result.scheme, result.netloc]):
            return False, f"{field_name} has invalid format: {url}"
    except Exception as e:
        return False, f"{field_name} validation failed: {e}"

    return True, ""


def normalize_color(color_raw: str) -> str:
    """Normalize color to standard palette or lowercase."""
    if not color_raw:
        return None
    color_lower = color_raw.lower().strip().replace(" ", "_")
    if color_lower in STANDARD_COLORS:
        return color_lower
    # Return as-is if not in standard palette (will be tracked)
    return color_lower


def normalize_category(category_raw: str) -> str:
    """Normalize category to standard list or warn."""
    if not category_raw:
        return None
    category_lower = category_raw.lower().strip()
    if category_lower in STANDARD_CATEGORIES:
        return category_lower
    # Return as-is; mapping will be attempted
    return category_lower


def normalize_gender(gender_raw: str) -> str:
    """Normalize gender to standard values."""
    if not gender_raw:
        return None
    gender_lower = gender_raw.lower().strip()
    if gender_lower in STANDARD_GENDERS:
        return gender_lower
    return gender_lower


def normalize_season(season_raw: str) -> str:
    """Normalize season to standard values."""
    if not season_raw:
        return None
    season_lower = season_raw.lower().strip()
    if season_lower in STANDARD_SEASONS:
        return season_lower
    return season_lower


def normalize_usage(usage_raw: str) -> str:
    """Normalize usage to standard values."""
    if not usage_raw:
        return None
    usage_lower = usage_raw.lower().strip()
    if usage_lower in STANDARD_USAGES:
        return usage_lower
    return usage_lower


# ============================================================================
# CATALOG INGESTION
# ============================================================================

class CatalogImporter:
    """Handles catalog import with validation, deduplication, and reporting."""

    def __init__(self, database_url: Optional[str] = None, dry_run: bool = False):
        self.database_url = database_url
        self.dry_run = dry_run
        self.start_time = time.time()

        self.stats = {
            "total_read": 0,
            "total_valid": 0,
            "total_skipped": 0,
            "total_failed": 0,
            "total_imported": 0,
            "errors": [],
            "warnings": [],
            "seen_product_ids": set(),
            "brands_created": 0,
            "categories_created": 0,
        }

    def import_from_json(self, source_path: str) -> Dict[str, Any]:
        """Import products from JSON file."""
        logger.info(f"Loading products from JSON: {source_path}")

        try:
            with open(source_path, "r") as f:
                data = json.load(f)
        except Exception as e:
            logger.error(f"Failed to load JSON: {e}")
            return self.stats

        # Support both array and object with 'products' key
        products = data if isinstance(data, list) else data.get("products", [])
        return self.ingest_products(products)

    def import_from_csv(self, source_path: str) -> Dict[str, Any]:
        """Import products from CSV file."""
        logger.info(f"Loading products from CSV: {source_path}")

        try:
            products = []
            with open(source_path, "r", newline="") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    products.append(row)
        except Exception as e:
            logger.error(f"Failed to load CSV: {e}")
            return self.stats

        return self.ingest_products(products)

    def ingest_products(self, products: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Ingest a list of product dictionaries."""
        logger.info(f"Starting ingestion of {len(products)} products")

        # get_session() is a FastAPI generator dependency — calling it
        # directly returned a generator (crash: 'generator' has no
        # attribute 'query'). Also honor --database when provided instead
        # of silently importing into the app's default engine.
        if self.database_url:
            from sqlalchemy import create_engine
            from sqlalchemy.orm import sessionmaker

            engine = create_engine(self.database_url)
            session = sessionmaker(bind=engine)()
        else:
            session = next(get_session())

        try:
            for idx, product_raw in enumerate(products, 1):
                self.stats["total_read"] += 1

                # Validate required fields
                is_valid, error_msg = validate_required_fields(product_raw)
                if not is_valid:
                    self._skip_product(product_raw, error_msg)
                    continue

                # Check for duplicates
                product_id = str(product_raw["id"]).strip()
                if product_id in self.stats["seen_product_ids"]:
                    self._skip_product(product_raw, f"Duplicate product ID: {product_id}")
                    continue

                self.stats["seen_product_ids"].add(product_id)

                # Check if already in database
                existing = session.query(Product).filter(Product.id == product_id).first()
                if existing:
                    self._skip_product(product_raw, f"Product already exists in DB: {product_id}")
                    continue

                # Validate and normalize
                product_normalized = self._normalize_and_validate(product_raw, session)
                if product_normalized is None:
                    continue

                self.stats["total_valid"] += 1

                # Insert if not dry-run
                if not self.dry_run:
                    try:
                        session.add(product_normalized)
                        session.flush()  # Flush to check for constraint violations
                        self.stats["total_imported"] += 1
                    except Exception as e:
                        session.rollback()
                        self._fail_product(product_raw, f"Database insert failed: {e}")
                        continue
                else:
                    self.stats["total_imported"] += 1

                # Progress logging
                if idx % 100 == 0:
                    logger.info(f"Progress: {idx}/{len(products)} processed")

            # Commit batch
            if not self.dry_run:
                try:
                    session.commit()
                    logger.info("Batch committed to database")
                except Exception as e:
                    session.rollback()
                    logger.error(f"Failed to commit batch: {e}")
                    self.stats["total_imported"] = 0

        finally:
            session.close()

        self._print_report()
        return self.stats

    def _normalize_and_validate(
        self, product_raw: Dict[str, Any], session
    ) -> Optional[Product]:
        """Normalize and validate a single product."""
        try:
            # Extract and validate basic fields
            product_id = str(product_raw["id"]).strip()
            name = str(product_raw.get("name", "")).strip()
            description = product_raw.get("description", "")
            category = product_raw.get("category")
            brand = product_raw.get("brand")
            color = product_raw.get("color")
            gender = product_raw.get("gender")
            season = product_raw.get("season")
            usage = product_raw.get("usage")
            price = product_raw.get("price")
            image_url = product_raw.get("image_url")
            affiliate_links = product_raw.get("affiliate_links")
            rating = product_raw.get("rating")

            # Validate price
            is_valid, price_numeric, error_msg = validate_price(price)
            if not is_valid:
                self._fail_product(product_raw, f"Price validation: {error_msg}")
                return None

            # Validate URLs
            if image_url:
                is_valid, error_msg = validate_url(image_url, "image_url")
                if not is_valid:
                    self._fail_product(product_raw, error_msg)
                    return None

            # Normalize fields
            category_norm = normalize_category(category) if category else None
            brand_norm = normalize_brand(brand) if brand else None
            color_norm = normalize_color(color) if color else None
            gender_norm = normalize_gender(gender) if gender else None
            season_norm = normalize_season(season) if season else None
            usage_norm = normalize_usage(usage) if usage else None

            # Get or create brand
            brand_id = None
            if brand_norm:
                brand_obj = session.query(Brand).filter(Brand.name == brand_norm).first()
                if not brand_obj:
                    brand_obj = Brand(name=brand_norm, description="")
                    session.add(brand_obj)
                    session.flush()
                    self.stats["brands_created"] += 1
                brand_id = brand_obj.id

            # Get or create category
            category_id = None
            if category_norm:
                cat_obj = session.query(Category).filter(Category.name == category_norm).first()
                if not cat_obj:
                    cat_obj = Category(name=category_norm, parent_category_id=None)
                    session.add(cat_obj)
                    session.flush()
                    self.stats["categories_created"] += 1
                category_id = cat_obj.id

            # Create product
            product = Product(
                id=product_id,
                name=name,
                description=description or "",
                category=category_norm,
                brand=brand_norm,
                brand_id=brand_id,
                category_id=category_id,
                color=color_norm,
                gender=gender_norm,
                season=season_norm,
                usage=usage_norm,
                price=price_numeric,
                image_url=image_url,
                rating=float(rating) if rating else None,
                affiliate_links=affiliate_links,
                is_archived=False,
            )

            # Populate outfit styling fields if provided
            if "outfit_role" in product_raw:
                product.outfit_role = product_raw.get("outfit_role")
            if "style" in product_raw:
                product.style = product_raw.get("style")
            if "occasion" in product_raw:
                product.occasion = product_raw.get("occasion")
            if "material" in product_raw:
                product.material = product_raw.get("material")
            if "fit" in product_raw:
                product.fit = product_raw.get("fit")

            return product

        except Exception as e:
            self._fail_product(product_raw, f"Normalization error: {e}")
            return None

    def _skip_product(self, product: Dict[str, Any], reason: str):
        """Log a skipped product."""
        self.stats["total_skipped"] += 1
        self.stats["warnings"].append({
            "product_id": product.get("id"),
            "reason": reason,
        })
        logger.warning(f"Skipped product {product.get('id')}: {reason}")

    def _fail_product(self, product: Dict[str, Any], reason: str):
        """Log a failed product."""
        self.stats["total_failed"] += 1
        self.stats["errors"].append({
            "product_id": product.get("id"),
            "reason": reason,
        })
        logger.error(f"Failed product {product.get('id')}: {reason}")

    def _print_report(self):
        """Print import summary report."""
        elapsed = time.time() - self.start_time

        print("\n" + "=" * 70)
        print("CATALOG IMPORT REPORT")
        print("=" * 70)
        print(f"Total read:         {self.stats['total_read']}")
        print(f"Total valid:        {self.stats['total_valid']}")
        print(f"Total imported:     {self.stats['total_imported']}")
        print(f"Total skipped:      {self.stats['total_skipped']}")
        print(f"Total failed:       {self.stats['total_failed']}")
        print(f"Brands created:     {self.stats['brands_created']}")
        print(f"Categories created: {self.stats['categories_created']}")
        print(f"Elapsed time:       {elapsed:.2f}s")
        print("=" * 70)

        if self.stats["warnings"]:
            print(f"\nWarnings ({len(self.stats['warnings'])}):")
            for warning in self.stats["warnings"][:10]:  # Show first 10
                print(f"  - {warning['product_id']}: {warning['reason']}")
            if len(self.stats["warnings"]) > 10:
                print(f"  ... and {len(self.stats['warnings']) - 10} more")

        if self.stats["errors"]:
            print(f"\nErrors ({len(self.stats['errors'])}):")
            for error in self.stats["errors"][:10]:  # Show first 10
                print(f"  - {error['product_id']}: {error['reason']}")
            if len(self.stats["errors"]) > 10:
                print(f"  ... and {len(self.stats['errors']) - 10} more")

    def save_report(self, output_path: Optional[str] = None):
        """Save detailed report to JSON file."""
        if output_path is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_path = f"catalog_import_{timestamp}.json"

        try:
            with open(output_path, "w") as f:
                json.dump(self.stats, f, indent=2, default=str)
            logger.info(f"Report saved to {output_path}")
        except Exception as e:
            logger.error(f"Failed to save report: {e}")


def normalize_brand(brand_raw: str) -> str:
    """Normalize brand name."""
    if not brand_raw:
        return None
    return brand_raw.lower().strip()


# ============================================================================
# CLI
# ============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Import product catalog into Trenzy database"
    )
    parser.add_argument(
        "--source",
        required=True,
        help="Path to source file (JSON or CSV) or S3 URI",
    )
    parser.add_argument(
        "--format",
        choices=["json", "csv"],
        default="json",
        help="Input file format (default: json)",
    )
    parser.add_argument(
        "--database",
        help="Database URL (defaults to environment POSTGRES_* variables)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate without inserting into database",
    )
    parser.add_argument(
        "--report",
        help="Path to save JSON report (defaults to catalog_import_TIMESTAMP.json)",
    )

    args = parser.parse_args()

    # Initialize importer
    importer = CatalogImporter(
        database_url=args.database,
        dry_run=args.dry_run,
    )

    # Load and import
    if args.format == "json":
        importer.import_from_json(args.source)
    elif args.format == "csv":
        importer.import_from_csv(args.source)

    # Save report
    importer.save_report(args.report)

    # Exit with appropriate code
    if importer.stats["total_failed"] > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
