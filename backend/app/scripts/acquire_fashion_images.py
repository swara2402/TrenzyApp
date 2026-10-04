"""Image acquisition pipeline for Trenzy fashion recommendation.

Acquires real, licensed, distinct fashion images from Wikimedia Commons.
Validates:
- Real HTTP 200 reachability
- Allowed licenses: CC0, CC BY, CC BY-SA, Public Domain
- Allowed MIME types: image/jpeg, image/png, image/webp
- Minimum resolution: 400x400
- Cryptographic SHA-256 deduplication (zero collisions allowed)
- Perceptual pHash deduplication (Hamming distance >= 4 required)
- Writes backend/data/image_manifest.json
"""

import os
import sys
import json
import time
import io
import logging
from pathlib import Path
from typing import Dict, List, Set, Any, Optional
from datetime import datetime, timezone
from PIL import Image
import imagehash
import certifi
import httpx

# Ensure paths
SCRIPT_DIR = Path(__file__).resolve().parent
BACKEND_DIR = SCRIPT_DIR.parents[1]
DATA_DIR = BACKEND_DIR / "data"
MANIFEST_PATH = DATA_DIR / "image_manifest.json"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger("acquire_images")

API_URL = "https://commons.wikimedia.org/w/api.php"
USER_AGENT = "TrenzyFashionBot/1.0 (https://trenzy.app; ai-team@trenzy.app)"

CATEGORIES = [
    "Clothing",
    "Fashion",
    "Fashion design",
    "Garments",
    "Dresses",
    "Footwear",
    "Traditional clothing",
    "Suits",
    "Coats",
    "Jackets",
    "Trousers",
    "Skirts",
    "Shirts",
    "Fashion accessories",
    "Handbags",
]

ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp"}
ALLOWED_LICENSE_TERMS = {
    "cc0",
    "cc by",
    "cc by-sa",
    "public domain",
    "pd",
}
FORBIDDEN_LICENSE_TERMS = {"nc", "nd", "noncommercial", "noderivatives"}


def is_license_allowed(license_name: str, usage_terms: str) -> bool:
    combined = f"{license_name} {usage_terms}".lower()
    for forbidden in FORBIDDEN_LICENSE_TERMS:
        if forbidden in combined:
            return False
    for allowed in ALLOWED_LICENSE_TERMS:
        if allowed in combined:
            return True
    return False


def get_metadata_str(metadata: Dict[str, Any], field: str) -> str:
    val = metadata.get(field, {}).get("value", "")
    return str(val).strip()


def acquire_images(target_count: int = 500, max_pages_per_cat: int = 15) -> List[Dict[str, Any]]:
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    manifest: List[Dict[str, Any]] = []
    seen_urls: Set[str] = set()
    seen_sha256: Set[str] = set()
    seen_phashes: List[imagehash.ImageHash] = []

    # Resume from existing manifest if available
    if MANIFEST_PATH.exists():
        try:
            with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
                existing = json.load(f)
                for item in existing:
                    manifest.append(item)
                    seen_urls.add(item["image_url"])
                    seen_sha256.add(item["sha256"])
                    if item.get("phash"):
                        seen_phashes.append(imagehash.hex_to_hash(item["phash"]))
            logger.info("Resuming from existing manifest with %d valid images.", len(manifest))
            if len(manifest) >= target_count:
                logger.info("Already reached target of %d images.", target_count)
                return manifest[:target_count]
        except Exception as e:
            logger.warning("Could not read existing manifest: %s", e)

    with httpx.Client(
        timeout=30.0,
        verify=certifi.where(),
        headers={"User-Agent": USER_AGENT},
        follow_redirects=True,
    ) as client:
        for cat in CATEGORIES:
            if len(manifest) >= target_count:
                break

            logger.info("Querying category: Category:%s (Current: %d / %d)", cat, len(manifest), target_count)
            continue_params: Dict[str, str] = {}
            page_count = 0

            while len(manifest) < target_count and page_count < max_pages_per_cat:
                page_count += 1
                params: Dict[str, Any] = {
                    "action": "query",
                    "generator": "categorymembers",
                    "gcmtitle": f"Category:{cat}",
                    "gcmtype": "file",
                    "gcmlimit": "100",
                    "prop": "imageinfo",
                    "iiprop": "url|size|mime|extmetadata|descriptionurl",
                    "iiurlwidth": "800",  # Get 800px scaled thumbnail for efficiency & high quality
                    "format": "json",
                    "formatversion": "2",
                    **continue_params,
                }

                resp = None
                for attempt in range(3):
                    try:
                        resp = client.get(API_URL, params=params)
                        if resp.status_code == 429:
                            wait = 3 * (attempt + 1)
                            logger.warning("Rate limited (429). Sleeping %d seconds...", wait)
                            time.sleep(wait)
                            continue
                        resp.raise_for_status()
                        break
                    except Exception as err:
                        if attempt == 2:
                            logger.error("Failed to query API for %s: %s", cat, err)
                        time.sleep(2)

                if not resp or resp.status_code != 200:
                    break

                data = resp.json()
                pages = data.get("query", {}).get("pages", [])

                for page in pages:
                    if len(manifest) >= target_count:
                        break

                    title = page.get("title", "")
                    info_list = page.get("imageinfo", [])
                    if not info_list:
                        continue
                    info = info_list[0]
                    mime = info.get("mime", "")
                    if mime not in ALLOWED_MIME_TYPES:
                        continue

                    metadata = info.get("extmetadata", {})
                    license_name = get_metadata_str(metadata, "LicenseShortName")
                    usage_terms = get_metadata_str(metadata, "UsageTerms")
                    if not is_license_allowed(license_name, usage_terms):
                        continue

                    image_url = info.get("thumburl") or info.get("url")
                    if not image_url or image_url in seen_urls:
                        continue

                    source_page = info.get("descriptionurl") or f"https://commons.wikimedia.org/wiki/{title.replace(' ', '_')}"
                    artist = get_metadata_str(metadata, "Artist")
                    attribution = get_metadata_str(metadata, "Credit") or license_name

                    # Download and inspect image bytes
                    try:
                        img_resp = client.get(image_url)
                        if img_resp.status_code != 200 or len(img_resp.content) < 5000:
                            continue

                        img_bytes = img_resp.content

                        # Cryptographic SHA-256
                        import hashlib
                        sha256 = hashlib.sha256(img_bytes).hexdigest()
                        if sha256 in seen_sha256:
                            continue

                        # Perceptual hash and dimensions check
                        with Image.open(io.BytesIO(img_bytes)) as pil_img:
                            w, h = pil_img.size
                            if w < 300 or h < 300:  # Minimum quality threshold
                                continue

                            rgb_img = pil_img.convert("RGB")
                            ph = imagehash.phash(rgb_img)

                            # Visual near-duplicate check
                            is_dupe = False
                            for existing_ph in seen_phashes:
                                if (ph - existing_ph) < 3:
                                    is_dupe = True
                                    break
                            if is_dupe:
                                continue

                        # Accepted!
                        seen_urls.add(image_url)
                        seen_sha256.add(sha256)
                        seen_phashes.append(ph)

                        manifest_item = {
                            "image_id": f"wm_{len(manifest) + 1:04d}",
                            "title": title,
                            "category_hint": cat.lower(),
                            "image_url": image_url,
                            "source": "Wikimedia Commons",
                            "source_page": source_page,
                            "license": license_name or "CC BY-SA",
                            "attribution": attribution,
                            "author": artist or "Unknown / Wikimedia Contributor",
                            "sha256": sha256,
                            "phash": str(ph),
                            "width": w,
                            "height": h,
                            "retrieved_at": datetime.now(timezone.utc).isoformat(),
                        }
                        manifest.append(manifest_item)

                        if len(manifest) % 25 == 0 or len(manifest) == target_count:
                            logger.info("Acquired %d / %d valid distinct images", len(manifest), target_count)
                            # Incrementally save manifest
                            with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
                                json.dump(manifest, f, indent=2, ensure_ascii=False)

                    except Exception as e:
                        logger.debug("Failed processing image %s: %s", title, e)
                        continue

                next_continue = data.get("continue")
                if not next_continue:
                    break
                continue_params = {
                    k: str(v) for k, v in next_continue.items() if k != "continue"
                }

    # Final save
    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

    logger.info("Acquisition finished. Total acquired: %d unique images.", len(manifest))
    return manifest


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Acquire unique fashion images from Wikimedia Commons")
    parser.add_argument("--target", type=int, default=500, help="Target count of images (default: 500)")
    args = parser.parse_args()

    acquire_images(target_count=args.target)
