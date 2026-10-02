"""Import the Trenzy catalog and optionally generate FashionCLIP embeddings.

The binary dataset stays outside Git. A typical runtime mount is:
  /data/trenzy/images/TRZ-0001.jpg
  /data/trenzy/catalog.csv

Examples (run from backend/):
  python -m app.scripts.import_image_catalog --image-dir /data/trenzy/images --catalog-file /data/trenzy/catalog.csv --dry-run
  python -m app.scripts.import_image_catalog --image-dir /data/trenzy/images --catalog-file /data/trenzy/catalog.csv
  python -m app.scripts.import_image_catalog --image-dir /data/trenzy/images --catalog-file /data/trenzy/catalog.csv --embed

The job is idempotent and resume-safe:
- catalog rows are keyed by their stable TRZ IDs;
- changed image hashes reset embedding status;
- completed embeddings for the current model/version are skipped;
- failed embeddings are retried on the next run;
- a non-zero exit code is returned if any embedding remains failed.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image, UnidentifiedImageError

from ..db import SessionLocal
from ..models import Product
from ..ai.ml_config import EMBEDDING_DIM

logger = logging.getLogger(__name__)

DEFAULT_IMAGE_DIR = Path(__file__).resolve().parents[2] / "uploads" / "product-images" / "images"
DEFAULT_CATALOG_FILE = Path(__file__).resolve().parents[2] / "uploads" / "product-images" / "catalog.csv"
ALLOWED = {".jpg", ".jpeg", ".png", ".webp"}
MIN_DIMENSION = 64
MAX_PIXELS = 4096 * 4096
CATALOG_SOURCE = "trenzy_generated_catalog"


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

    required = {
        "id", "name", "category", "product_type", "color", "style",
        "price", "currency", "image_file",
    }
    missing = required - set(rows[0].keys() if rows else ())
    if missing:
        raise ValueError(f"catalog is missing columns: {sorted(missing)}")

    ids = [_clean(row.get("id")) for row in rows]
    duplicates = sorted({item for item in ids if item and ids.count(item) > 1})
    if duplicates:
        raise ValueError(f"catalog contains duplicate product IDs: {duplicates[:10]}")

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
        source=CATALOG_SOURCE,
        source_license="owner-provided dataset",
        license_attribution="Trenzy generated catalog",
        search_keywords=[
            v for v in (
                _clean(row.get("product_type")),
                _clean(row.get("style")),
                _clean(row.get("color")),
            ) if v
        ],
        style_tags=[_clean(row.get("style"))] if _clean(row.get("style")) else None,
        color_tags=[_clean(row.get("color"))] if _clean(row.get("color")) else None,
    )


def _apply_row(product: Product, row: dict[str, str], image_url: str, digest: str) -> bool:
    """Update a product and return whether its source image changed."""
    image_changed = product.image_sha256 != digest

    product.name = _clean(row.get("name")) or product.name
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
    product.source = CATALOG_SOURCE
    product.source_license = "owner-provided dataset"
    product.license_attribution = "Trenzy generated catalog"
    product.search_keywords = [
        v for v in (
            _clean(row.get("product_type")),
            _clean(row.get("style")),
            _clean(row.get("color")),
        ) if v
    ]
    product.style_tags = [_clean(row.get("style"))] if _clean(row.get("style")) else None
    product.color_tags = [_clean(row.get("color"))] if _clean(row.get("color")) else None

    if image_changed:
        product.image_embedding_status = "pending"
        product.text_embedding_status = "pending"
        product.image_embedding_model = None
        product.text_embedding_model = None
        product.image_embedding_version = None
        product.text_embedding_version = None
        product.image_embedding_created_at = None
        product.text_embedding_created_at = None

    return image_changed


def _validate_embedding(vector: Any, label: str) -> np.ndarray:
    array = np.asarray(vector, dtype=np.float32).reshape(-1)
    if array.size != EMBEDDING_DIM:
        raise ValueError(
            f"{label} dimension {array.size} != expected {EMBEDDING_DIM}"
        )
    if not np.isfinite(array).all():
        raise ValueError(f"{label} contains NaN or Inf")
    return array


def _embedding_is_current(product: Product, model_name: str, model_version: str) -> bool:
    return (
        product.image_embedding_status == "completed"
        and product.text_embedding_status == "completed"
        and product.image_embedding_model == model_name
        and product.text_embedding_model == model_name
        and product.image_embedding_version == model_version
        and product.text_embedding_version == model_version
        and product.image_embedding_vector is not None
        and product.text_embedding_vector is not None
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Import the Trenzy product catalog.")
    parser.add_argument("--image-dir", type=Path, default=DEFAULT_IMAGE_DIR)
    parser.add_argument("--catalog-file", type=Path, default=DEFAULT_CATALOG_FILE)
    parser.add_argument("--embed", action="store_true", help="Generate FashionCLIP image/text embeddings.")
    parser.add_argument("--dry-run", action="store_true", help="Validate the catalog/images without writing to the database.")
    parser.add_argument("--limit", type=int, default=0, help="Only process the first N rows (useful for smoke tests).")
    parser.add_argument("--batch-size", type=int, default=32, help="Embedding/database commit batch size.")
    args = parser.parse_args()

    if args.limit < 0 or args.batch_size < 1:
        parser.error("--limit must be >= 0 and --batch-size must be >= 1")

    image_dir = args.image_dir.resolve()
    catalog_file = args.catalog_file.resolve()

    if not image_dir.is_dir():
        logger.error("Image directory does not exist: %s", image_dir)
        return 2
    if not catalog_file.is_file():
        logger.error("Catalog CSV does not exist: %s", catalog_file)
        return 2

    try:
        rows = _load_catalog(catalog_file)
    except (OSError, ValueError) as exc:
        logger.error("Catalog validation failed: %s", exc)
        return 2

    if args.limit:
        rows = rows[:args.limit]
    if not rows:
        logger.error("Catalog CSV contains no rows")
        return 2

    logger.info("Validating %d catalog rows and images...", len(rows))
    valid_rows: list[tuple[dict[str, str], Path, str]] = []
    invalid = 0

    for row in rows:
        product_id = _clean(row.get("id"))
        image_file = _clean(row.get("image_file"))
        if not product_id or not image_file:
            invalid += 1
            logger.warning("Skipping row with missing id/image_file")
            continue

        image_path = (image_dir / Path(image_file).name).resolve()
        if image_path.parent != image_dir:
            invalid += 1
            logger.warning("Rejected path traversal for %s: %s", product_id, image_file)
            continue
        if image_path.suffix.lower() not in ALLOWED or not image_path.is_file():
            invalid += 1
            logger.warning("Missing/unsupported image for %s: %s", product_id, image_file)
            continue

        try:
            _validate_image(image_path)
            digest = _sha256(image_path)
        except (UnidentifiedImageError, OSError, ValueError) as exc:
            invalid += 1
            logger.warning("Invalid image for %s: %s", product_id, exc)
            continue

        valid_rows.append((row, image_path, digest))

    logger.info("Validation complete: %d valid, %d invalid", len(valid_rows), invalid)
    if invalid:
        logger.error("Catalog validation is incomplete; fix the dataset before production import.")
        return 3

    if args.dry_run:
        logger.info("Dry run successful: %d products are ready.", len(valid_rows))
        return 0

    db = SessionLocal()
    imported = 0
    failed_embeddings = 0
    try:
        for start in range(0, len(valid_rows), args.batch_size):
            batch = valid_rows[start:start + args.batch_size]
            for row, image_path, digest in batch:
                product_id = _clean(row["id"])
                product = db.get(Product, product_id)
                image_url = f"/product-images/{image_path.name}"

                if product is None:
                    db.add(_product_from_row(row, image_url, digest))
                else:
                    _apply_row(product, row, image_url, digest)
                imported += 1

            db.commit()
            logger.info("Catalog rows committed: %d/%d", min(start + len(batch), len(valid_rows)), len(valid_rows))

        if not args.embed:
            logger.info("Catalog import complete: %d products.", imported)
            return 0

        from ..ai.vision.embedding_service import get_embedding_service

        service = get_embedding_service()
        model_name = service.model_name
        model_version = service.model_version

        products = (
            db.query(Product)
            .filter(Product.source == CATALOG_SOURCE)
            .order_by(Product.id)
            .all()
        )

        # Keep embedding work deterministic and resumable. A completed product
        # is skipped only when both vectors are present and match this model.
        to_embed = [p for p in products if not _embedding_is_current(p, model_name, model_version)]
        logger.info(
            "Embedding status: %d total catalog products, %d already current, %d to process.",
            len(products), len(products) - len(to_embed), len(to_embed),
        )

        for start in range(0, len(to_embed), args.batch_size):
            batch = to_embed[start:start + args.batch_size]
            batch_failed = 0

            for product in batch:
                image_path = image_dir / Path(product.image_url or "").name
                now = datetime.now(timezone.utc)

                # Mark work as running before inference so an interrupted job is
                # never mistaken for a completed one.
                product.image_embedding_status = "processing"
                product.text_embedding_status = "processing"
                db.commit()

                try:
                    image_embedding = _validate_embedding(
                        service.model.encode_image(str(image_path)),
                        "image embedding",
                    )
                    text_embedding = _validate_embedding(
                        service.model.encode_text(service._build_product_text(product)),
                        "text embedding",
                    )

                    product.image_embedding_vector = image_embedding.tolist()
                    product.text_embedding_vector = text_embedding.tolist()
                    product.image_embedding_status = "completed"
                    product.text_embedding_status = "completed"
                    product.image_embedding_model = model_name
                    product.text_embedding_model = model_name
                    product.image_embedding_version = model_version
                    product.text_embedding_version = model_version
                    product.image_embedding_created_at = now
                    product.text_embedding_created_at = now
                except Exception as exc:
                    batch_failed += 1
                    failed_embeddings += 1
                    product.image_embedding_status = "failed"
                    product.text_embedding_status = "failed"
                    logger.exception("Embedding failed for product %s: %s", product.id, exc)

            db.commit()
            completed = sum(
                1 for p in to_embed[:start + len(batch)]
                if _embedding_is_current(p, model_name, model_version)
            )
            logger.info(
                "Embedding batch complete: %d/%d current; %d failed in this batch.",
                min(start + len(batch), len(to_embed)),
                len(to_embed),
                batch_failed,
            )

        remaining = (
            db.query(Product)
            .filter(
                Product.source == CATALOG_SOURCE,
                (Product.image_embedding_status != "completed")
                | (Product.text_embedding_status != "completed"),
            )
            .count()
        )
        if remaining:
            logger.error("Embedding job incomplete: %d catalog products still lack current embeddings.", remaining)
            return 4

        logger.info("Catalog + embedding import complete: %d products, all embeddings current.", len(products))
        return 0
    except Exception:
        db.rollback()
        logger.exception("Catalog import failed unexpectedly.")
        return 5
    finally:
        db.close()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
    raise SystemExit(main())
