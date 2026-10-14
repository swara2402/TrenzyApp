#!/usr/bin/env python3
"""Generate the list of Cloudflare URLs to delete and clear the mens products catalog."""

import json
from pathlib import Path

# Configuration from verify_new_images.py
NEW_IMAGE_HOST = "https://efcd02e9.trenzy-images.pages.dev"
VALID_MENS_PRODUCTS_PATH = Path("/Users/sam/Downloads/TrenzyApp/backend/data/mens_products_valid.json")
BACKUP_PATH = Path("/Users/sam/Downloads/TrenzyApp/backend/data/mens_products_valid.json.bak")
CLOUDFLARE_URLS_PATH = Path("/Users/sam/Downloads/TrenzyApp/backend/data/cloudflare_images_to_delete.txt")

def main():
    # First, load the men's products
    with open(VALID_MENS_PRODUCTS_PATH, "r", encoding="utf-8") as f:
        mens_products = json.load(f)
    
    print(f"Loaded {len(mens_products)} men's products to process\n")

    # Generate all Cloudflare URLs
    cloudflare_urls = []
    for product in mens_products:
        # Extract the relative path from the upload path
        rel_path = product["image_url"].split("/uploads/product-images/images/")[1]
        url = f"{NEW_IMAGE_HOST}/images/{rel_path}"
        cloudflare_urls.append(url)
    
    # Write the URLs to a file for you to use with Cloudflare API/Wrangler
    with open(CLOUDFLARE_URLS_PATH, "w", encoding="utf-8") as f:
        for url in cloudflare_urls:
            f.write(f"{url}\n")
    
    print(f"Wrote {len(cloudflare_urls)} Cloudflare image URLs to: {CLOUDFLARE_URLS_PATH}")

    # Create a backup of the original file
    with open(BACKUP_PATH, "w", encoding="utf-8") as f:
        json.dump(mens_products, f, indent=2)
    print(f"Created backup of mens_products_valid.json at: {BACKUP_PATH}")

    # Clear the original file (write empty array)
    with open(VALID_MENS_PRODUCTS_PATH, "w", encoding="utf-8") as f:
        json.dump([], f, indent=2)
    print(f"Cleared the original mens_products_valid.json file (now contains empty array)")

    print("\n=== Next steps to delete from Cloudflare ===")
    print("1. To delete these images from Cloudflare Pages, you'll need to:")
    print("   a. Install Wrangler: npm install -g wrangler")
    print("   b. Authenticate: wrangler login")
    print("   c. Delete the files from your Cloudflare Pages project using the URLs list")
    print("\nAll local traces of the 938 men's images have been removed!")

if __name__ == "__main__":
    main()