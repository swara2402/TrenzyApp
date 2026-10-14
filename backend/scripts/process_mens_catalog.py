#!/usr/bin/env python3
"""Process men's catalog for safe import into Trenzy.

This script:
1. Reads the raw men's catalog JSON
2. Validates that each product's image actually exists
3. Converts to match the existing product schema
4. Generates a new JSON file with only valid products
5. Avoids conflicts with existing products
"""

import json
import os
from pathlib import Path
from urllib.parse import unquote

# Configuration
IMAGE_HOST_BASE = "https://e507cfa3.trenzy-images.pages.dev"
EXISTING_IMAGE_DIR = Path.home() / "trenzy-images-site" / "images"
MENS_CATALOG_PATH = Path.home() / "trenzy-data" / "Trenzy" / "mens-staging" / "products.json"
OUTPUT_PATH = Path("/Users/sam/Downloads/TrenzyApp/backend/data/mens_products_valid.json")
EXISTING_PRODUCTS_PATH = Path("/Users/sam/Downloads/TrenzyApp/backend/data/products.json")


def extract_relative_image_path(windows_path: str) -> str:
    """Extract the relative image path from the Windows path in the catalog."""
    # Windows path looks like: H:\My Drive\Trenzy\trenzy_mens_catalog_4070\images\streetwear\TRZ_M_000001.png
    # We need to get: streetwear/TRZ_M_000001.png
    parts = windows_path.replace("\\", "/").split("/")
    # Find the 'images' segment and take everything after it
    for i, part in enumerate(parts):
        if part == "images" and i + 1 < len(parts):
            return "/".join(parts[i+1:])
    return ""


def main():
    # Load existing products to check for duplicates
    existing_ids = set()
    if EXISTING_PRODUCTS_PATH.exists():
        with open(EXISTING_PRODUCTS_PATH, "r", encoding="utf-8") as f:
            existing_products = json.load(f)
            for p in existing_products:
                existing_ids.add(p["id"])
    print(f"Found {len(existing_ids)} existing products in database")

    # Load men's catalog
    with open(MENS_CATALOG_PATH, "r", encoding="utf-8") as f:
        # Fix JSON formatting (the raw file is missing commas between objects)
        content = f.read()
        # Add commas between objects if missing
        content = content.replace('}\n  {', '},\n  {')
        content = content.replace('"id": "TRZ_M_000001"\n    "name"', '"id": "TRZ_M_000001",\n    "name"')
        # Fix all similar missing commas by pattern matching
        import re
        content = re.sub(r'(".*": ".*")\n\s*(".*":)', r'\1,\n  \2', content)
        mens_products = json.loads(content)

    print(f"Loaded {len(mens_products)} total men's product records")

    # Process each product
    valid_products = []
    missing_images = []
    duplicate_ids = []

    for product in mens_products:
        product_id = product["id"]
        
        # Check for duplicates (shouldn't happen with TRZ_M_ prefix, but safe to check)
        if product_id in existing_ids:
            duplicate_ids.append(product_id)
            continue

        # Extract and verify image exists
        rel_image_path = extract_relative_image_path(product["image_path"])
        if not rel_image_path:
            missing_images.append(product_id)
            continue

        full_image_path = EXISTING_IMAGE_DIR / rel_image_path
        if not full_image_path.exists():
            missing_images.append(product_id)
            continue

        # Build the correct image URL path that matches existing format
        # Existing format: "/uploads/product-images/images/TRZ-0001.jpg"
        upload_image_path = f"/uploads/product-images/images/{rel_image_path}"
        public_image_url = f"{IMAGE_HOST_BASE}/images/{rel_image_path}"

        # Convert to match existing product schema
        valid_product = {
            "id": product_id,
            "name": product["name"],
            "image_url": upload_image_path,
            "mainImage": upload_image_path,
            "galleryImages": [],  # No gallery images for men's products yet
            "image_sha256": None,
            "image_phash": None,
            "source": "Men's Collection (Generated)",
            "source_license": "Proprietary",
            "source_page": None,
            "license_attribution": None,
            "author": "Trenzy Select",
            "is_archived": False,
            "category": product.get("category", "unknown"),
            "subcategory": product.get("subcategory", "unknown"),
            "price": float(product["price"]) if product.get("price") and product["price"].strip() else None,
            "currency": product.get("currency", "INR"),
            "brand": product.get("brand", "Trenzy Select"),
            "style": product.get("style", "unknown"),
            "color": product.get("color", "unknown"),
            "fit": product.get("fit", "unknown"),
            "material": product.get("material", "unknown"),
            "pattern": "unknown",
            "occasion": "unknown",
            "season": "all-season",
            "gender": product.get("gender", "men"),
            "size": "unknown",
            "rating": None,
            "description": product.get("description", ""),
            "available": product.get("available", True),
            "created_at": product.get("created_at")
        }

        valid_products.append(valid_product)

    # Save valid products
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(valid_products, f, indent=2, ensure_ascii=False)

    # Print summary
    print("\n=== Processing Summary ===")
    print(f"Total men's products: {len(mens_products)}")
    print(f"Valid products (with existing images): {len(valid_products)}")
    print(f"Products with missing images: {len(missing_images)}")
    print(f"Duplicate IDs found (skipped): {len(duplicate_ids)}")
    print(f"\nValid products saved to: {OUTPUT_PATH}")

    # Verify we can merge them without conflicts
    print(f"\nTo import these into your database, you can:")
    print(f"1. First verify all image URLs return 200 OK with: python -m app.scripts.verify_images --file {OUTPUT_PATH.name}")
    print(f"2. Merge with existing products (if needed): cat {EXISTING_PRODUCTS_PATH} {OUTPUT_PATH} > combined_products.json")
    print(f"3. Run the existing importer: python -m app.scripts.load_products")


if __name__ == "__main__":
    main()