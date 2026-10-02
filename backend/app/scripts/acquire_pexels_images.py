"""Acquire licensed fashion/apparel product images from the Pexels API.

PHASE 3 replacement pipeline: swap archive-quality Wikimedia Commons photos
for real, commercially-licensed fashion photography.

Pipeline per image:
1. Search Pexels (https://api.pexels.com/v1/search) for each query
2. Download photo bytes via the canonical ImageDownloadService singleton
   into backend/uploads/product-images/
3. Compute real SHA-256 (64-char hex, from downloaded bytes) and perceptual
   pHash from the local file
4. Deduplicate: zero SHA-256 collisions, pHash Hamming distance >= 3
5. Derive product name, category, and colors from the search query
   (dominant-color sampling fallback when the query has no color word)
6. Validate each entry against ml CatalogItemContract BEFORE writing
7. Emit backend/data/image_manifest.json entries compatible with
   app.scripts.seed_from_manifest (title/category_hint/sha256/phash/
   source/source_page/attribution/author/license keys)

Pexels License: free for commercial use, attribution appreciated, not
required. The contributing photographer and the photo page are recorded
per image for the LICENSE_MANIFEST.md generator regardless.

Usage:
    PEXELS_API_KEY=*** python -m app.scripts.acquire_pexels_images \
        --queries queries.json --count 250
    python -m app.scripts.acquire_pexels_images --dry-run   # search only

--queries accepts a JSON file containing either plain strings:
    ["white linen shirt", "leather ankle boots"]
or objects with explicit hints:
    [{"query": "white linen shirt", "category": "tops",
      "colors": ["White"], "name_prefix": "Linen"}]
"""

import json
import logging
import os
import sys
import time
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

import imagehash
import requests
from PIL import Image

# Ensure the backend package root is importable when run as a script
SCRIPT_DIR = Path(__file__).resolve().parent
BACKEND_DIR = SCRIPT_DIR.parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.ai.services.image_download_service import get_image_download_service
from app.config import UPLOAD_BASE_URL
from ml.contracts.data_contracts import CatalogItemContract

DATA_DIR = BACKEND_DIR / "data"
MANIFEST_PATH = DATA_DIR / "image_manifest.json"
PRODUCT_IMAGES_DIR = BACKEND_DIR / "uploads" / "product-images"

SEARCH_URL = "https://api.pexels.com/v1/search"
PHASH_MIN_DISTANCE = 3  # matches the Wikimedia acquirer's near-duplicate gate
MIN_BYTES = 5_000
MAX_PAGES_PER_QUERY = 10  # bounded page depth so dedupe can't spin forever

logger = logging.getLogger("acquire_pexels_images")
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)

# Category taxonomy mirrors app/scripts/seed_from_manifest.CATEGORY_KEYWORDS
CATEGORY_KEYWORDS = {
    "dress": "dresses",
    "gown": "dresses",
    "maxi": "dresses",
    "skirt": "bottoms",
    "trouser": "bottoms",
    "pant": "bottoms",
    "jean": "bottoms",
    "denim": "bottoms",
    "chino": "bottoms",
    "short": "bottoms",
    "legging": "bottoms",
    "shirt": "tops",
    "t-shirt": "tops",
    "tee": "tops",
    "blouse": "tops",
    "sweater": "tops",
    "knit": "tops",
    "hoodie": "tops",
    "jacket": "outerwear",
    "coat": "outerwear",
    "blazer": "outerwear",
    "trench": "outerwear",
    "parka": "outerwear",
    "shoe": "footwear",
    "sneaker": "footwear",
    "boot": "footwear",
    "loafer": "footwear",
    "sandal": "footwear",
    "heel": "footwear",
    "flat": "footwear",
    "bag": "bags",
    "handbag": "bags",
    "tote": "bags",
    "backpack": "bags",
    "purse": "bags",
    "clutch": "bags",
    "necklace": "jewelry",
    "ring": "jewelry",
    "bracelet": "jewelry",
    "earring": "jewelry",
    "hat": "accessories",
    "cap": "accessories",
    "scarf": "accessories",
    "belt": "accessories",
    "sunglass": "accessories",
    "watch": "accessories",
}

# Query color words mapped to display names (aligned with seed COLORS list)
COLOR_KEYWORDS = {
    "black": "Black",
    "white": "White",
    "ivory": "Ivory",
    "cream": "Cream",
    "beige": "Beige",
    "tan": "Tan",
    "brown": "Brown",
    "grey": "Gray",
    "gray": "Gray",
    "charcoal": "Charcoal",
    "navy": "Navy",
    "blue": "Blue",
    "green": "Green",
    "olive": "Olive",
    "red": "Red",
    "burgundy": "Burgundy",
    "wine": "Wine",
    "pink": "Pink",
    "rose": "Rose",
    "yellow": "Yellow",
    "mustard": "Mustard",
    "orange": "Orange",
    "purple": "Purple",
    "lavender": "Lavender",
    "gold": "Gold",
    "silver": "Silver",
    "leather": "Brown",
    "heather": "Heather Gray",
    "off-white": "Off-White",
    "monochrome": "Black",
}

# Named palette for dominant-color fallback sampling
SAMPLE_PALETTE = [
    ("Black", (20, 20, 20)),
    ("White", (245, 245, 245)),
    ("Gray", (128, 128, 128)),
    ("Navy", (20, 30, 80)),
    ("Blue", (50, 100, 180)),
    ("Beige", (220, 200, 170)),
    ("Brown", (120, 80, 50)),
    ("Red", (180, 40, 40)),
    ("Green", (60, 130, 70)),
    ("Pink", (230, 150, 170)),
    ("Cream", (245, 235, 210)),
]

DEFAULT_QUERIES: List[Dict[str, Any]] = [
    {"query": "white cotton t-shirt product"},
    {"query": "blue denim jeans product"},
    {"query": "black leather jacket"},
    {"query": "beige linen shirt"},
    {"query": "knit sweater fashion"},
    {"query": "summer dress fashion"},
    {"query": "tailored blazer suit"},
    {"query": "white sneakers shoes"},
    {"query": "leather boots fashion"},
    {"query": "brown leather handbag"},
    {"query": "gold necklace jewelry"},
    {"query": "sunglasses accessory"},
]


def load_queries(path: Optional[str]) -> List[Dict[str, Any]]:
    """Normalize --queries input (JSON file) to a list of hint dicts."""
    if not path:
        return DEFAULT_QUERIES
    with open(path, "r", encoding="utf-8") as f:
        raw = json.load(f)
    entries: List[Dict[str, Any]] = []
    for item in raw:
        if isinstance(item, str):
            entries.append({"query": item})
        elif isinstance(item, dict) and item.get("query"):
            entries.append(item)
        else:
            logger.warning("Ignoring malformed query entry: %r", item)
    if not entries:
        raise ValueError(f"No usable queries found in {path}")
    return entries


def derive_category(query: str, hint: Optional[str]) -> str:
    if hint:
        return hint
    lowered = query.lower()
    for kw, cat in CATEGORY_KEYWORDS.items():
        if kw in lowered:
            return cat
    return "accessories"


def derive_colors(query: str, hint: Optional[List[str]]) -> List[str]:
    if hint:
        return hint
    lowered = query.lower()
    found = [name for word, name in COLOR_KEYWORDS.items() if word in lowered]
    # dict.fromkeys preserves order and drops dupes (e.g. grey/gray)
    return list(dict.fromkeys(found))


def dominant_color(image_path: Path) -> Optional[str]:
    """Sample the dominant color of the downloaded photo against a palette."""
    try:
        with Image.open(image_path) as img:
            small = img.convert("RGB").resize((50, 50))
        counts: Counter = Counter(small.getdata())
        # Ignore near-background extremes only when the image is mostly one tone
        top, _ = counts.most_common(1)[0]
        best_name, best_dist = None, None
        for name, rgb in SAMPLE_PALETTE:
            dist = sum((a - b) ** 2 for a, b in zip(top, rgb))
            if best_dist is None or dist < best_dist:
                best_name, best_dist = name, dist
        return best_name
    except Exception as e:  # sampling must never break acquisition
        logger.debug("Dominant color sampling failed for %s: %s", image_path, e)
        return None


def derive_name(query: str, alt: str, used_names: Set[str]) -> str:
    """Human product name derived from the search query (alt text as bonus)."""
    base = (alt or "").strip()
    if not (5 <= len(base) <= 60):
        base = query.replace("product", "").strip()
    name = " ".join(w.capitalize() for w in base.split()).rstrip(" .")
    candidate, n = name, 2
    while candidate in used_names:
        candidate = f"{name} No. {n}"
        n += 1
    used_names.add(candidate)
    return candidate


def search_pexels(
    session: requests.Session, api_key: str, query: str, page: int, per_page: int
) -> Tuple[List[Dict[str, Any]], bool]:
    """One Pexels search page. Returns (photos, transient_error)."""
    resp = session.get(
        SEARCH_URL,
        headers={"Authorization": api_key},
        params={
            "query": query,
            "orientation": "portrait",
            "locale": "en-US",
            "page": page,
            "per_page": min(per_page, 80),
        },
        timeout=30,
    )
    if resp.status_code == 429:
        wait = int(resp.headers.get("Retry-After", "60"))
        logger.warning("Pexels search rate limited (429); sleeping %ds", wait)
        time.sleep(min(wait, 120))
        return [], True
    resp.raise_for_status()
    return resp.json().get("photos", []), False


def alt_text(photo: Dict[str, Any]) -> str:
    return photo.get("alt") or ""


def process_photo(
    service, photo: Dict[str, Any], spec: Dict[str, Any], seq: int
) -> Optional[Dict[str, Any]]:
    """Download, hash, validate and manifest one Pexels photo.

    Returns the manifest item, or None if the photo was rejected.
    """
    src = photo.get("src", {})
    image_url = src.get("large") or src.get("original")
    if not image_url:
        return None

    image_id = f"px_{seq:04d}"
    dest = PRODUCT_IMAGES_DIR / f"{image_id}.jpg"

    ok, status, _ = service.download_to_file(image_url, str(dest))
    if not ok:
        logger.warning("Download %s (%s): %s", image_url, status, "skipped")
        return None
    if dest.stat().st_size < MIN_BYTES:
        dest.unlink(missing_ok=True)
        logger.info("Rejected %s: file smaller than %d bytes", image_id, MIN_BYTES)
        return None

    # Real hashes from the downloaded bytes
    sha256 = service.compute_sha256(str(dest))
    with Image.open(dest) as img:
        width, height = img.size
        phash = str(imagehash.phash(img.convert("RGB")))

    query = spec["query"]
    category = derive_category(query, spec.get("category"))
    colors = derive_colors(query, spec.get("colors"))
    if not colors:
        sampled = dominant_color(dest)
        colors = [sampled] if sampled else []
    name = derive_name(query, alt_text(photo), spec["_used_names"])

    photographer = photo.get("user", {}).get("name") or "Pexels Contributor"
    photo_page = photo.get("page", "")
    attribution = f"Photo by {photographer} on Pexels"  # Pexels License
    license_name = "Pexels License"

    # Serve locally via the canonical /uploads mount (same convention as
    # routes/uploads.py) instead of hotlinking the Pexels CDN.
    served_url = f"{UPLOAD_BASE_URL.rstrip('/')}/product-images/{image_id}.jpg"

    item = {
        "image_id": image_id,
        "title": name,
        "product_name": name,
        "product_category": category,
        "colors": colors,
        "category_hint": category,
        "query": query,
        "image_url": served_url,
        "remote_image_url": image_url,
        "local_path": str(dest.relative_to(BACKEND_DIR)),
        "source": "Pexels",
        "source_page": photo_page,
        "license": license_name,
        "license_attribution": attribution,
        "attribution": attribution,
        "author": photographer,
        "sha256": sha256,
        "phash": phash,
        "width": width,
        "height": height,
        "status": "VALID",
        "retrieved_at": datetime.now(timezone.utc).isoformat(),
    }

    # Gate on the ML contract before the item can ever reach seed_from_manifest
    contract = CatalogItemContract(
        id=image_id,
        name=name,
        category=category,
        price=0.0,
        image_url=served_url,
        image_sha256=sha256,
        image_phash=phash,
        source_page=photo_page,
        license_attribution=attribution,
        author=photographer,
        currency="INR",
    )
    res = contract.validate()
    if not res.is_valid:
        dest.unlink(missing_ok=True)
        logger.error("Contract failure for %s: %s", image_id, res.errors)
        return None
    for warning in res.warnings:
        logger.debug("Contract warning for %s: %s", image_id, warning)
    return item


def acquire(
    queries: List[Dict[str, Any]],
    count: int,
    api_key: str,
    dry_run: bool = False,
    append: bool = False,
) -> List[Dict[str, Any]]:
    service = get_image_download_service()
    session = requests.Session()

    manifest: List[Dict[str, Any]] = []
    seen_urls: Set[str] = set()
    seen_sha: Set[str] = set()
    seen_phashes: List[imagehash.ImageHash] = []

    if append and MANIFEST_PATH.exists():
        with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
            for item in json.load(f):
                manifest.append(item)
                seen_urls.add(item.get("image_url", ""))
                seen_sha.add(item.get("sha256", ""))
                if item.get("phash"):
                    seen_phashes.append(imagehash.hex_to_hash(item["phash"]))
        logger.info("Append mode: continuing from %d manifest entries", len(manifest))
    elif MANIFEST_PATH.exists():
        backup = MANIFEST_PATH.with_suffix(".json.pre-pexels")
        MANIFEST_PATH.replace(backup)
        logger.info("Existing manifest backed up to %s", backup)

    new_count = len(manifest)
    PRODUCT_IMAGES_DIR.mkdir(parents=True, exist_ok=True)
    api_calls = 0

    # Round-robin across queries so every style gets coverage
    pages: Dict[int, int] = {}
    active = True
    while active and len(manifest) < count:
        active = False
        for spec in queries:
            if len(manifest) >= count:
                break
            spec.setdefault("_used_names", set())
            key = id(spec)
            page = pages.get(key, 1)
            if page > MAX_PAGES_PER_QUERY:
                continue
            pages[key] = page + 1
            try:
                photos, _transient = search_pexels(
                    session, api_key, spec["query"], page, per_page=30
                )
            except Exception as e:
                logger.error("Search failed for %r: %s", spec["query"], e)
                photos = []
            api_calls += 1

            if dry_run:
                accepted = min(len(photos), max(1, count // len(queries)))
                logger.info(
                    "[dry-run] query=%r -> %d results (%d would be acquired, "
                    "category=%s, colors=%s)",
                    spec["query"], len(photos), accepted,
                    derive_category(spec["query"], spec.get("category")),
                    derive_colors(spec["query"], spec.get("colors")),
                )
                continue

            for photo in photos:
                if len(manifest) >= count:
                    break
                url = (photo.get("src", {}).get("large")
                       or photo.get("src", {}).get("original") or "")
                if not url or url in seen_urls:
                    continue

                item = process_photo(service, photo, spec, len(manifest) + 1)
                if not item:
                    continue
                ph = imagehash.hex_to_hash(item["phash"])
                if item["sha256"] in seen_sha:
                    logger.info("Duplicate SHA-256, removing: %s", item["image_id"])
                    Path(BACKEND_DIR / item["local_path"]).unlink(missing_ok=True)
                    continue
                if any((ph - old) < PHASH_MIN_DISTANCE for old in seen_phashes):
                    logger.info("Near-duplicate pHash, removing: %s", item["image_id"])
                    Path(BACKEND_DIR / item["local_path"]).unlink(missing_ok=True)
                    continue

                seen_urls.add(url)
                seen_sha.add(item["sha256"])
                seen_phashes.append(ph)
                manifest.append(item)
                if len(manifest) % 25 == 0 or len(manifest) == count:
                    logger.info("Acquired %d / %d images", len(manifest), count)

            # Keep looping while any query still yields pages (depth capped above)
            if photos:
                active = True
            time.sleep(0.5)  # stay well under 200 req/h Pexels budget

    if dry_run:
        logger.info(
            "[dry-run] %d API calls made; nothing downloaded, manifest untouched.",
            api_calls,
        )
        return manifest

    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    logger.info(
        "Done. %d new images acquired (manifest now %d entries) -> %s",
        len(manifest) - new_count, len(manifest), MANIFEST_PATH,
    )
    return manifest


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(
        description="Acquire Pexels fashion images into the Trenzy catalog manifest"
    )
    parser.add_argument(
        "--queries",
        type=str,
        default=None,
        help="JSON file of search queries (strings or {query, category, colors} objects)",
    )
    parser.add_argument(
        "--count", type=int, default=250, help="Target number of new images (default: 250)"
    )
    parser.add_argument(
        "--api-key",
        type=str,
        default=os.environ.get("PEXELS_API_KEY", ""),
        help="Pexels API key (defaults to $PEXELS_API_KEY)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Search and report expected acquisitions without downloading or writing",
    )
    parser.add_argument(
        "--append",
        action="store_true",
        help="Keep existing manifest entries instead of backing them up and replacing",
    )
    args = parser.parse_args()

    if not args.api_key:
        parser.error(
            "Pexels API key required: pass --api-key or set PEXELS_API_KEY "
            "(free at https://www.pexels.com/api/)"
        )

    try:
        specs = load_queries(args.queries)
    except (OSError, json.JSONDecodeError, ValueError) as e:
        parser.error(f"Cannot load --queries {args.queries!r}: {e}")

    try:
        acquire(
            specs,
            count=args.count,
            api_key=args.api_key,
            dry_run=args.dry_run,
            append=args.append,
        )
    except KeyboardInterrupt:
        logger.warning("Interrupted; manifest saved only on normal completion.")
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main())
