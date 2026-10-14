#!/usr/bin/env python3
"""Safely merge the men's valid products into the existing products catalog."""

import json
from pathlib import Path
import shutil

# Paths
EXISTING_PRODUCTS = Path("/Users/sam/Downloads/TrenzyApp/backend/data/products.json")
MENS_PRODUCTS = Path("/Users/sam/Downloads/TrenzyApp/backend/data/mens_products_valid.json")
BACKUP_PATH = Path("/Users/sam/Downloads/TrenzyApp/backend/data/products.json.bak")
COMBINED_PATH = Path("/Users/sam/Downloads/TrenzyApp/backend/data/products_combined.json")


def main():
    # First create a backup
    print("📦 Creating backup of existing products...")
    shutil.copyfile(EXISTING_PRODUCTS, BACKUP_PATH)
    print(f"✅ Backup created at: {BACKUP_PATH}")

    # Load both datasets
    with open(EXISTING_PRODUCTS, "r", encoding="utf-8") as f:
        existing = json.load(f)
    
    with open(MENS_PRODUCTS, "r", encoding="utf-8") as f:
        mens = json.load(f)

    print(f"\n📊 Current stats:")
    print(f"   Existing products: {len(existing)}")
    print(f"   Men's products to add: {len(mens)}")

    # Verify no duplicate IDs (double-check safety)
    existing_ids = {p["id"] for p in existing}
    duplicates = [p["id"] for p in mens if p["id"] in existing_ids]
    
    if duplicates:
        print(f"\n⚠️ Found {len(duplicates)} duplicate IDs - these will be skipped:")
        for dup in duplicates[:10]:
            print(f"   - {dup}")
        # Filter out duplicates
        mens = [p for p in mens if p["id"] not in existing_ids]
        print(f"   Adding only {len(mens)} unique men's products")
    else:
        print("\n✅ No duplicate IDs found! All men's products are unique.")

    # Combine them
    combined = existing + mens
    print(f"\n🔗 Combined total products: {len(combined)}")

    # Save the combined file
    with open(COMBINED_PATH, "w", encoding="utf-8") as f:
        json.dump(combined, f, indent=2, ensure_ascii=False)
    print(f"✅ Combined products saved to: {COMBINED_PATH}")

    # Verify we can load it again
    with open(COMBINED_PATH, "r", encoding="utf-8") as f:
        verify = json.load(f)
    assert len(verify) == len(combined), "JSON verification failed - file corrupted!"
    print("\n✅ JSON file verified and valid!")

    # Now replace the main products.json with the combined one
    shutil.copyfile(COMBINED_PATH, EXISTING_PRODUCTS)
    print(f"✅ Main products file updated!")

    print("\n🎉 Merge complete! Ready to run the importer.")
    print("\nNext step: Run the importer with the correct environment variable:")
    print("   cd /Users/sam/Downloads/TrenzyApp/backend")
    print("   export TRENZY_IMAGE_BASE_URL=https://e507cfa3.trenzy-images.pages.dev")
    print("   python -m app.scripts.load_products")


if __name__ == "__main__":
    main()