"""Replace recycled catalog image URLs with licensed Wikimedia Commons images.

Usage:
    python -m app.scripts.import_wikimedia_fashion_images

The importer only accepts distinct raster files with explicit CC BY, CC BY-SA,
CC0, or Public Domain metadata. It writes the selected source records to a
manifest before updating products.json so the catalog can be audited later.
"""

from __future__ import annotations

import json
import sys
import time
from pathlib import Path
from typing import Any

import certifi
import httpx
from ..ai.services.image_download_service import get_image_download_service


API_URL = "https://commons.wikimedia.org/w/api.php"
CATALOG_PATH = Path(__file__).resolve().parents[2] / "data" / "products.json"
MANIFEST_PATH = Path(__file__).resolve().parents[2] / "data" / "wikimedia_fashion_manifest.json"
CATEGORY_TITLES = ("Clothing", "Fashion", "Fashion design", "Garments", "Textiles")
ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp"}
ALLOWED_LICENSE_PREFIXES = ("cc by", "cc0", "public domain")


def metadata_value(metadata: dict[str, Any], key: str) -> str:
    return str(metadata.get(key, {}).get("value", "")).strip()


def collect_images(target_count: int) -> list[dict[str, str]]:
    images: list[dict[str, str]] = []
    seen_titles: set[str] = set()
    
    # Use canonical service for rate limiting and backoff logic
    image_downloader = get_image_download_service()

    with httpx.Client(timeout=30, verify=certifi.where(), headers={"User-Agent": image_downloader.user_agent}) as client:
        for category_title in CATEGORY_TITLES:
            continue_params: dict[str, str] = {}
            while len(images) < target_count:
                params: dict[str, Any] = {
                    "action": "query",
                    "generator": "categorymembers",
                    "gcmtitle": f"Category:{category_title}",
                    "gcmtype": "file",
                    "gcmlimit": "250",
                    "prop": "imageinfo",
                    "iiprop": "url|mime|extmetadata|descriptionurl",
                    "iiurlwidth": "1200",
                    "format": "json",
                    "formatversion": "2",
                    **continue_params,
                }
                for attempt in range(4):
                    response = client.get(API_URL, params=params)
                    if response.status_code != 429:
                        break
                    # Use canonical service's backoff logic for 429 handling
                    retry_after = int(response.headers.get("Retry-After", 0))
                    image_downloader._handle_rate_limit(retry_after, attempt)
                response.raise_for_status()
                payload = response.json()

                for page in payload.get("query", {}).get("pages", []):
                    title = page.get("title", "")
                    info = (page.get("imageinfo") or [{}])[0]
                    metadata = info.get("extmetadata", {})
                    mime = info.get("mime", "")
                    license_name = metadata_value(metadata, "LicenseShortName")
                    image_url = info.get("thumburl") or info.get("url")

                    if (
                        not title
                        or title in seen_titles
                        or mime not in ALLOWED_MIME_TYPES
                        or not image_url
                        or not license_name.lower().startswith(ALLOWED_LICENSE_PREFIXES)
                    ):
                        continue

                    seen_titles.add(title)
                    images.append(
                        {
                            "title": title,
                            "image_url": image_url,
                            "source": "Wikimedia Commons",
                            "source_license": license_name,
                            "source_url": info.get("descriptionurl", ""),
                            "artist": metadata_value(metadata, "Artist"),
                        }
                    )
                    if len(images) >= target_count:
                        break

                next_page = payload.get("continue")
                if not next_page:
                    break
                continue_params = {
                    key: str(value)
                    for key, value in next_page.items()
                    if key != "continue"
                }

            if len(images) >= target_count:
                break

    if len(images) < target_count:
        raise RuntimeError(
            f"Wikimedia Commons returned only {len(images)} usable distinct images; "
            f"{target_count} are required."
        )
    return images


def update_catalog(products: list[dict[str, Any]], images: list[dict[str, str]]) -> None:
    if len(products) != len(images):
        raise ValueError(f"Catalog has {len(products)} products but received {len(images)} images")

    for product, image in zip(products, images):
        product["image_url"] = image["image_url"]
        product["source"] = image["source"]
        product["source_license"] = image["source_license"]


def main() -> None:
    import argparse
    parser = argparse.ArgumentParser(description="Import unique Wikimedia Commons fashion images for catalog products")
    parser.add_argument("--target-count", type=int, default=500, help="Number of products to generate (default: 500)")
    args = parser.parse_args()
    
    # Get canonical image download service
    image_downloader = get_image_download_service()
    
    # First generate a clean catalog of target_count products with unique metadata
    from seed_100_legal_products import generate_additional_products
    clean_products = generate_additional_products(current_count=0, target_count=args.target_count, existing_products=None)
    
    # Collect exactly target_count unique, licensed images from Wikimedia Commons
    print(f"Collecting {args.target_count} unique, licensed Wikimedia Commons images...")
    images = collect_images(args.target_count)
    
    # Update catalog with unique images
    update_catalog(clean_products, images)
    
    # Download all images using canonical ImageDownloadService (enforces rate limiting, caching, validation)
    print(f"\nDownloading and validating images using canonical ImageDownloadService...")
    CACHE_DIR = Path(__file__).resolve().parents[2] / "data" / "image_cache"
    CACHE_DIR.mkdir(exist_ok=True, parents=True)
    
    success_count = 0
    cache_hit_count = 0
    failure_count = 0
    
    for idx, image in enumerate(images, 1):
        image_filename = f"{image['title'].replace(' ', '_').replace('/', '_')}"
        dest_path = CACHE_DIR / image_filename
        
        # Use canonical service to download/validate image
        success, status, _ = image_downloader.download_to_file(image["image_url"], str(dest_path))
        
        if success:
            if status == "CACHE_HIT":
                cache_hit_count += 1
            else:
                success_count += 1
            print(f"  [{idx}/{len(images)}] {status}: {image['title']}")
            # Add local path to image manifest
            image["local_path"] = str(dest_path.relative_to(Path(__file__).resolve().parents[2]))
        else:
            failure_count += 1
            print(f"  [{idx}/{len(images)}] ❌ {status}: {image['title']}")
            # Hard fail on critical failures (CI/CD compatible)
            if status in ["PERMANENT_FAILURE", "INVALID_IMAGE"]:
                print(f"🚨 Critical failure: Cannot continue with invalid image {image['title']}")
                sys.exit(1)
    
    # Save the clean catalog and manifest with local paths
    MANIFEST_PATH.write_text(json.dumps(images, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    CATALOG_PATH.write_text(json.dumps(clean_products, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    
    print(f"\n✅ Successfully created high-quality seed catalog:")
    print(f"   - Total products: {len(clean_products)}")
    print(f"   - Unique image URLs: {len(set(p['image_url'] for p in clean_products))}")
    print(f"   - Newly downloaded: {success_count}")
    print(f"   - Cache hits (reused): {cache_hit_count}")
    if failure_count > 0:
        print(f"   - Failed downloads: {failure_count} (temporary, will retry on next run)")
    print(f"   - Catalog saved to: {CATALOG_PATH}")
    print(f"   - Image manifest saved to: {MANIFEST_PATH}")


if __name__ == "__main__":
    main()