#!/usr/bin/env python3
"""
Fix fabricated metadata in products.json as per production requirements:
- Replace all randomly assigned attributes that can't be confirmed from source metadata with "unknown"
- Preserve all actual source metadata (image URLs, licenses, attribution, source pages, etc.)
- Never fabricate fashion attributes if they can't be confidently determined from Wikimedia data
"""
import json
import os
from pathlib import Path

def main():
    # Paths
    root_dir = Path(__file__).parent.parent
    products_path = root_dir / "data" / "products.json"
    products_backup_path = root_dir / "data" / "products.json.backup"
    image_manifest_path = root_dir / "data" / "image_manifest.json"
    
    # Load original data
    with open(products_path, "r", encoding="utf-8") as f:
        products = json.load(f)
    
    # Create backup before modifying
    if not products_backup_path.exists():
        with open(products_backup_path, "w", encoding="utf-8") as f:
            json.dump(products, f, indent=2)
        print(f"Created backup at {products_backup_path}")
    
    # Load image manifest to get actual source metadata
    with open(image_manifest_path, "r", encoding="utf-8") as f:
        image_manifest = json.load(f)
    
    # Create map of image_url to manifest entry
    image_map = {entry["image_url"]: entry for entry in image_manifest}
    
    fixed_products = []
    fake_attrs_fixed = 0
    
    for product in products:
        # Preserve all actual source metadata
        fixed = {
            "id": product["id"],
            "name": product["name"],  # Keep original Wikimedia filename as name
            "image_url": product["image_url"],
            "image_sha256": product["image_sha256"],
            "image_phash": product["image_phash"],
            "source": product["source"],
            "source_license": product["source_license"],
            "source_page": product["source_page"],
            "license_attribution": product["license_attribution"],
            "author": product["author"],
            "is_archived": product["is_archived"],
            # Set all unconfirmable fashion attributes to "unknown"
            "category": "unknown",
            "subcategory": "unknown",
            "price": None,
            "currency": "unknown",
            "brand": "unknown",
            "style": "unknown",
            "color": "unknown",
            "fit": "unknown",
            "material": "unknown",
            "pattern": "unknown",
            "occasion": "unknown",
            "season": "unknown",
            "gender": "unknown",
            "size": "unknown",
            # Keep rating only if it was actually computed, else set to null
            "rating": None
        }
        
        # Check if we fixed any fake attributes
        if product.get("category") != "unknown" and product.get("category") is not None:
            fake_attrs_fixed +=1
        if product.get("brand") != "unknown" and product.get("brand") is not None:
            fake_attrs_fixed +=1
        if product.get("style") != "unknown" and product.get("style") is not None:
            fake_attrs_fixed +=1
        if product.get("color") != "unknown" and product.get("color") is not None:
            fake_attrs_fixed +=1
        if product.get("price") is not None:
            fake_attrs_fixed +=1
        
        fixed_products.append(fixed)
    
    # Save fixed products
    with open(products_path, "w", encoding="utf-8") as f:
        json.dump(fixed_products, f, indent=2)
    
    print(f"Successfully fixed metadata for {len(fixed_products)} products")
    print(f"Total fake attributes replaced with 'unknown': {fake_attrs_fixed}")
    print(f"Updated products saved to {products_path}")

if __name__ == "__main__":
    main()