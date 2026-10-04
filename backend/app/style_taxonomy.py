"""Canonical style taxonomy for onboarding and recommendation matching.

Mirrors the pattern from color_taxonomy.py: a fixed curated list for
onboarding UI + alias map for normalizing raw catalog values.
"""

from __future__ import annotations

# ── Canonical styles (shown in onboarding) ───────────────────────────────────

CANONICAL_STYLES: list[str] = [
    "Casual",
    "Formal",
    "Streetwear",
    "Minimalist",
    "Classic",
    "Bohemian",
    "Sporty",
    "Ethnic",
    "Preppy",
    "Grunge",
]

# ── Alias map: raw catalog string → canonical name ────────────────────────────

STYLE_ALIASES: dict[str, str] = {
    "casual": "Casual",
    "everyday": "Casual",
    "relaxed": "Casual",
    "laid-back": "Casual",
    "informal": "Casual",

    "formal": "Formal",
    "dressy": "Formal",
    "business": "Formal",
    "office": "Formal",
    "professional": "Formal",
    "workwear": "Formal",

    "streetwear": "Streetwear",
    "street": "Streetwear",
    "urban": "Streetwear",
    "hip hop": "Streetwear",
    "hip-hop": "Streetwear",
    "skater": "Streetwear",
    "grunge streetwear": "Streetwear",

    "minimalist": "Minimalist",
    "minimal": "Minimalist",
    "clean": "Minimalist",
    "simple": "Minimalist",
    "basic": "Minimalist",
    "scandinavian": "Minimalist",

    "classic": "Classic",
    "traditional": "Classic",
    "timeless": "Classic",
    "vintage": "Classic",
    "retro": "Classic",
    "heritage": "Classic",

    "bohemian": "Bohemian",
    "boho": "Bohemian",
    "boho-chic": "Bohemian",
    "hippie": "Bohemian",
    "free-spirited": "Bohemian",
    "eclectic": "Bohemian",

    "sporty": "Sporty",
    "athletic": "Sporty",
    "athleisure": "Sporty",
    "activewear": "Sporty",
    "gym": "Sporty",
    "fitness": "Sporty",

    "ethnic": "Ethnic",
    "traditional ethnic": "Ethnic",
    "indian": "Ethnic",
    "desi": "Ethnic",
    "fusion": "Ethnic",
    " Indo-Western": "Ethnic",

    "preppy": "Preppy",
    "collegiate": "Preppy",
    "ivy": "Preppy",
    "nautical": "Preppy",

    "grunge": "Grunge",
    "punk": "Grunge",
    "rock": "Grunge",
    "edgy": "Grunge",
    "rebel": "Grunge",
}


def normalize_style(raw: str | None) -> str | None:
    """Map a raw catalog style string to its canonical name.

    Returns ``None`` for empty inputs. Unknown styles return ``None``
    so callers can skip them rather than letting noise through.
    """
    if not raw:
        return None
    key = " ".join(raw.strip().lower().split())
    if not key:
        return None
    return STYLE_ALIASES.get(key)


def canonical_styles() -> list[str]:
    """Return the fixed canonical style list for the onboarding UI."""
    return list(CANONICAL_STYLES)
