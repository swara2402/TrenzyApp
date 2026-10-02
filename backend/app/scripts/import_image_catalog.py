"""Import the Trenzy 2,000-image catalog into the searchable product table.

The dataset is intentionally kept outside Git. Mount/copy the supplied dataset so
that the runtime has /data/trenzy/images/TRZ-0001.jpg and /data/trenzy/catalog.csv.

Run from backend/:
  python -m app.scripts.import_image_catalog --image-dir /data/trenzy/images --catalog-file /data/trenzy/catalog.csv

Add --embed to generate FashionCLIP image and text vectors.
The importer is idempotent because product IDs come from the catalog (TRZ-0001, ...).
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import logging
from pathlib import Path
from typing import Any

from PIL import Image, UnidentifiedImageError

from ..db import SessionLocal
from ..models import Product

logger = logging.getLogger(__name__)
DEFAULT_IMAGE_DIR = Path(__file__).resolve().parents[2] / "uploads" / "product-images" / "images"
DEFAULT_CATALOG_FILE = Path(__file__).resolve().parents[2] / "uploads" / "product-images" / "catalog.csv"
ALLOWED = {".jpg", ".jpeg", ".png", ".webp"}
MIN_DIMENSION = 64
MAX_PIXELS = 4096 * 4096

def _clean(value: Any) -> str:
    return str(value or "").strip()

def _float_or_none(value: Any) -> float | None:
    raw = _clean(value)
    if not raw:
        return None
    try:
        return float(raw)
    except ValueError:
        return None

def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()

def _validate_image(path: Path) -> tuple[int, int]:
    with Image.open(path) as image:
        image.verify()
    with Image.open(path) as image:
        width, height = image.size
    if width < MIN_DIMENSION or height < MIN_DIMENSION:
        raise ValueError(f"image too small: {width}x{height}")
    if width * height > MAX_PIXELS:
        raise ValueError(f"image too large: {width}x{height}")
    return width, height

def _load_catalog(catalog_file: Path) -> list[dict[str, str]]:
    with catalog_file.open("r", encoding="utf-8-sig", newline="") as fh:
        rows = list(csv.DictReader(fh))
    required = {"id", "name", "category", "product_type", "color", "style", "price", "currency", "image_file"}
    missing = required - set(rows[0].keys() if rows else ())
    if missing:
        raise ValueError(f"catalog is missing columns: {sorted(missing)}")
    return rows

def _product_from_row(row: dict[str, str], image_url: str, image_sha256: str) -> Product:
    return Product(
        id=_clean(row["id"]),
        name=_clean(row["name"]) or "Fashion item",
        description=_clean(row.get("prompt")),
        category=_clean(row.get("category")) or None,
        subcategory=_clean(row.get("product_type")) or None,
        article_type=_clean(row.get("product_type")) or None,
        color=_clean(row.get("color")) or None,
        style=_clean(row.get("style")) or None,
        price=_float_or_none(row.get("price")),
        currency=_clean(row.get("currency")) or "INR",
        image_url=image_url,
        image_sha256=image_sha256,
        source="trenzy_generated_catalog",
        source_license="owner-provided dataset",
        license_attribution="Trenzy generated catalog",
        search_keywords=[v for v in (_clean(row.get("product_type")), _clean(row.get("style")), _clean(row.get("color"))) if v],
        style_tags=[_clean(row.get("style"))] if _clean(row.get("style")) else None,
        color_tags=[_clean(row.get("color"))] if _clean(row.get("color")) else None,
    )

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--image-dir", type=Path, default=DEFAULT_IMAGE_DIR)
    parser.add_argument("--catalog-file", type=Path, default=DEFAULT_CATALOG_FILE)
    parser.add_argument("--embed", action="store_true", help="Generate FashionCLIP image and text embeddings.")
    parser.add_argument("--limit", type=int, default=0, help="Only import the first N rows for smoke tests.")
    args = parser.parse_args()

    image_dir = args.image_dir.resolve()
    catalog_file = args.catalog_file.resolve()
    if not image_dir.is_dir():
        logger.error("Image directory does not exist: %s", image_dir)
        return 2
    if not catalog_file.is_file():
        logger.error("Catalog CSV does not exist: %s", catalog_file)
        return 2

    rows = _load_catalog(catalog_file)
    if args.limit:
        rows = rows[: args.limit]
    if not rows:
        logger.error("Catalog CSV contains no rows")
        return 2

    db = SessionLocal()
    imported = skipped = 0
    try:
        for row in rows:
            product_id = _clean(row.get("id"))
            image_file = _clean(row.get("image_file"))
            if not product_id or not image_file:
                skipped += 1
                continue
            image_path = (image_dir / Path(image_file).name).resolve()
            if image_path.parent != image_dir or image_path.suffix.lower() not in ALLOWED or not image_path.is_file():
                skipped += 1
                logger.warning("Missing/unsupported image for %s: %s", product_id, image_file)
                continue
            try:
                _validate_image(image_path)
                digest = _sha256(image_path)
            except (UnidentifiedImageError, OSError, ValueError) as exc:
                skipped += 1
                logger.warning("Skipping %s: %s", product_id, exc)
                continue

            product = db.get(Product, product_id)
            image_url = f"/product-images/{image_path.name}"
            if product is None:
                db.add(_product_from_row(row, image_url, digest))
            else:
                product.name = _clean(row["name"]) or product.name
                product.description = _clean(row.get("prompt")) or product.description
                product.category = _clean(row.get("category")) or product.category
                product.subcategory = _clean(row.get("product_type")) or product.subcategory
                product.article_type = _clean(row.get("product_type")) or product.article_type
                product.color = _clean(row.get("color")) or product.color
                product.style = _clean(row.get("style")) or product.style
                product.price = _float_or_none(row.get("price"))
                product.currency = _clean(row.get("currency")) or product.currency
                product.image_url = image_url
                product.image_sha256 = digest
                product.source = "trenzy_generated_catalog"
                product.source_license = "owner-provided dataset"
                product.license_attribution = "Trenzy generated catalog"
                product.search_keywords = [v for v in (_clean(row.get("product_type")), _clean(row.get("style")), _clean(row.get("color"))) if v]
                product.style_tags = [_clean(row.get("style"))] if _clean(row.get("style")) else None
                product.color_tags = [_clean(row.get("color"))] if _clean(row.get("color")) else None
            imported += 1
            if imported % 100 == 0:
                db.commit()
                logger.info("Imported %d catalog products", imported)
        db.commit()
        logger.info("Catalog import complete: %d imported, %d skipped", imported, skipped)

        if args.embed:
            from ..ai.vision.embedding_service import get_embedding_service
            service = get_embedding_service()
            products = db.query(Product).filter(Product.source == "trenzy_generated_catalog").order_by(Product.id).all()
            for start in range(0, len(products), 32):
                batch = products[start:start + 32]
                for product in batch:
                    image_path = image_dir / Path(product.image_url or "").name
                    try:
                        image_embedding = service.model.encode_image(str(image_path))
                        text_embedding = service.model.encode_text(service._build_product_text(product))
                        product.image_embedding_vector = image_embedding.tolist()
                        product.text_embedding_vector = text_embedding.tolist()
                        product.image_embedding_status = "completed"
                        product.text_embedding_status = "completed"
                        product.image_embedding_model = service.model_name
                        product.text_embedding_model = service.model_name
                        product.image_embedding_version = service.model_version
                        product.text_embedding_version = service.model_version
                    except Exception:
                        product.image_embedding_status = "failed"
                        product.text_embedding_status = "failed"
                        logger.exception("Embedding failed for product %s", product.id)
                db.commit()
                logger.info("Embedded %d/%d products", min(start + len(batch), len(products)), len(products))
    finally:
        db.close()
    return 0

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
    raise SystemExit(main())
