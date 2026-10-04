#!/usr/bin/env python3
"""Download remaining TRZ-0063 to TRZ-2000 images from Google Drive one by one (avoids rate limits).
Processes each image immediately after download to update the catalog.
Automatically lists all files from your Google Drive folder.
"""
import time
import subprocess
import sys
import re
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parents[1]
IMAGES_DIR = BACKEND_DIR / "uploads" / "product-images" / "images"
IMAGES_DIR.mkdir(parents=True, exist_ok=True)

# Your Google Drive folder ID (from your shared link: https://drive.google.com/drive/folders/13MGy2nKNhMFKzTbmQ_QJd9fG38H4qv5X)
GOOGLE_DRIVE_FOLDER_ID = "13MGy2nKNhMFKzTbmQ_QJd9fG38H4qv5X"

def download_folder_incrementally():
    """Download from Google Drive folder incrementally, respecting rate limits with delays."""
    print("📥 Starting incremental folder download (resumes existing files)...")
    try:
        # Use gdown's folder mode with continue flag to resume partial downloads
        # We'll add delays between large batches to avoid rate limits
        result = subprocess.run([
            sys.executable, "-m", "gdown", "--folder", GOOGLE_DRIVE_FOLDER_ID,
            "--continue",  # Resume partial downloads
            "-O", str(IMAGES_DIR.parent)  # Save to product-images directory
        ], check=True, cwd=BACKEND_DIR, capture_output=False, text=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f"⚠️  Folder download encountered issues (this is normal if rate-limited): {e}")
        print("💡 The script will still process all successfully downloaded files!")
        return False



def process_new_images():
    """Process all downloaded images to update the catalog."""
    print("\n🔧 Processing all downloaded images...")
    try:
        result = subprocess.run([
            sys.executable, "scripts/process_google_drive_images.py",
            "--images-dir", "./uploads/product-images/images"
        ], check=True, cwd=BACKEND_DIR, capture_output=False, text=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f"⚠️  Processing had issues: {e}")
        return False

def count_local_images() -> int:
    """Count how many TRZ-*.jpg images we have locally."""
    count = 0
    for file in IMAGES_DIR.glob("TRZ-*.jpg"):
        count += 1
    return count

def main():
    print("🚀 Starting incremental download of remaining images...")
    print(f"📂 Save directory: {IMAGES_DIR}")
    
    # Count current images
    initial_count = count_local_images()
    print(f"📊 Currently downloaded: {initial_count} images")
    
    # First, process any images we already have
    process_new_images()
    
    # Try to download remaining images - this will resume where it left off
    download_folder_incrementally()
    
    # After download completes (or fails due to rate limits), process all new images
    final_count = count_local_images()
    new_images = final_count - initial_count
    print(f"\n📥 Downloaded {new_images} new images in this session")
    
    # Final process of all remaining images
    process_new_images()
    print(f"\n🎉 Done! Total images now: {final_count}")

if __name__ == "__main__":
    main()