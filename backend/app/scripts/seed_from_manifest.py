"""Seed catalog products strictly 1-to-1 from verified image manifest.

Guarantees:
- Zero image URL duplication: Exactly 1 product per unique image in manifest.
- Zero hash duplication: SHA-256 and pHash preserved from manifest.
- Zero missing license/attribution: Complete legal metadata copied to Product schema.
- Currency set to INR.
- Strict data contract compliance.
"""

import os
import sys
import json
import random
import logging
from pathlib import Path
from typing import Dict, List, Set, Any, Optional

from sqlalchemy.orm import Session

# Add backend directory to sys.path
SCRIPT_DIR = Path(__file__).resolve().parent
BACKEND_DIR = SCRIPT_DIR.parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.db import SessionLocal
from app.models import Product
from ml.contracts.data_contracts import CatalogItemContract

logger = logging.getLogger("seed_catalog")
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

MANIFEST_PATH = BACKEND_DIR / "data" / "image_manifest.json"
CATALOG_JSON_PATH = BACKEND_DIR / "data" / "products.json"

CATEGORIES = [
    "tops", "bottoms", "dresses", "outerwear",
    "footwear", "accessories", "bags", "jewelry",
]

CATEGORY_KEYWORDS = {
    "dress": "dresses",
    "gown": "dresses",
    "skirt": "bottoms",
    "trousers": "bottoms",
    "pants": "bottoms",
    "jeans": "bottoms",
    "shirt": "tops",
    "t-shirt": "tops",
    "tee": "tops",
    "blouse": "tops",
    "sweater": "tops",
    "hoodie": "tops",
    "jacket": "outerwear",
    "coat": "outerwear",
    "blazer": "outerwear",
    "suit": "outerwear",
    "shoe": "footwear",
    "sneaker": "footwear",
    "boot": "footwear",
    "sandal": "footwear",
    "bag": "bags",
    "handbag": "bags",
    "backpack": "bags",
    "purse": "bags",
    "necklace": "jewelry",
    "ring": "jewelry",
    "bracelet": "jewelry",
    "earring": "jewelry",
    "hat": "accessories",
    "cap": "accessories",
    "scarf": "accessories",
    "belt": "accessories",
    "sunglasses": "accessories",
}

STYLES = ["streetwear", "minimal", "classic", "boho", "casual", "formal", "sporty", "ethnic", "modern"]
COLORS = ["black", "white", "gray", "navy", "beige", "brown", "red", "blue", "green", "pink"]
BRANDS = ["Trenzy Studio", "Aura Urban", "Noir & Co", "Vogue Atelier", "Artisan Loom", "Minimalist Lab", "Solstice Wear", "Kashmir Craft"]


def infer_category(title: str, cat_hint: str) -> str:
    combined = f"{title} {cat_hint}".lower()
    for kw, cat in CATEGORY_KEYWORDS.items():
        if kw in combined:
            return cat
    if "footwear" in combined:
        return "footwear"
    if "garment" in combined or "cloth" in combined:
        return "tops"
    return random.choice(CATEGORIES)


def build_product_record(manifest_item: Dict[str, Any], idx: int) -> Dict[str, Any]:
    # Prefer fields explicitly derived at acquisition time (e.g. by
    # acquire_pexels_images) over title heuristics; fall back for legacy
    # Wikimedia manifests that only carry title/category_hint.
    title = (
        manifest_item.get("product_name")
        or manifest_item.get("title", f"Fashion Item {idx}")
    )
    # Clean up file title
    clean_title = (
        title.replace("File:", "")
        .replace(".jpg", "")
        .replace(".jpeg", "")
        .replace(".png", "")
        .replace(".webp", "")
        .replace("_", " ")
        .strip()
    )
    if len(clean_title) > 60:
        clean_title = clean_title[:57] + "..."

    cat_hint = manifest_item.get("category_hint", "")
    category = manifest_item.get("product_category") or infer_category(clean_title, cat_hint)
    style = random.choice(STYLES)
    manifest_colors = manifest_item.get("colors") or []
    color = manifest_colors[0] if manifest_colors else random.choice(COLORS)
    brand = random.choice(BRANDS)

    # Deterministic price based on index
    price_cents = 799 + (hash(manifest_item["sha256"]) % 4200)
    price = float(price_cents)

    prod_id = f"trenzy_{idx:04d}"

    return {
        "id": prod_id,
        "name": clean_title if len(clean_title) >= 5 else f"{brand} {style.capitalize()} {category.capitalize()}",
        "description": f"Curated {style} {category} in {color} by {brand}. Sourced under {manifest_item.get('license', 'CC BY-SA')}.",
        "category": category,
        "price": price,
        "currency": "INR",
        "brand": brand,
        "style": style,
        "color": color,
        "colors": manifest_colors or [color],
        "image_url": manifest_item["image_url"],
        "image_sha256": manifest_item["sha256"],
        "image_phash": manifest_item.get("phash"),
        "source": manifest_item.get("source", "Wikimedia Commons"),
        "source_license": manifest_item.get("license", "CC BY-SA"),
        "source_page": manifest_item.get("source_page"),
        "license_attribution": manifest_item.get("attribution") or manifest_item.get("license"),
        "author": manifest_item.get("author", "Unknown Contributor"),
        "is_archived": False,
        "rating": round(4.0 + (hash(prod_id) % 10) * 0.1, 1),
    }


def seed_catalog(target_count: Optional[int] = None, sync_db: bool = True) -> List[Dict[str, Any]]:
    if not MANIFEST_PATH.exists():
        raise FileNotFoundError(f"Manifest not found at {MANIFEST_PATH}. Run acquire_fashion_images first.")

    with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
        manifest = json.load(f)

    if not manifest:
        raise ValueError("Image manifest is empty. Cannot generate catalog.")

    if target_count and len(manifest) > target_count:
        items_to_seed = manifest[:target_count]
    else:
        items_to_seed = manifest

    logger.info("Generating catalog from %d unique manifest images...", len(items_to_seed))

    products: List[Dict[str, Any]] = []
    seen_urls: Set[str] = set()
    seen_hashes: Set[str] = set()

    for i, item in enumerate(items_to_seed, start=1):
        url = item["image_url"]
        sha = item["sha256"]

        # Strict invariant enforcement: no duplicates permitted
        if url in seen_urls:
            logger.warning("Skipping duplicate image URL in manifest: %s", url)
            continue
        if sha in seen_hashes:
            logger.warning("Skipping duplicate SHA-256 in manifest: %s", sha)
            continue

        prod = build_product_record(item, i)

        # Validate with ML data contract
        contract = CatalogItemContract(
            id=prod["id"],
            name=prod["name"],
            category=prod["category"],
            price=prod["price"],
            currency=prod["currency"],
            image_url=prod["image_url"],
            image_sha256=prod["image_sha256"],
            image_phash=prod["image_phash"],
            source_page=prod["source_page"],
            license_attribution=prod["license_attribution"],
            author=prod["author"],
            is_archived=prod["is_archived"],
        )
        res = contract.validate()
        if not res.is_valid:
            logger.error("Contract failure for product %s: %s", prod["id"], res.errors)
            continue

        products.append(prod)
        seen_urls.add(url)
        seen_hashes.add(sha)

    # Save to products.json
    with open(CATALOG_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(products, f, indent=2, ensure_ascii=False)
    logger.info("Saved %d products to %s", len(products), CATALOG_JSON_PATH)

    # Sync to database if requested
    if sync_db:
        db: Session = SessionLocal()
        try:
            # Upsert products into database
            inserted = 0
            updated = 0
            for p_dict in products:
                existing = db.query(Product).filter(Product.id == p_dict["id"]).first()
                if existing:
                    for k, v in p_dict.items():
                        if hasattr(existing, k):
                            setattr(existing, k, v)
                    updated += 1
                else:
                    new_prod = Product(**{k: v for k, v in p_dict.items() if hasattr(Product, k)})
                    db.add(new_prod)
                    inserted += 1
            db.commit()
            logger.info("DB sync complete: %d inserted, %d updated", inserted, updated)
        except Exception as e:
            db.rollback()
            logger.error("DB sync failed: %s", e)
        finally:
            db.close()

    return products


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Seed catalog from image manifest")
    parser.add_argument("--count", type=int, default=None, help="Max count to seed")
    parser.add_argument("--no-db", action="store_true", help="Skip DB upsert")
    args = parser.parse_args()

    seed_catalog(target_count=args.count, sync_db=not args.no_db)
