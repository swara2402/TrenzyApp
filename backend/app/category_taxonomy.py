"""Canonical category taxonomy for onboarding and recommendation matching.

Mirrors the pattern from color_taxonomy.py: a fixed curated list for
onboarding UI + alias map for normalizing raw catalog values.
"""

from __future__ import annotations

# ── Canonical categories (shown in onboarding) ───────────────────────────────

CANONICAL_CATEGORIES: list[str] = [
    "Tops",
    "Bottoms",
    "Dresses",
    "Footwear",
    "Outerwear",
    "Ethnic Wear",
    "Accessories",
    "Activewear",
    "Sleepwear",
    "Swimwear",
]

# ── Alias map: raw catalog string → canonical name ────────────────────────────

CATEGORY_ALIASES: dict[str, str] = {
    # Tops
    "tops": "Tops",
    "shirts": "Tops",
    "t-shirts": "Tops",
    "tshirt": "Tops",
    "t-shirt": "Tops",
    "polo": "Tops",
    "polos": "Tops",
    "blouses": "Tops",
    "tunics": "Tops",
    "tank tops": "Tops",
    "camisoles": "Tops",
    "crop tops": "Tops",
    "sweaters": "Tops",
    "sweatshirts": "Tops",
    "hoodies": "Tops",
    "cardigans": "Tops",
    "knitwear": "Tops",
    "top": "Tops",

    # Bottoms
    "bottoms": "Bottoms",
    "jeans": "Bottoms",
    "trousers": "Bottoms",
    "pants": "Bottoms",
    "chinos": "Bottoms",
    "shorts": "Bottoms",
    "culottes": "Bottoms",
    "jeggings": "Bottoms",
    "leggings": "Bottoms",
    "skirts": "Bottoms",
    "dungarees": "Bottoms",
    "bottom": "Bottoms",

    # Dresses
    "dresses": "Dresses",
    "gowns": "Dresses",
    "maxi dresses": "Dresses",
    "midi dresses": "Dresses",
    "mini dresses": "Dresses",
    "shift dresses": "Dresses",
    "wrap dresses": "Dresses",
    "dress": "Dresses",

    # Footwear
    "footwear": "Footwear",
    "shoes": "Footwear",
    "sneakers": "Footwear",
    "sandals": "Footwear",
    "flats": "Footwear",
    "heels": "Footwear",
    "boots": "Footwear",
    "loafers": "Footwear",
    "formal shoes": "Footwear",
    "sports shoes": "Footwear",
    "floaters": "Footwear",
    "slide": "Footwear",
    "slides": "Footwear",

    # Outerwear
    "outerwear": "Outerwear",
    "jackets": "Outerwear",
    "coats": "Outerwear",
    "blazers": "Outerwear",
    "vests": "Outerwear",
    "gilets": "Outerwear",
    "windcheaters": "Outerwear",
    "parkas": "Outerwear",
    "puffers": "Outerwear",
    "denim jackets": "Outerwear",
    "bomber jackets": "Outerwear",

    # Ethnic Wear
    "ethnic wear": "Ethnic Wear",
    "kurtas": "Ethnic Wear",
    "kurti": "Ethnic Wear",
    "kurtis": "Ethnic Wear",
    "sarees": "Ethnic Wear",
    "sari": "Ethnic Wear",
    "lehengas": "Ethnic Wear",
    "sherwanis": "Ethnic Wear",
    "dhotis": "Ethnic Wear",
    "salwar": "Ethnic Wear",
    "churidar": "Ethnic Wear",
    "palazzos": "Ethnic Wear",
    "dupatta": "Ethnic Wear",
    "ethnic": "Ethnic Wear",
    "traditional": "Ethnic Wear",

    # Accessories
    "accessories": "Accessories",
    "watches": "Accessories",
    "bags": "Accessories",
    "sunglasses": "Accessories",
    "jewellery": "Accessories",
    "jewelry": "Accessories",
    "belts": "Accessories",
    "scarves": "Accessories",
    "hats": "Accessories",
    "caps": "Accessories",
    "wallets": "Accessories",
    "ties": "Accessories",
    "socks": "Accessories",
    "clutches": "Accessories",

    # Activewear
    "activewear": "Activewear",
    "sports": "Activewear",
    "sportswear": "Activewear",
    "gym wear": "Activewear",
    "track pants": "Activewear",
    "tracksuits": "Activewear",
    "yoga": "Activewear",
    "running": "Activewear",

    # Sleepwear
    "sleepwear": "Sleepwear",
    "nightwear": "Sleepwear",
    "pyjamas": "Sleepwear",
    "pajamas": "Sleepwear",
    "nighties": "Sleepwear",
    "robes": "Sleepwear",
    "loungewear": "Sleepwear",

    # Swimwear
    "swimwear": "Swimwear",
    "swimsuits": "Swimwear",
    "bikinis": "Swimwear",
    "trunks": "Swimwear",
    "board shorts": "Swimwear",
}


def normalize_category(raw: str | None) -> str | None:
    """Map a raw catalog category string to its canonical name.

    Returns ``None`` for empty inputs. Unknown categories return ``None``
    so callers can skip them rather than letting noise through.
    """
    if not raw:
        return None
    key = " ".join(raw.strip().lower().split())
    if not key:
        return None
    return CATEGORY_ALIASES.get(key)


def canonical_categories() -> list[str]:
    """Return the fixed canonical category list for the onboarding UI."""
    return list(CANONICAL_CATEGORIES)
