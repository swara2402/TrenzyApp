#!/usr/bin/env python3
"""Verify EVERY image URL in the catalog to ensure they return 200 OK."""
import json
import requests
import os
from pathlib import Path

JSON_PATH = Path("/Users/sam/Downloads/TrenzyApp/backend/data/products.json")
STABLE_IMAGE_HOST = "https://e507cfa3.trenzy-images.pages.dev"
NEW_IMAGE_HOST = "https://efcd02e9.trenzy-images.pages.dev"

def main():
    with open(JSON_PATH, "r", encoding="utf-8") as f:
        all_products = json.load(f)
    
    print(f"🔍 Verifying {len(all_products)} total product images...\n")
    failed = []
    success = 0
    original_failed = 0
    mens_failed = 0
    
    for p in all_products:
        image_path = p.get("image_url", "")
        if not image_path:
            failed.append(f"{p['id']}: No image URL found")
            if p['id'].startswith('trenzy_'):
                original_failed +=1
            else:
                mens_failed +=1
            continue
            
        # Extract the relative path after /uploads/product-images/images/
        if image_path.startswith("/uploads/product-images/images/"):
            rel_path = image_path[len("/uploads/product-images/images/"):]
        else:
            rel_path = image_path.lstrip("/")
        
        # Use appropriate host based on ID
        if p['id'].startswith('trenzy_'):
            full_url = f"{STABLE_IMAGE_HOST}/images/{rel_path}"
        else:
            full_url = f"{NEW_IMAGE_HOST}/images/{rel_path}"
            
        try:
            response = requests.get(full_url, timeout=15)
            if response.status_code == 200:
                success +=1
            else:
                failed.append(f"{p['id']}: HTTP {response.status_code} - {full_url}")
                if p['id'].startswith('trenzy_'):
                    original_failed +=1
                else:
                    mens_failed +=1
        except Exception as e:
            failed.append(f"{p['id']}: ERROR - {str(e)} | URL: {full_url}")
            if p['id'].startswith('trenzy_'):
                original_failed +=1
            else:
                mens_failed +=1
    
    # Summary
    print("📊 Full verification summary:")
    print(f"   ✅ Successful: {success}")
    print(f"   ❌ Failed: {len(failed)}")
    print(f"      Original products failed: {original_failed}")
    print(f"      Men's products failed: {mens_failed}")
    print(f"   TOTAL: {success + len(failed)}")
    
    if failed:
        print("\n❌ Failed URLs:")
        for f in failed[:20]: # Show first 20 failures
            print(f"   - {f}")
        if len(failed) > 20:
            print(f"   ... and {len(failed)-20} more")
    else:
        print("\n🎉 ALL IMAGES ARE ACCESSIBLE! 100% success rate!")

if __name__ == "__main__":
    main()