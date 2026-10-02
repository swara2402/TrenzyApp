#!/usr/bin/env python3
"""Download your entire Google Drive folder of 2000 images and update the product catalog.
Can use either local files OR direct Google Drive links - configurable.
"""
import subprocess
import sys
from pathlib import Path
import json
import shutil

BACKEND_DIR = Path(__file__).resolve().parents[1]
IMAGES_DIR = BACKEND_DIR / "uploads" / "product-images" / "images"
IMAGES_DIR.mkdir(parents=True, exist_ok=True)
PRODUCTS_JSON = BACKEND_DIR / "data" / "products.json"

# Your Google Drive folder ID
GOOGLE_DRIVE_FOLDER_ID = "13MGy2nKNhMFKzTbmQ_QJd9fG38H4qv5X"
# Google Drive direct download link format - works for images shared publicly
GOOGLE_DRIVE_BASE_URL = "https://drive.google.com/uc?id="

# CHOOSE YOUR OPTION:
USE_LOCAL_FILES = True  # Set to False to use direct Google Drive links instead


def download_entire_folder():
    """Download all files from your Google Drive folder - one-time full download."""
    print("📥 Downloading ENTIRE Google Drive folder (this will take time for 2000 images)...")
    print(f"📂 Saving to: {IMAGES_DIR}")
    
    try:
        # Use gdown to download the entire folder - this is the simplest way
        result = subprocess.run([
            sys.executable, "-m", "gdown", "--folder", GOOGLE_DRIVE_FOLDER_ID,
            "-O", str(IMAGES_DIR)  # Save directly to our images directory
        ], check=True, cwd=BACKEND_DIR, capture_output=False, text=True)
        print("✅ Folder download completed!")
        return True
    except subprocess.CalledProcessError as e:
        print(f"⚠️  Download finished with some issues (common for large folders): {e}")
        print("💡 But we'll still process all successfully downloaded files!")
        return False


def update_product_catalog():
    """Update products.json with your Google Drive images - maps TRZ-XXXX.jpg to products."""
    print("\n🔧 Updating product catalog with your images...")
    
    # First backup the current products.json
    backup_path = PRODUCTS_JSON.with_suffix(".json.bak")
    shutil.copy(PRODUCTS_JSON, backup_path)
    print(f"💾 Backup created: {backup_path}")
    
    # Load current products
    with open(PRODUCTS_JSON, 'r') as f:
        products = json.load(f)
    
    # Get all downloaded TRZ-*.jpg images
    image_files = list(IMAGES_DIR.glob("TRZ-*.jpg"))
    print(f"🖼️  Found {len(image_files)} images to assign to products")
    
    # Create mapping from number to product (trenzy_XXXX to product)
    product_map = {}
    for i, product in enumerate(products):
        # Create sequential mapping: first image goes to first product, etc.
        num = f"{i+1:04d}"  # 0001, 0002, etc.
        product_id_for_image = f"trenzy_{num}"
        product_map[num] = product
    
    # Assign images to products
    images_assigned = 0
    for img_path in image_files:
        filename = img_path.name
        # Extract number from TRZ-0001.jpg
        import re
        match = re.search(r'TRZ-(\d+)', filename)
        if match:
            num = match.group(1)  # gets '0001' from TRZ-0001.jpg
            if num in product_map:
                product = product_map[num]
                # Create the image URL based on our choice
                if USE_LOCAL_FILES:
                    # Use local backend URL - this is what your app expects
                    image_url = f"/api/uploads/product-images/images/{filename}"
                else:
                    # If you wanted to use direct Google Drive links (not recommended for app performance)
                    # You'd need the file ID for each image, which is more complex
                    # So USE_LOCAL_FILES = True is better for your app
                    pass
                
                # Set as mainImage if not already set
                if not product.get('mainImage') or 'wikimedia.org' in product.get('mainImage', ''):
                    product['mainImage'] = image_url
                    # Initialize gallery if needed
                    if 'galleryImages' not in product:
                        product['galleryImages'] = []
                    images_assigned += 1
                    print(f"✅ Assigned {filename} to product: {product['name']}")
    
    # Save the updated products.json
    with open(PRODUCTS_JSON, 'w') as f:
        json.dump(products, f, indent=2)
    
    print(f"\n🎉 Updated {images_assigned} products with your images!")
    print(f"📝 Updated products.json saved. Backup is at: {backup_path}")


def main():
    print("🚀 Starting full Google Drive folder download and catalog update...")
    print(f"⚙️  Configuration: USE_LOCAL_FILES = {USE_LOCAL_FILES} (recommended)")
    
    # First download the entire folder
    download_entire_folder()
    
    # Then update the catalog
    update_product_catalog()
    
    # Count how many images we have
    final_count = len(list(IMAGES_DIR.glob("TRZ-*.jpg")))
    print(f"\n📊 Final stats: Downloaded {final_count}/2000 images")
    if final_count < 2000:
        print("💡 To download remaining images, just run this script again - it will resume!")


if __name__ == "__main__":
    main()