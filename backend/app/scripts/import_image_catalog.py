"""Import local fashion images into the Trenzy searchable product catalog.

Usage:
    cd backend
    python -m app.scripts.import_image_catalog
    python -m app.scripts.import_image_catalog --embed

Images are read from backend/uploads/product-images/images. That directory is
intentionally ignored by Git; production/Docker deployments should mount it
as catalog data. Product URLs are served from /product-images/<filename>.
"""

from __future__ import annotations

import argparse
import hashlib
import logging
import re
from pathlib import Path

from PIL import Image, UnidentifiedImageError

from ..db import SessionLocal
from ..models import Product

logger = logging.getLogger(__name__)
IMAGE_DIR = Path(__file__).resolve().parents[2] / "uploads" / "product-images" / "images"
ALLOWED = {".jpg", ".jpeg", ".png", ".webp"}
MAX_PIXELS = 4096 * 4096


def product_id_for(path: Path) -> str:
    return "img-" + hashlib.sha256(path.read_bytes()).hexdigest()[:20]


def name_from_filename(path: Path) -> str:
    return re.sub(r"[_-]+", " ", path.stem).strip() or "Fashion item"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--embed", action="store_true")
    ap.add_argument("--limit", type=int, default=0)
    args = ap.parse_args()

    images = sorted(p for p in IMAGE_DIR.rglob("*") if p.is_file() and p.suffix.lower() in ALLOWED)
    if args.limit:
        images = images[:args.limit]
    if not images:
        logger.error("No catalog images found at %s", IMAGE_DIR)
        return 2

    db = SessionLocal()
    imported = skipped = 0
    try:
        for path in images:
            try:
                with Image.open(path) as im:
                    im.verify()
                with Image.open(path) as im:
                    w, h = im.size
                    if w < 64 or h < 64 or w * h > MAX_PIXELS:
                        raise ValueError(f"invalid dimensions {w}x{h}")
            except (UnidentifiedImageError, OSError, ValueError) as exc:
                skipped += 1
                logger.warning("Skipping %s: %s", path.name, exc)
                continue

            pid = product_id_for(path)
            rel = path.relative_to(IMAGE_DIR).as_posix()
            url = f"/product-images/{rel}"
            product = db.get(Product, pid)
            if product is None:
                product = Product(id=pid, name=name_from_filename(path),
                                  image_url=url, currency="INR",
                                  source="local_image_catalog")
                db.add(product)
            else:
                product.image_url = url
            imported += 1
            if imported % 100 == 0:
                db.commit()
                logger.info("Imported %d images", imported)
        db.commit()
        logger.info("Catalog import complete: %d imported, %d skipped", imported, skipped)

        if args.embed:
            from ..ai.vision.embedding_service import get_embedding_service
            service = get_embedding_service()
            products = db.query(Product).filter(Product.image_url.like("/product-images/%")).all()
            for start in range(0, len(products), 32):
                for product in products[start:start + 32]:
                    rel = product.image_url.removeprefix("/product-images/")
                    image_path = IMAGE_DIR / rel
                    emb = service.model.encode_image(str(image_path))
                    product.image_embedding_vector = emb.tolist()
                    product.image_embedding_status = "completed"
                    # Text vectors make natural-language search use the same catalog.
                    text = service._build_product_text(product)
                    product.text_embedding_vector = service.model.encode_text(text).tolist()
                    product.text_embedding_status = "completed"
                    product.image_embedding_model = service.model_name
                db.commit()
                logger.info("Embedded %d/%d products", min(start + 32, len(products)), len(products))
    finally:
        db.close()
    return 0


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
    raise SystemExit(main())
