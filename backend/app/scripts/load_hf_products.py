import os
import random
import logging

from datasets import load_dataset
from huggingface_hub import login
from sqlalchemy import select

from ..db import SessionLocal
from ..models import Product

logger = logging.getLogger(__name__)

HF_TOKEN = os.getenv("HF_TOKEN")
if HF_TOKEN and HF_TOKEN != "YOUR_HF_TOKEN_HERE":
    login(HF_TOKEN)

# Realistic brand names for fashion products
FAKE_BRANDS = [
    "Zara",
    "H&M",
    "Nike",
    "Adidas",
    "Levi's",
    "Puma",
    "Gucci",
    "Prada",
    "Ralph Lauren",
    "Tommy Hilfiger",
    "Calvin Klein",
    "Uniqlo",
    "Forever 21",
    "Mango",
    "ASOS",
    "Boohoo",
    "Burberry",
    "Versace",
    "Dior",
    "Louis Vuitton",
    "Chanel",
    "Hermes",
    "Balenciaga",
    "Valentino",
    "Fendi",
    "Armani",
    "North Face",
    "Columbia",
    "Patagonia",
    "Under Armour",
]


def _extract_image_url(item: dict) -> str | None:
    """Extract an image URL from the HF dataset item."""
    # The HF fashion dataset stores image URLs in 'link' field.
    # The 'image' field is a PIL image object, not a URL.
    image_url = item.get("link") or item.get("image_url") or item.get("thumbnail")

    if not image_url:
        return None

    image_url = str(image_url).strip()
    if not image_url:
        return None

    # Drop known-bad URLs.
    if image_url.startswith(("https://example.com/", "http://example.com/")):
        return None

    return image_url


def _generate_price() -> int:
    """Generate a realistic INR price between 499 and 8999."""
    return random.randint(499, 8999)


def _generate_rating() -> float:
    """Generate a realistic rating between 2.5 and 5.0."""
    return round(random.uniform(2.5, 5.0), 1)


def run():
    db = SessionLocal()

    try:
        logger.info("Loading dataset from HuggingFace...")
        dataset = load_dataset("ceyda/fashion-products-small", split="train")
        logger.info("Dataset loaded: %s items", len(dataset))

        inserted = 0
        skipped = 0
        errors = 0

        for i, item in enumerate(dataset):
            try:
                # Build a deterministic product ID from the dataset id field.
                product_id = str(item.get("id", f"hf-{i}"))

                # Check for duplicates.
                existing = (
                    db.execute(select(Product).where(Product.id == product_id))
                    .scalar_one_or_none()
                )
                if existing:
                    skipped += 1
                    continue

                # Extract the name from available fields.
                name = (
                    item.get("productDisplayName")
                    or item.get("productName")
                    or item.get("title")
                    or item.get("filename")
                    or f"Product {product_id}"
                )

                # Extract image URL — skip items without images.
                image_url = _extract_image_url(item)
                if not image_url:
                    skipped += 1
                    continue

                product = Product(
                    id=product_id,
                    name=str(name).strip(),
                    category=item.get("masterCategory"),
                    subcategory=item.get("subCategory"),
                    article_type=item.get("articleType"),
                    gender=item.get("gender"),
                    color=item.get("baseColor") or item.get("baseColour"),
                    season=item.get("season"),
                    usage=item.get("usage"),
                    price=_generate_price(),
                    brand=random.choice(FAKE_BRANDS),
                    rating=_generate_rating(),
                    image_url=image_url,
                    tags=[],
                    affiliate_links=None,
                )

                db.add(product)
                inserted += 1

                # Commit in batches of 50 for efficiency.
                if inserted % 50 == 0:
                    db.commit()
                    logger.info("Committed batch at %s products...", inserted)

            except Exception as e:
                errors += 1
                logger.warning("Skipping item %s: %s", i, e)
                # Rollback this item but continue.
                db.rollback()

        # Final commit for any remaining items.
        db.commit()
        logger.info(
            "Done! Inserted: %s, Skipped (existing/no-image): %s, Errors: %s",
            inserted,
            skipped,
            errors,
        )

    finally:
        db.close()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    run()

