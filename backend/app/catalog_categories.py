"""Canonical garment-category mapping for legacy product records.

Legacy imports used style groups such as streetwear as category. The
specific item type in subcategory is the best available signal for the
customer-facing garment category. Unknown/non-item records intentionally map
to an empty string and are excluded from customer-facing discovery.
"""
from __future__ import annotations

from sqlalchemy import case, or_

from .models import Product

CATEGORY_RULES = (
    ("Footwear", ("footwear", "sneaker", "shoe", "boot", "sandal", "loafer", "trainer", "derby", "heel", "flat")),
    ("Bottoms", ("jeans", "trouser", "pants", "chinos", "shorts", "cargo", "skirt", "legging", "jogger")),
    ("Dresses", ("dress", "gown", "lehenga", "one-piece")),
    ("Outerwear", ("jacket", "coat", "blazer", "windbreaker", "varsity", "overshirt", "cardigan", "outerwear", "parka")),
    ("Accessories", ("bag", "cap", "hat", "belt", "watch", "wallet", "sunglasses", "accessory", "jewelry", "jewellery")),
    ("Tops", ("shirt", "jersey", "sweater", "sweatshirt", "t-shirt", "tee", "polo", "hoodie", "knit", "blouse", "top", "crewneck")),
)


def canonical_category(subcategory: str | None) -> str:
    """Return a canonical garment category only when the item type supports it."""
    text = str(subcategory or "").strip().lower()
    if not text or text in {"unknown", "none", "null", "uncategorized"}:
        return ""
    for category, keywords in CATEGORY_RULES:
        if any(keyword in text for keyword in keywords):
            return category
    return ""


def canonical_category_expr():
    """SQL expression equivalent to canonical_category for query filtering."""
    whens = []
    for category, keywords in CATEGORY_RULES:
        condition = or_(*(Product.subcategory.ilike(f"%{keyword}%") for keyword in keywords))
        whens.append((condition, category))
    return case(*whens, else_="")


def catalog_category_is_classified():
    """SQL predicate that excludes placeholder and non-product records."""
    return canonical_category_expr() != ""
