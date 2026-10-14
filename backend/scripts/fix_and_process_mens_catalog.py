#!/usr/bin/env python3
"""Fix and process the malformed men's catalog JSON."""

import json
import os
from pathlib import Path

# Configuration
IMAGE_HOST_BASE = "https://e507cfa3.trenzy-images.pages.dev"
EXISTING_IMAGE_DIR = Path.home() / "trenzy-images-site" / "images"
MENS_CATALOG_PATH = Path.home() / "trenzy-data" / "Trenzy" / "mens-staging" / "products.json"
FIXED_JSON_PATH = Path.home() / "trenzy-data" / "Trenzy" / "mens-staging" / "products_fixed.json"
OUTPUT_PATH = Path("/Users/sam/Downloads/TrenzyApp/backend/data/mens_products_valid.json")
EXISTING_PRODUCTS_PATH = Path("/Users/sam/Downloads/TrenzyApp/backend/data/products.json")


def fix_malformed_json(input_path: Path, output_path: Path):
    """Fix the malformed JSON by adding missing commas and wrapping in array."""
    with open(input_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # First, make sure we have the opening [
    if not content.strip().startswith("["):
        content = "[\n" + content
    # Make sure we have closing ]
    if not content.strip().endswith("]"):
        content = content.rstrip() + "\n]"
    
    # Add commas between objects: find "}  {" patterns and add comma
    import re
    # Fix "} {" patterns with any whitespace
    content = re.sub(r'}\s*{', '},\n  {', content)
    # Fix lines that end with a quote but don't have a comma before the next key
    content = re.sub(r'(".*")\n\s*(".*"):', r'\1,\n  \2:', content)
    
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(content)
    
    print(f"Fixed JSON saved to {output_path}")
    
    # Try to load it to verify
    try:
        with open(output_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        print(f"✅ Fixed JSON is valid! Loaded {len(data)} products")
        return data
    except json.JSONDecodeError as e:
        print(f"❌ JSON still invalid: {e}")
        print(f"Line: {e.lineno}, Column: {e.colno}")
        # Show the problematic area
        lines = content.split('\n')
        for i in range(max(0, e.lineno-5), min(len(lines), e.lineno+5)):
            print(f"{i+1:4d}: {lines[i]}")
        return None


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
    # First fix the JSON
    mens_products = fix_malformed_json(MENS_CATALOG_PATH, FIXED_JSON_PATH)
    if not mens_products:
        return

    # Load existing products to check for duplicates
    existing_ids = set()
    if EXISTING_PRODUCTS_PATH.exists():
        with open(EXISTING_PRODUCTS_PATH, "r", encoding="utf-8") as f:
            existing_products = json.load(f)
            for p in existing_products:
                existing_ids.add(p["id"])
    print(f"Found {len(existing_ids)} existing products in database")

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
            "price": float(product["price"]) if product.get("price") and str(product["price"]).strip() else None,
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
    print(f"\nNext steps:")
    print(f"1. Deploy the updated images to Cloudflare Pages:")
    print(f"   cd ~/trenzy-images-site && wrangler pages deploy . --project-name trenzy-images")
    print(f"\n2. Verify all image URLs return 200 OK after deployment:")
    print(f"   cd /Users/sam/Downloads/TrenzyApp/backend && python -c \"")
    print(f"   import json, requests")
    print(f"   with open('data/mens_products_valid.json', 'r') as f: products = json.load(f)")
    print(f"   base = '{IMAGE_HOST_BASE}'")
    print(f'   failed = [p[\"image_url\"].split(\"/uploads/product-images/images/\")[1] for p in products if requests.get(base + \"/images/\" + p[\"image_url\"].split(\"/uploads/product-images/images/\")[1], timeout=5).status_code != 200]')
    print(f"   print(f'Failed images: {len(failed)}')")
    print(f"   if failed: print('First 10 failures:', failed[:10])")
    print(f"   \"")
    print(f"\n3. Merge with existing products and import:")
    print(f"   cd /Users/sam/Downloads/TrenzyApp/backend/data")
    print(f"   cp products.json products.json.bak  # Backup first!")
    print(f"   python -c \"")
    print(f"   import json")
    print(f"   with open('products.json', 'r') as f: existing = json.load(f)")
    print(f"   with open('mens_products_valid.json', 'r') as f: mens = json.load(f)")
    print(f"   combined = existing + mens")
    print(f"   with open('products_combined.json', 'w') as f: json.dump(combined, f, indent=2)")
    print(f"   print(f'Combined {len(combined)} products total')")
    print(f"   \"")
    print(f"\n4. Run the existing importer to load everything:")
    print(f"   cd /Users/sam/Downloads/TrenzyApp/backend && python -m app.scripts.load_products")


if __name__ == "__main__":
    main()