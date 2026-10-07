"""Load products into the database from CSV/JSON.

Usage:
    python -m app.scripts.load_products

Reads from backend/data/products.csv (or products.json) and upserts into
the products table. Safe to run multiple times (idempotent upsert).

If the data file doesn't exist, exits cleanly with a warning — this
prevents docker-compose from crashing on first run before data is loaded.
"""

import csv
import json
import logging
import os
from pathlib import Path

logger = logging.getLogger(__name__)

DATA_DIR = (Path(__file__).resolve().parents[2] / "data") if (Path(__file__).resolve().parents[2] / "data").exists() else (Path(__file__).resolve().parent.parent / "data")
CSV_PATH = DATA_DIR / "products.csv"
JSON_PATH = DATA_DIR / "products.json"


def load_from_csv() -> list[dict]:
    products = []
    with open(CSV_PATH, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            products.append(row)
    return products


def load_from_json() -> list[dict]:
    with open(JSON_PATH, encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, list):
        return data
    if isinstance(data, dict) and "products" in data:
        return data["products"]
    return []


def _map_fields(p: dict) -> dict:
    """Normalize seed-file fields to Product columns.

    The JSON seed uses a catalog-oriented schema (``mainImage``,
    ``galleryImages``, ``colors``, ``style``, ``tags``); this maps them to the
    legacy CSV-style columns the upsert loop reads.
    """
    image_url = p.get("image_url") or p.get("image") or p.get("mainImage")
    image_base_url = os.getenv("TRENZY_IMAGE_BASE_URL", "").strip().rstrip("/")
    if image_base_url and isinstance(image_url, str) and image_url.startswith("/"):
        # The static image host serves the catalog files from /images/.
        image_path = image_url
        prefix = "/uploads/product-images/images/"
        if image_path.startswith(prefix):
            image_path = "/images/" + image_path[len(prefix):]
        image_url = f"{image_base_url}{image_path}"
    colors = p.get("colors") or (p.get("color") if isinstance(p.get("color"), list) else None)
    color = p.get("color")
    if isinstance(color, list):
        color = color[0] if color else ""
    if not color and colors:
        color = colors[0] if colors else ""

    mapped = dict(p)
    mapped["image_url"] = image_url or ""
    mapped["color"] = color or ""

    tags_val = p.get("tags")
    if isinstance(tags_val, str):
        tags_val = [t.strip() for t in tags_val.split(",") if t.strip()]
    if not tags_val and p.get("style"):
        tags_val = [str(p["style"])]
    mapped["tags"] = tags_val
    return mapped


def main():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")

    if not DATA_DIR.exists():
        logger.warning("Data directory not found at %s — skipping product load.", DATA_DIR)
        return

    products = []
    if CSV_PATH.exists():
        logger.info("Loading products from %s", CSV_PATH)
        products = load_from_csv()
    elif JSON_PATH.exists():
        logger.info("Loading products from %s", JSON_PATH)
        products = load_from_json()
    else:
        logger.warning(
            "No product data file found (looked for %s). "
            "Place products.csv or products.json in backend/data/ to load products.",
            DATA_DIR,
        )
        return

    if not products:
        logger.info("No products to load.")
        return

    logger.info("Found %d products to load. Starting import...", len(products))

    from sqlalchemy.orm import Session
    from ..db import SessionLocal
    from ..models import Product

    session: Session = SessionLocal()
    loaded = 0
    skipped = 0
    try:
        for raw in products:
            p = _map_fields(raw)
            product_id = p.get("id") or p.get("product_id")
            if not product_id:
                skipped += 1
                continue

            existing = session.query(Product).filter(Product.id == str(product_id)).first()
            aff_url = p.get("affiliate_url") or p.get("affiliate_link")
            aff_links = {"default": aff_url} if aff_url else None
            tags_val = p.get("tags")
            if isinstance(tags_val, str):
                tags_val = [t.strip() for t in tags_val.split(",") if t.strip()]

            if existing:
                # Update basic fields
                for field in ["name", "brand", "color", "category", "subcategory",
                              "image_url", "gender", "season", "usage", "article_type",
                              "style", "occasion", "material", "fit", "description",
                              "currency"]:
                    if field in p and p[field]:
                        setattr(existing, field, p[field])
                # Safely update numeric fields
                if "price" in p and p["price"] is not None:
                    existing.price = float(p["price"])
                if "rating" in p and p["rating"] is not None:
                    existing.rating = float(p["rating"])
                if aff_links:
                    existing.affiliate_links = aff_links
                if tags_val:
                    existing.tags = tags_val
            else:
                # Safely convert numeric fields with None handling
                price_val = p.get("price")
                price = float(price_val) if price_val is not None else 0.0
                rating_val = p.get("rating")
                rating = float(rating_val) if rating_val is not None else 0.0
                
                new_product = Product(
                    id=str(product_id),
                    name=p.get("name", ""),
                    brand=p.get("brand", ""),
                    price=price,
                    currency=p.get("currency", "INR") or "INR",
                    color=p.get("color", ""),
                    category=p.get("category", ""),
                    subcategory=p.get("subcategory", ""),
                    image_url=p.get("image_url", ""),
                    affiliate_links=aff_links,
                    rating=rating,
                    gender=p.get("gender", ""),
                    season=p.get("season", ""),
                    usage=p.get("usage", ""),
                    article_type=p.get("article_type", ""),
                    style=p.get("style", ""),
                    occasion=p.get("occasion", ""),
                    material=p.get("material", ""),
                    fit=p.get("fit", ""),
                    description=p.get("description", ""),
                    tags=tags_val,
                )
                session.add(new_product)
            loaded += 1

            if loaded % 500 == 0:
                session.commit()
                logger.info("  ... committed %d products", loaded)

        session.commit()
        logger.info("Product load complete: %d upserted, %d skipped.", loaded, skipped)

        # Local/dev only: keep the catalog in sync with the seed file by
        # removing rows that are not part of it (e.g. leftovers from a one-off
        # Wikimedia import). Never touch a real (production) catalog.
        try:
            from ..config import IS_PRODUCTION
            if not IS_PRODUCTION:
                seed_ids = {str(p.get("id") or p.get("product_id")) for p in products if (p.get("id") or p.get("product_id"))}
                stray = session.query(Product).filter(Product.id.not_in(seed_ids)).all()
                for s in stray:
                    session.delete(s)
                if stray:
                    session.commit()
                    logger.info("Removed %d product(s) not present in the seed data.", len(stray))
        except Exception:
            session.rollback()
            logger.warning("Could not sync stray products to seed (non-fatal).")
    except Exception:
        session.rollback()
        logger.exception("Failed to load products")
        raise
    finally:
        session.close()


if __name__ == "__main__":
    main()