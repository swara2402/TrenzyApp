#!/usr/bin/env python3
"""Replace placeholder (picsum) product images with real fashion photos.

Sources each product's image from Wikimedia Commons using targeted searches
built from the product's name / article type / color, with strict candidate
filtering (title must contain a relevant keyword, JPEG only, minimum size).

Updates BOTH:
  - backend/data/products.json  (catalog source of truth, backed up first)
  - the products table in a database (--database-url; defaults to the local
    dev SQLite via the app's own engine when run inside backend/)

Usage:
    cd backend
    python scripts/fix_product_images.py --dry-run
    python scripts/fix_product_images.py
    python scripts/fix_product_images.py --database-url postgresql+psycopg://user:pass@localhost:5433/trenzy
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
import time
import urllib.parse
from pathlib import Path
from typing import Any

import requests

BACKEND_DIR = Path(__file__).resolve().parents[1]
PRODUCTS_JSON = BACKEND_DIR / "data" / "products.json"

COMMONS_API = "https://commons.wikimedia.org/w/api.php"
HEADERS = {"User-Agent": "TrenzyCatalog/1.0 (https://trenzy.app; contact@trenzy.app)"}

# article_type -> (search term, accepted title keywords)
TYPE_QUERIES: dict[str, tuple[str, list[str]]] = {
    "tshirt": ("t-shirt", ["t-shirt", "tshirt", "tee"]),
    "jeans": ("denim jeans", ["jean", "denim"]),
    "bag": ("leather handbag", ["bag", "handbag", "purse"]),
    "tote": ("tote bag", ["tote", "bag"]),
    "watch": ("wristwatch", ["watch"]),
    "sneakers": ("sneakers", ["sneaker", "trainer", "shoe"]),
    "hoodie": ("hoodie", ["hoodie", "sweatshirt"]),
    "shirt": ("button-down shirt", ["shirt"]),
    "blazer": ("blazer jacket", ["blazer", "jacket"]),
    "skirt": ("skirt", ["skirt"]),
    "trousers": ("trousers", ["trouser", "pant"]),
    "cargo": ("cargo pants", ["cargo", "pant"]),
    "shorts": ("shorts clothing", ["short"]),
    "boots": ("leather boots", ["boot"]),
    "loafers": ("loafer shoes", ["loafer", "shoe"]),
    "espadrilles": ("espadrilles", ["espadrill", "shoe"]),
    "sandals": ("sandals", ["sandal"]),
    "sunglasses": ("sunglasses", ["sunglass", "glasses"]),
    "cap": ("baseball cap", ["cap", "hat"]),
    "dress": ("dress clothing", ["dress", "gown"]),
    "sweater": ("knitted sweater", ["sweater", "jumper", "knit"]),
}

# Words that mark an image as unfit for a product catalog even if the
# keyword matches (archives, museum/costume context, diagrams, people-heavy).
BAD_TITLE_WORDS = [
    "bundesarchiv", "archive", "historic", "vintage photo", "museum",
    "costume", "caricature", "poster", "diagram", "chart", "map",
    "flag", "coat of arms", "illustration", "engraving", "painting",
    "statue", "drawing", "sketch", "black and white", "swastika",
    # relevance noise seen during the first acquisition run
    "shaman", "viking", "bunny", "on sale", "reconstructed", "applying",
    "mink oil", "logo", "ambigram", "myth", "cartoon", "meme",
    "traditional", "ethnic", "ceremonial", "ritual", "ancient",
    "repair", "cleaning", "washing", "manufacturing", "factory",
    "stack", "pile", "row of", "hanging on rack", "mannequin",
    "fetish", "latex", "pvc", "lingerie", "nude", "flag",
]

# Museum accession numbers in file titles, e.g. "Dress, girls (AM 1999.107.126-5).jpg"
MUSEUM_ACCESSION_RE = re.compile(r"\([a-z]{1,4} \d{4}")

COMMON_COLORS = {
    "black", "white", "brown", "navy", "blue", "red", "green", "olive",
    "gray", "grey", "beige", "cream", "pink", "gold", "silver",
}


def build_query(product: dict[str, Any]) -> tuple[str, list[str]]:
    article = (product.get("article_type") or "").lower().strip()
    base_term, keywords = TYPE_QUERIES.get(
        article,
        ((product.get("name") or "clothing").lower(), [article or "clothing"]),
    )
    color = (product.get("color") or "").lower().split("/")[0].strip()
    query = f"{color} {base_term}".strip() if color in COMMON_COLORS else base_term
    return query, keywords


def title_ok(title: str, keywords: list[str]) -> bool:
    t = title.lower()
    if any(bad in t for bad in BAD_TITLE_WORDS):
        return False
    if MUSEUM_ACCESSION_RE.search(t):
        return False
    return any(k in t for k in keywords)


def score_title(title: str, keywords: list[str], product_name: str) -> float:
    """Rank candidates: keyword early in the title + product-name overlap."""
    t = title.lower()
    best_pos = min((t.find(k) for k in keywords if k in t), default=999)
    score = 2.0 if best_pos < 40 else 1.0 if best_pos < 80 else 0.3
    name_words = set(re.findall(r"[a-z]+", product_name.lower()))
    stop = {"the", "a", "of", "and", "classic", "premium", "essential"}
    overlap = len(name_words & set(re.findall(r"[a-z]+", t)) - stop)
    return score + 0.3 * overlap


def commons_search(query: str, limit: int = 12) -> list[dict[str, Any]]:
    """Return file candidates with resolved imageinfo."""
    params = {
        "action": "query",
        "format": "json",
        "list": "search",
        "srsearch": f"{query} filetype:bitmap",
        "srnamespace": "6",
        "srlimit": str(limit),
    }
    r = requests.get(COMMONS_API, params=params, headers=HEADERS, timeout=20)
    r.raise_for_status()
    titles = [hit["title"] for hit in r.json().get("query", {}).get("search", [])]
    if not titles:
        return []

    params = {
        "action": "query",
        "format": "json",
        "titles": "|".join(titles),
        "prop": "imageinfo",
        "iiprop": "url|size|mime",
        "iiurlwidth": "800",
    }
    r = requests.get(COMMONS_API, params=params, headers=HEADERS, timeout=20)
    r.raise_for_status()
    pages = r.json().get("query", {}).get("pages", {})

    out: list[dict[str, Any]] = []
    for page in pages.values():
        info = (page.get("imageinfo") or [{}])[0]
        if not info:
            continue
        if info.get("mime") not in ("image/jpeg", "image/png", "image/webp"):
            continue
        if int(info.get("width") or 0) < 500 or int(info.get("height") or 0) < 400:
            continue
        url = info.get("thumburl") or info.get("url")
        if not url:
            continue
        out.append({"title": page.get("title", ""), "url": url})
    return out


def pick_images(product: dict[str, Any], exclude: set[str]) -> list[dict[str, str]] | None:
    query, keywords = build_query(product)
    candidates = commons_search(query)
    good = [c for c in candidates if title_ok(c["title"], keywords) and c["url"] not in exclude]
    if not good:
        return None
    good.sort(key=lambda c: score_title(c["title"], keywords, product.get("name", "")), reverse=True)
    # Main + up to two gallery shots; avoid duplicates.
    picked: list[dict[str, str]] = []
    for c in good:
        if all(c["url"] != p["url"] for p in picked):
            picked.append(c)
        if len(picked) >= 3:
            break
    return picked


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--database-url", default=None,
                    help="SQLAlchemy URL of a products DB to update as well")
    args = ap.parse_args()

    products = json.loads(PRODUCTS_JSON.read_text())
    replaced, failed = 0, []

    updates: dict[str, dict[str, Any]] = {}
    used_urls: set[str] = set()
    for product in products:
        pid, name = product.get("id"), product.get("name", "?")
        old = product.get("mainImage") or ""
        if old and "picsum" not in old:
            continue  # already real
        urls = pick_images(product, used_urls)
        if not urls:
            failed.append(f"{pid} ({name})")
            print(f"  ✗ {pid} {name}: no suitable Commons image")
            continue
        product["mainImage"] = urls[0]["url"]
        product["galleryImages"] = [u["url"] for u in urls[1:]] or [urls[0]["url"]]
        used_urls.update(u["url"] for u in urls)
        updates[pid] = {"image_url": urls[0]["url"]}
        replaced += 1
        print(f"  ✓ {pid} {name}: {urls[0]['title'][:80]}")
        time.sleep(0.3)  # be polite to the API

    print(f"\nReplaced {replaced}/{len(products)} images.")
    if failed:
        print("Failed: " + ", ".join(failed))

    if args.dry_run:
        print("(dry run — nothing written)")
        return 0

    backup = PRODUCTS_JSON.with_suffix(".json.placeholder-backup")
    if not backup.exists():
        shutil.copy2(PRODUCTS_JSON, backup)
        print(f"Backed up catalog to {backup.name}")
    PRODUCTS_JSON.write_text(json.dumps(products, indent=2))
    print(f"Updated {PRODUCTS_JSON}")

    if updates and args.database_url:
        sys.path.insert(0, str(BACKEND_DIR))
        from sqlalchemy import create_engine, update
        from sqlalchemy.orm import Session

        import app.models as models

        engine = create_engine(args.database_url)
        with Session(engine) as session:
            for pid, values in updates.items():
                session.execute(
                    update(models.Product)
                    .where(models.Product.id == pid)
                    .values(**values)
                )
            session.commit()
        print(f"Updated {len(updates)} rows in the database.")
    elif updates:
        print("(no --database-url passed; DB rows not updated)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
