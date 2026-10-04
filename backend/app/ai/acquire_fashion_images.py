# backend/app/ai/acquire_fashion_images.py

"""Simple placeholder image acquisition script.

This version does **not** call the Wikimedia Commons API. Instead it generates
`TARGET_IMAGE_COUNT` placeholder images from https://picsum.photos, which are
public domain and require no API keys.

It writes the images to ``cfg.IMAGE_STORAGE_DIR`` and creates a manifest file
``backend/exports/image_manifest.json`` with the same fields expected by later
pipeline stages.

If you later want to replace this with a real Wikimedia Commons crawler, you can
swap out the ``_download_placeholder_images`` function.
"""

import json
import os
import logging
from pathlib import Path
from typing import List

from .config import image_acquisition as cfg
from .services.image_download_service import get_image_download_service

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

def _download_placeholder_images(target: int, storage_dir: Path) -> List[dict]:
    """Download ``target`` placeholder images from picsum.photos using canonical ImageDownloadService.

    Returns a list of manifest entries containing ``filename``, ``sha256``,
    ``source_url``, ``category`` (set to ``"placeholder"``), and empty license
    fields.
    """
    image_downloader = get_image_download_service()

    manifest: List[dict] = []
    for i in range(1, target + 1):
        # Use a deterministic seed so the same run produces the same image URLs
        url = f"https://picsum.photos/seed/{i}/800/800"
        filename = f"placeholder_{i:04d}.jpg"
        dest_path = storage_dir / filename
        try:
            success, status = image_downloader.download_to_file(url, str(dest_path))
            if not success:
                logging.warning(f"Failed to download placeholder image {url}: status={status}")
                continue
            sha256 = image_downloader.compute_sha256(str(dest_path))
        except Exception as exc:
            logging.warning(f"Failed to download placeholder image {url}: {exc}")
            continue
        manifest.append({
            "filename": filename,
            "sha256": sha256,
            "source_url": url,
            "category": "placeholder",
            "license_name": "Public Domain",
            "license_url": "https://picsum.photos/",
        })
    return manifest


def main():
    target = cfg.TARGET_IMAGE_COUNT
    storage_dir = Path(cfg.IMAGE_STORAGE_DIR)
    storage_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = Path("backend/exports/image_manifest.json")
    manifest_path.parent.mkdir(parents=True, exist_ok=True)

    logging.info(f"Downloading {target} placeholder images to {storage_dir}")
    manifest = _download_placeholder_images(target, storage_dir)

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
    logging.info(f"Wrote manifest with {len(manifest)} entries to {manifest_path}")

if __name__ == "__main__":
    main()