#!/usr/bin/env python3
"""Process your Google Drive images for Trenzy:
- Computes SHA-256 and pHash for all images
- Updates products.json with your local image URLs
- Adds gallery images to products
- Creates a backup before modifying anything

Usage:
    cd backend
    python scripts/process_google_drive_images.py --images-dir ./uploads/product-images
"""

from __future__ import annotations

import argparse
import json
import hashlib
import imagehash
from PIL import Image
from pathlib import Path
import shutil
from typing import Any, Dict, List

BACKEND_DIR = Path(__file__).resolve().parents[1]
PRODUCTS_JSON = BACKEND_DIR / "data" / "products.json"
PRODUCTS_BACKUP = BACKEND_DIR / "data" / "products.json.google_drive_backup"

def compute_sha256(file_path: Path) -> str:
    """Compute SHA-256 hash of a file."""
    hash_sha256 = hashlib.sha256()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_sha256.update(chunk)
    return hash_sha256.hexdigest()

def compute_phash(file_path: Path) -> str:
    """Compute perceptual hash (pHash) of an image."""
    with Image.open(file_path) as img:
        return str(imagehash.phash(img))

def main():
    parser = argparse.ArgumentParser(description="Process Google Drive images for Trenzy")
    parser.add_argument("--images-dir", required=True, help="Directory containing your images")
    parser.add_argument("--dry-run", action="store_true", help="Only scan, don't update products.json")
    args = parser.parse_args()

    images_dir = Path(args.images_dir)
    if not images_dir.exists():
        print(f"Error: Images directory {images_dir} does not exist!")
        sys.exit(1)

    # Load products
    with open(PRODUCTS_JSON, "r", encoding="utf-8") as f:
        products = json.load(f)
    print(f"Loaded {len(products)} products from catalog")

    # Scan all images
    image_files = list(images_dir.glob("*.jpg")) + list(images_dir.glob("*.jpeg")) + list(images_dir.glob("*.png"))
    print(f"Found {len(image_files)} images in {images_dir}")

    # Group images by product ID - your images are TRZ-0001.jpg, TRZ-0002.jpg, etc.
    # Perfectly matches: TRZ-0001 → trenzy_0001, TRZ-0062 → trenzy_0062
    product_images: Dict[str, Dict[str, List[Path]]] = {}
    
    for img_path in image_files:
        filename = img_path.name
        if "TRZ-" in filename:
            # Extract number from TRZ-0001.jpg → 0001
            import re
            match = re.search(r'TRZ-(\d+)', filename)
            if match:
                num = match.group(1)
                # Your files are sequential: TRZ-0001, TRZ-0002, ..., TRZ-2000
                # 1:1 mapping for 2000 separate single-image products
                product_num = int(num) - 1  # 1→0, 2→1, ..., 2000→1999
                if product_num >= 2000:
                    continue  # Skip images beyond our 2000 product limit
                product_num_str = f"{product_num + 1:04d}"  # 0→0001, 1→0002
                product_id = f"trenzy_{product_num_str}"
                image_index = 0  # Always main image for single-image products
                
                if product_id not in product_images:
                    product_images[product_id] = {"main": [], "gallery": []}
                
                if image_index == 0:
                    product_images[product_id]["main"].append(img_path)
                else:
                    product_images[product_id]["gallery"].append(img_path)

    print(f"\nMapped images to {len(product_images)} products:")
    for pid, imgs in product_images.items():
        print(f"  {pid}: {len(imgs['main'])} main, {len(imgs['gallery'])} gallery images")

    if args.dry_run:
        print("\nDry run complete - no changes made")
        return

    # Create backup
    if not PRODUCTS_BACKUP.exists():
        shutil.copy(PRODUCTS_JSON, PRODUCTS_BACKUP)
        print(f"\nCreated backup at {PRODUCTS_BACKUP}")

    # Update products with your images
    updated_count = 0
    for product in products:
        pid = product["id"]
        if pid in product_images:
            # Ensure galleryImages field exists
            if "galleryImages" not in product:
                product["galleryImages"] = []
                
            # Set main image
            if product_images[pid]["main"]:
                main_img = product_images[pid]["main"][0]
                main_url = f"/uploads/product-images/images/{main_img.name}"
                product["image_url"] = main_url
                product["mainImage"] = main_url
                product["image_sha256"] = compute_sha256(main_img)
                product["image_phash"] = compute_phash(main_img)
                product["source"] = "Google Drive (User Created)"
                product["source_license"] = "Proprietary"

            # Set gallery images
            gallery_urls = []
            for gallery_img in product_images[pid]["gallery"]:
                gallery_urls.append(f"/uploads/product-images/images/{gallery_img.name}")
            if gallery_urls:
                product["galleryImages"] = gallery_urls

            updated_count += 1

    # Save updated products.json
    with open(PRODUCTS_JSON, "w", encoding="utf-8") as f:
        json.dump(products, f, indent=2)

    print(f"\n✅ Successfully updated {updated_count} products with your images!")
    print(f"📝 Original catalog backed up to: {PRODUCTS_BACKUP}")

if __name__ == "__main__":
    main()