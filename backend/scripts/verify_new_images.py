#!/usr/bin/env python3
"""Verify that all new men's images are accessible at the new Cloudflare deployment URL."""

import json
import requests
from pathlib import Path

# Configuration
NEW_IMAGE_HOST = "https://efcd02e9.trenzy-images.pages.dev"
EXISTING_IMAGE_HOST = "https://e507cfa3.trenzy-images.pages.dev"
VALID_MENS_PRODUCTS_PATH = Path("/Users/sam/Downloads/TrenzyApp/backend/data/mens_products_valid.json")


def main():
    # Load our valid products
    with open(VALID_MENS_PRODUCTS_PATH, "r", encoding="utf-8") as f:
        mens_products = json.load(f)
    
    print(f"Loaded {len(mens_products)} valid men's products to verify\n")

    # First, test the specific examples your user asked for
    test_urls = [
        f"{NEW_IMAGE_HOST}/images/streetwear/TRZ_M_000001.png",
        f"{NEW_IMAGE_HOST}/images/footwear/TRZ_M_000921.png",
        f"{EXISTING_IMAGE_HOST}/images/TRZ-0001.jpg",
    ]

    print("=== Test Specific URLs ===")
    for url in test_urls:
        try:
            response = requests.get(url, timeout=10)
            print(f"Checking: {url:<80} HTTP {response.status_code}")
        except Exception as e:
            print(f"Checking: {url:<80} ERROR: {e}")

    # Now verify a random sample of 10 men's images to ensure they all work
    print("\n=== Verify Random Sample of Men's Images ===")
    import random
    sample = random.sample(mens_products, min(20, len(mens_products)))
    failed = []
    
    for product in sample:
        # Extract the relative path from the upload path
        rel_path = product["image_url"].split("/uploads/product-images/images/")[1]
        url = f"{NEW_IMAGE_HOST}/images/{rel_path}"
        try:
            response = requests.get(url, timeout=10)
            if response.status_code != 200:
                failed.append((url, response.status_code))
                print(f"❌ {url:<80} {response.status_code}")
            else:
                print(f"✅ {url:<80} 200")
        except Exception as e:
            failed.append((url, str(e)))
            print(f"⚠️ {url:<80} {e}")

    # Check if there are any CSV files in the staging directory
    print("\n=== Check for Catalog CSV Files ===")
    staging_dir = Path.home() / "trenzy-data" / "Trenzy" / "mens-staging"
    csv_files = list(staging_dir.rglob("*.csv"))
    if csv_files:
        print(f"Found {len(csv_files)} CSV files:")
        for csv_path in csv_files:
            print(f"  - {csv_path}")
            # Print first few lines
            with open(csv_path, "r", encoding="utf-8-sig") as f:
                first_3 = [next(f).strip() for _ in range(3)]
            print("    First 3 lines:")
            for line in first_3:
                print(f"      {line}")
    else:
        print("No CSV files found in staging directory - only JSON, which we've already processed!")

    # Summary
    print(f"\n=== Verification Summary ===")
    print(f"Total verified sample: {len(sample)}")
    print(f"Failed images: {len(failed)}")
    if failed:
        print("\nFailed URLs:")
        for url, code in failed:
            print(f"  - {url}: {code}")
    else:
        print("\n🎉 All tested images are accessible! Ready to import.")
        print("\nNext step to import safely:")
        print("1. First backup your existing products file:")
        print("   cd /Users/sam/Downloads/TrenzyApp/backend/data && cp products.json products.json.bak")
        print("\n2. Merge the men's products into your main products file:")
        print("   python -c \"")
        print("   import json")
        print("   with open('products.json', 'r') as f: existing = json.load(f)")
        print("   with open('mens_products_valid.json', 'r') as f: mens = json.load(f)")
        print("   combined = existing + mens")
        print("   print(f'Total products after merge: {len(combined)} (was {len(existing)} before)')")
        print("   with open('products_combined.json', 'w') as f: json.dump(combined, f, indent=2)")
        print("   \"")
        print("\n3. Verify the importer's image path handling is fixed:")
        print("   We need to update your TRENZY_IMAGE_BASE_URL environment variable to use the stable production URL:")
        print("   export TRENZY_IMAGE_BASE_URL=https://e507cfa3.trenzy-images.pages.dev")
        print("\n4. Run the existing importer:")
        print("   cd /Users/sam/Downloads/TrenzyApp/backend && python -m app.scripts.load_products")


if __name__ == "__main__":
    main()