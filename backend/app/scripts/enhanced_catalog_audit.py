"""Enhanced catalog audit with visual contact sheets, perceptual hashing, and detailed reports.

This script performs comprehensive catalog quality checks:
1. URL uniqueness analysis
2. Broken URL detection
3. Perceptual hashing for visual duplicate detection
4. Contact sheet generation for visual inspection
5. Detailed CSV and JSON reports

Usage:
    python -m app.scripts.enhanced_catalog_audit
    python -m app.scripts.enhanced_catalog_audit --contact-sheets-only
    python -m app.scripts.enhanced_catalog_audit --skip-downloads
"""

from __future__ import annotations

import json
import sys
import csv
import argparse
import time
import hashlib
import requests
from pathlib import Path
from collections import Counter, defaultdict
from io import BytesIO
from typing import Any, Dict, List, Tuple, Optional
from dataclasses import dataclass

import imagehash
from PIL import Image, ImageDraw, ImageFont
from tqdm import tqdm

# -----------------------------------------------------------------------------
# Data Structures
# -----------------------------------------------------------------------------
@dataclass
class ProductImageInfo:
    product_id: str
    name: str
    category: str
    subcategory: str
    gender: str
    image_url: str
    source: str
    source_license: str
    source_page: str = ""
    author: str = ""
    attribution_required: bool = False
    local_path: Optional[Path] = None
    phash: Optional[str] = None
    is_broken: bool = False
    error_message: str = ""

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
CATALOG_PATH = Path(__file__).resolve().parents[2] / "data" / "products.json"
AUDIT_OUTPUT_DIR = Path(__file__).resolve().parents[2] / "catalog_audit"
IMAGES_CACHE_DIR = AUDIT_OUTPUT_DIR / "images_cache"
CONTACT_SHEET_SIZE = (10, 10)  # 10x10 grid = 100 images per sheet
IMAGE_DISPLAY_SIZE = (200, 200)  # Size of each image in contact sheet
TEXT_HEIGHT = 40  # Height for text below each image
DOWNLOAD_DELAY = 0.5  # seconds delay between image requests

# -----------------------------------------------------------------------------
# Core Audit Functions
# -----------------------------------------------------------------------------
def setup_directories() -> None:
    """Create all required output directories."""
    AUDIT_OUTPUT_DIR.mkdir(exist_ok=True)
    IMAGES_CACHE_DIR.mkdir(exist_ok=True)

def load_products() -> List[Dict[str, Any]]:
    """Load products from JSON catalog."""
    if not CATALOG_PATH.exists():
        raise FileNotFoundError(f"Catalog not found at {CATALOG_PATH}")
    with open(CATALOG_PATH, "r", encoding="utf-8") as f:
        return json.load(f)

def analyze_url_uniqueness(products: List[Dict[str, Any]]) -> Tuple[Dict[str, List[str]], int]:
    """Analyze which image URLs are reused across multiple products."""
    url_to_products: Dict[str, List[str]] = defaultdict(list)
    for product in products:
        url = product.get("image_url", "")
        if url:
            url_to_products[url].append(product["id"])
    
    # Filter to only reused URLs
    reused_urls = {
        url: product_ids 
        for url, product_ids in url_to_products.items() 
        if len(product_ids) > 1
    }
    return reused_urls, len(url_to_products)

def download_image(url: str, save_path: Path) -> Tuple[bool, str, Optional[Image.Image]]:
    """Download an image from URL and save to local path."""
    try:
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
        response = requests.get(url, headers=headers, timeout=15)
        response.raise_for_status()
        
        img = Image.open(BytesIO(response.content))
        img.convert("RGB").save(save_path)
        return True, "Success", img
    except Exception as e:
        return False, str(e), None

def compute_perceptual_hash(img: Image.Image) -> str:
    """Compute pHash for an image to detect duplicates."""
    return str(imagehash.phash(img))

def detect_visual_duplicates(image_infos: List[ProductImageInfo]) -> Dict[str, List[str]]:
    """Group product IDs by their perceptual hash to find visual duplicates."""
    phash_to_products: Dict[str, List[str]] = defaultdict(list)
    for info in image_infos:
        if info.phash and not info.is_broken:
            phash_to_products[info.phash].append(info.product_id)
    
    # Return only groups with duplicates
    return {
        phash: product_ids
        for phash, product_ids in phash_to_products.items()
        if len(product_ids) > 1
    }

def create_contact_sheet(
    image_infos: List[ProductImageInfo],
    sheet_number: int,
    output_dir: Path
) -> None:
    """Create a single contact sheet with grid of images and labels."""
    cols, rows = CONTACT_SHEET_SIZE
    img_w, img_h = IMAGE_DISPLAY_SIZE
    text_h = TEXT_HEIGHT
    
    # Calculate total sheet dimensions
    total_width = cols * img_w
    total_height = rows * (img_h + text_h)
    
    # Create blank canvas
    sheet = Image.new("RGB", (total_width, total_height), color=(255, 255, 255))
    draw = ImageDraw.Draw(sheet)
    
    # Try to load a font, fall back to default
    try:
        font = ImageFont.truetype("Arial", 12)
    except:
        font = ImageFont.load_default()
    
    for idx, info in enumerate(image_infos):
        if idx >= cols * rows:
            break
            
        col = idx % cols
        row = idx // cols
        
        x = col * img_w
        y = row * (img_h + text_h)
        
        # Paste image if available
        if info.local_path and info.local_path.exists() and not info.is_broken:
            try:
                img = Image.open(info.local_path)
                img.thumbnail(IMAGE_DISPLAY_SIZE)
                # Center the image in its slot
                paste_x = x + (img_w - img.width) // 2
                paste_y = y + (img_h - img.height) // 2
                sheet.paste(img, (paste_x, paste_y))
            except Exception:
                # Draw error placeholder
                draw.rectangle([x, y, x + img_w, y + img_h], fill=(200, 200, 200))
                draw.text((x + 10, y + img_h//2), "LOAD ERROR", fill=(255, 0, 0), font=font)
        else:
            # Draw broken image placeholder
            draw.rectangle([x, y, x + img_w, y + img_h], fill=(200, 0, 0))
            draw.text((x + 10, y + img_h//2), "BROKEN", fill=(255, 255, 255), font=font)
        
        # Draw text below image
        text_y = y + img_h + 5
        product_text = f"{info.product_id}\n{info.category} | {info.gender}"
        draw.text((x + 5, text_y), product_text, fill=(0, 0, 0), font=font)
    
    # Save the contact sheet
    sheet_path = output_dir / f"contact_sheet_{sheet_number:03d}.jpg"
    sheet.save(sheet_path, "JPEG", quality=85)
    print(f"Created contact sheet: {sheet_path}")

def generate_all_contact_sheets(image_infos: List[ProductImageInfo], output_dir: Path) -> None:
    """Generate all contact sheets from the list of image infos."""
    images_per_sheet = CONTACT_SHEET_SIZE[0] * CONTACT_SHEET_SIZE[1]
    valid_images = [info for info in image_infos if info.product_id]  # Filter out any empty entries
    
    for sheet_idx in range(0, len(valid_images), images_per_sheet):
        sheet_images = valid_images[sheet_idx:sheet_idx + images_per_sheet]
        create_contact_sheet(sheet_images, sheet_idx // images_per_sheet + 1, output_dir)

def write_csv_report(filepath: Path, headers: List[str], rows: List[List[str]]) -> None:
    """Write a CSV report file."""
    with open(filepath, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(rows)

def generate_reports(
    products: List[Dict[str, Any]],
    image_infos: List[ProductImageInfo],
    reused_urls: Dict[str, List[str]],
    visual_duplicates: Dict[str, List[str]],
    unique_url_count: int
) -> None:
    """Generate all audit reports in multiple formats."""
    # Create summary report
    broken_images = [info for info in image_infos if info.is_broken]
    total_products = len(products)
    
    summary = {
        "total_products": total_products,
        "unique_image_urls": unique_url_count,
        "reused_url_count": len(reused_urls),
        "total_reused_occurrences": sum(len(pids) for pids in reused_urls.values()),
        "visual_duplicate_groups": len(visual_duplicates),
        "total_visually_duplicated_products": sum(len(pids) for pids in visual_duplicates.values()),
        "broken_images": len(broken_images),
        "broken_image_details": [
            {"product_id": info.product_id, "url": info.image_url, "error": info.error_message}
            for info in broken_images
        ]
    }
    
    # Save main report.json
    with open(AUDIT_OUTPUT_DIR / "report.json", "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)
    
    # Save duplicate_images.csv - URL-based duplicates
    duplicate_rows = []
    for url, product_ids in reused_urls.items():
        for pid in product_ids[1:]:  # First occurrence is original, rest are duplicates
            duplicate_rows.append([pid, url, str(len(product_ids)), product_ids[0]])
    write_csv_report(
        AUDIT_OUTPUT_DIR / "duplicate_images.csv",
        ["product_id", "image_url", "total_uses", "original_product_id"],
        duplicate_rows
    )
    
    # Save broken_images.csv
    broken_rows = [[info.product_id, info.image_url, info.error_message] for info in broken_images]
    write_csv_report(
        AUDIT_OUTPUT_DIR / "broken_images.csv",
        ["product_id", "image_url", "error"],
        broken_rows
    )
    
    # Save visual_duplicates.csv
    visual_rows = []
    for phash, product_ids in visual_duplicates.items():
        for pid in product_ids[1:]:
            visual_rows.append([pid, phash, str(len(product_ids)), product_ids[0]])
    write_csv_report(
        AUDIT_OUTPUT_DIR / "visual_duplicates.csv",
        ["product_id", "perceptual_hash", "total_duplicates", "original_product_id"],
        visual_rows
    )
    
    # Save license_report.csv
    license_rows = [[
        info.product_id,
        info.image_url,
        info.source,
        info.source_license,
        info.source_page,
        info.author,
        str(info.attribution_required)
    ] for info in image_infos]
    write_csv_report(
        AUDIT_OUTPUT_DIR / "license_report.csv",
        ["product_id", "image_url", "source", "source_license", "source_page", "author", "attribution_required"],
        license_rows
    )
    
    print(f"\nAll reports generated in {AUDIT_OUTPUT_DIR}/")
    print(json.dumps(summary, indent=2))

def process_images(skip_downloads: bool = False, contact_sheets_only: bool = False) -> List[ProductImageInfo]:
    """Process all product images: download, compute hashes, prepare for contact sheets."""
    products = load_products()
    image_infos: List[ProductImageInfo] = []
    
    # If we're only doing contact sheets, load existing cache
    if contact_sheets_only:
        for product in products:
            url_hash = hashlib.md5(product["image_url"].encode()).hexdigest()
            local_path = IMAGES_CACHE_DIR / f"{url_hash}.jpg"
            image_infos.append(ProductImageInfo(
                product_id=product["id"],
                name=product["name"],
                category=product.get("category", "Unknown"),
                subcategory=product.get("subcategory", "Unknown"),
                gender=product.get("gender", "Unknown"),
                image_url=product["image_url"],
                source=product.get("source", "Unknown"),
                source_license=product.get("source_license", "Unknown"),
                local_path=local_path if local_path.exists() else None,
                is_broken=not local_path.exists()
            ))
        return image_infos
    
    # Full processing - download and hash
    for product in tqdm(products, desc="Processing images"):
        url = product["image_url"]
        url_hash = hashlib.md5(url.encode()).hexdigest()
        local_path = IMAGES_CACHE_DIR / f"{url_hash}.jpg"
        
        info = ProductImageInfo(
            product_id=product["id"],
            name=product["name"],
            category=product.get("category", "Unknown"),
            subcategory=product.get("subcategory", "Unknown"),
            gender=product.get("gender", "Unknown"),
            image_url=url,
            source=product.get("source", "Unknown"),
            source_license=product.get("source_license", "Unknown"),
            source_page=product.get("source_page", ""),
            author=product.get("author", ""),
            attribution_required=product.get("attribution_required", False),
            local_path=local_path
        )
        
        # Download if not already cached
        if not local_path.exists() and not skip_downloads:
            success, error, img = download_image(url, local_path)
            if not success or img is None:
                info.is_broken = True
                info.error_message = error
            else:
                info.phash = compute_perceptual_hash(img)
        elif local_path.exists():
            # Already cached, compute hash
            try:
                with Image.open(local_path) as img:
                    info.phash = compute_perceptual_hash(img)
            except Exception as e:
                info.is_broken = True
                info.error_message = f"Cached image corrupt: {str(e)}"
        elif skip_downloads:
            info.is_broken = True
            info.error_message = "Downloads skipped, image not in cache"
        
        image_infos.append(info)
        time.sleep(DOWNLOAD_DELAY)  # throttle requests to avoid 429 errors
    
    return image_infos

def main():
    parser = argparse.ArgumentParser(description="Enhanced catalog audit with visual inspection tools")
    parser.add_argument("--skip-downloads", action="store_true", help="Skip downloading new images, use only cache")
    parser.add_argument("--contact-sheets-only", action="store_true", help="Only regenerate contact sheets from cached images")
    args = parser.parse_args()
    
    try:
        setup_directories()
        products = load_products()
        
        # First run basic URL analysis
        reused_urls, unique_url_count = analyze_url_uniqueness(products)
        print(f"Initial URL analysis: {unique_url_count} unique URLs among {len(products)} products")
        print(f"Found {len(reused_urls)} URLs reused across multiple products")
        
        # Process images
        image_infos = process_images(args.skip_downloads, args.contact_sheets_only)
        
        # Detect visual duplicates
        visual_duplicates = detect_visual_duplicates(image_infos)
        print(f"Found {len(visual_duplicates)} visual duplicate groups")
        
        # Generate contact sheets
        print("\nGenerating contact sheets...")
        generate_all_contact_sheets(image_infos, AUDIT_OUTPUT_DIR)
        
        # Generate all reports
        if not args.contact_sheets_only:
            generate_reports(products, image_infos, reused_urls, visual_duplicates, unique_url_count)
        
        print("\n✅ Audit complete! Check the catalog_audit directory for all outputs.")
        return 0
        
    except Exception as e:
        print(f"❌ Audit failed: {str(e)}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    sys.exit(main())