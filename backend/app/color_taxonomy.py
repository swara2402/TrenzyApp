"""Canonical color taxonomy for onboarding and recommendation matching.

Single source of truth for color normalization. Maps raw catalog color
strings to a small, clean set of canonical colors used in:

- Onboarding color picker (clean UI, no duplicates)
- Recommendation/feed color matching (user picks canonical, products normalize)
- Signal vector aggregation (behavioral feedback uses canonical names)
"""

from __future__ import annotations

# ── Canonical colors (shown in onboarding) ───────────────────────────────────

CANONICAL_COLORS: list[dict[str, str]] = [
    {"name": "Black",       "hex": "#000000"},
    {"name": "White",       "hex": "#FFFFFF"},
    {"name": "Grey",        "hex": "#9E9E9E"},
    {"name": "Beige",       "hex": "#F5F5DC"},
    {"name": "Brown",       "hex": "#795548"},
    {"name": "Navy",        "hex": "#001F3F"},
    {"name": "Blue",        "hex": "#2196F3"},
    {"name": "Green",       "hex": "#4CAF50"},
    {"name": "Red",         "hex": "#F44336"},
    {"name": "Pink",        "hex": "#E91E63"},
    {"name": "Yellow",      "hex": "#FFEB3B"},
    {"name": "Orange",      "hex": "#FF9800"},
    {"name": "Purple",      "hex": "#9C27B0"},
    {"name": "Multicolor",  "hex": "#FF6F00"},
]

_CANONICAL_NAMES: set[str] = {c["name"].lower() for c in CANONICAL_COLORS}

# ── Alias map: raw catalog string → canonical name ────────────────────────────
# Keys must be lowercased and stripped. Add more from actual DB values.

COLOR_ALIASES: dict[str, str] = {
    # Black
    "black": "Black",
    "jet black": "Black",
    "obsidian": "Black",
    "onyx": "Black",
    "noir": "Black",

    # White
    "white": "White",
    "off white": "White",
    "off-white": "White",
    "ivory": "White",
    "cream": "White",
    "pearl": "White",
    "snow": "White",
    "arctic white": "White",
    "pure white": "White",

    # Grey / Gray
    "grey": "Grey",
    "gray": "Grey",
    "charcoal": "Grey",
    "anthracite": "Grey",
    "slate": "Grey",
    "ash": "Grey",
    "smoke": "Grey",
    "smoky": "Grey",
    "dove": "Grey",
    "pewter": "Grey",
    "silver": "Grey",
    "light grey": "Grey",
    "dark grey": "Grey",
    "light gray": "Grey",
    "dark gray": "Grey",

    # Beige / Tan / Khaki
    "beige": "Beige",
    "khaki": "Beige",
    "tan": "Beige",
    "camel": "Beige",
    "sand": "Beige",
    "stone": "Beige",
    "ecru": "Beige",
    "latte": "Beige",
    "biscuit": "Beige",
    "nude": "Beige",
    "fawn": "Beige",

    # Brown
    "brown": "Brown",
    "chocolate": "Brown",
    "coffee": "Brown",
    "mocha": "Brown",
    "caramel": "Brown",
    "toffee": "Brown",
    "cinnamon": "Brown",
    "espresso": "Brown",
    "mahogany": "Brown",
    "copper": "Brown",
    "bronze": "Brown",
    "rust": "Brown",
    "sienna": "Brown",
    "umber": "Brown",

    # Navy
    "navy": "Navy",
    "navy blue": "Navy",
    "dark blue": "Navy",
    "midnight blue": "Navy",
    "prussian blue": "Navy",
    "oxford blue": "Navy",

    # Blue
    "blue": "Blue",
    "light blue": "Blue",
    "sky blue": "Blue",
    "baby blue": "Blue",
    "royal blue": "Blue",
    "cobalt": "Blue",
    "azure": "Blue",
    "aqua": "Blue",
    "cyan": "Blue",
    "turquoise": "Blue",
    "teal": "Blue",
    "ice blue": "Blue",
    "powder blue": "Blue",
    "cornflower": "Blue",
    "denim": "Blue",

    # Green
    "green": "Green",
    "olive": "Green",
    "olive green": "Green",
    "army green": "Green",
    "forest green": "Green",
    "emerald": "Green",
    "sage": "Green",
    "mint": "Green",
    "lime": "Green",
    "sea green": "Green",
    "hunter green": "Green",
    "bottle green": "Green",
    "military green": "Green",
    "neon green": "Green",
    "pistachio": "Green",

    # Red
    "red": "Red",
    "maroon": "Red",
    "burgundy": "Red",
    "wine": "Red",
    "crimson": "Red",
    "scarlet": "Red",
    "cherry": "Red",
    "ruby": "Red",
    "garnet": "Red",
    "brick": "Red",
    "vermilion": "Red",
    "tomato": "Red",
    "berry": "Red",

    # Pink
    "pink": "Pink",
    "hot pink": "Pink",
    "rose": "Pink",
    "blush": "Pink",
    "salmon": "Pink",
    "coral pink": "Pink",
    "dusty pink": "Pink",
    "millennial pink": "Pink",
    "peach": "Pink",
    "fuchsia": "Pink",
    "magenta": "Pink",
    "mauve": "Pink",

    # Yellow
    "yellow": "Yellow",
    "mustard": "Yellow",
    "lemon": "Yellow",
    "gold": "Yellow",
    "champagne": "Yellow",
    "canary": "Yellow",
    "amber": "Yellow",
    "honey": "Yellow",
    "butter": "Yellow",

    # Orange
    "orange": "Orange",
    "coral": "Orange",
    "terracotta": "Orange",
    "peach orange": "Orange",
    "burnt orange": "Orange",
    "tangerine": "Orange",
    "apricot": "Orange",
    "persimmon": "Orange",

    # Purple
    "purple": "Purple",
    "lavender": "Purple",
    "violet": "Purple",
    "plum": "Purple",
    "lilac": "Purple",
    "amethyst": "Purple",
    "mauve purple": "Purple",
    "grape": "Purple",
    "eggplant": "Purple",
    "aubergine": "Purple",
    "indigo": "Purple",

    # Multicolor
    "multi": "Multicolor",
    "multicolor": "Multicolor",
    "multi-color": "Multicolor",
    "print": "Multicolor",
    "printed": "Multicolor",
    "pattern": "Multicolor",
    "colorful": "Multicolor",
    "mixed": "Multicolor",
    "assorted": "Multicolor",
}


# ── Helpers ───────────────────────────────────────────────────────────────────

def normalize_color(raw: str | None) -> str | None:
    """Map a raw catalog color string to its canonical name.

    Returns ``None`` for empty inputs or colors that don't match any alias.
    Unknown colors are silently excluded — prefer extending COLOR_ALIASES
    over letting unknowns through.
    """
    if not raw:
        return None
    key = " ".join(raw.strip().lower().split())
    if not key:
        return None
    return COLOR_ALIASES.get(key)


def canonical_colors() -> list[dict[str, str]]:
    """Return the fixed canonical color list for the onboarding UI."""
    return list(CANONICAL_COLORS)


def canonical_color_names() -> list[str]:
    """Return just the names (convenience for set membership checks)."""
    return [c["name"] for c in CANONICAL_COLORS]


def is_canonical(raw: str) -> bool:
    """Check if a string is already a canonical color name (case-insensitive)."""
    return raw.strip().lower() in _CANONICAL_NAMES


def expand_canonical_to_raw(
    canonical_colors: list[str],
    all_raw_colors: list[str],
) -> list[str]:
    """Expand a list of canonical color names into all raw catalog values that match.

    Given user preferences like ``["Navy"]`` and all raw DB colors
    ``["Navy", "Navy Blue", "Dark Blue", "Black", ...]``, returns
    ``["Navy", "Navy Blue", "Dark Blue"]`` — every raw value whose
    canonical form is in the input list.

    This lets SQL ``IN`` clauses match all variants without changing the
    DB schema.
    """
    if not canonical_colors or not all_raw_colors:
        return list(canonical_colors) if canonical_colors else []

    canonical_set = {c.lower() for c in canonical_colors if c}
    if not canonical_set:
        return []

    matching: list[str] = []
    for raw in all_raw_colors:
        if not raw:
            continue
        norm = normalize_color(raw)
        if norm and norm.lower() in canonical_set:
            matching.append(raw)

    return matching if matching else list(canonical_colors)
