"""Generate visual contact sheets for catalog inspection and Visual QA.

Arranges catalog images into grids (e.g. 5x5 or 10x10) labeled with:
- Product ID
- Category & Style
- Price
- Source Attribution
"""

import os
import sys
import json
import io
import logging
from pathlib import Path
from typing import List, Dict, Any, Optional
from PIL import Image, ImageDraw, ImageFont
import httpx
import certifi

SCRIPT_DIR = Path(__file__).resolve().parent
BACKEND_DIR = SCRIPT_DIR.parents[1]
DATA_DIR = BACKEND_DIR / "data"
OUTPUT_DIR = BACKEND_DIR / "catalog_audit"
CATALOG_PATH = DATA_DIR / "products.json"

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("contact_sheets")


def create_contact_sheet(
    products: List[Dict[str, Any]],
    sheet_index: int,
    grid_cols: int = 5,
    grid_rows: int = 5,
    thumb_size: int = 200,
    text_height: int = 50,
) -> Path:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    cell_w = thumb_size
    cell_h = thumb_size + text_height
    sheet_w = grid_cols * cell_w
    sheet_h = grid_rows * cell_h

    # White background image
    sheet = Image.new("RGB", (sheet_w, sheet_h), color=(255, 255, 255))
    draw = ImageDraw.Draw(sheet)

    with httpx.Client(timeout=15.0, verify=certifi.where(), follow_redirects=True) as client:
        for idx, prod in enumerate(products):
            if idx >= grid_cols * grid_rows:
                break

            col = idx % grid_cols
            row = idx // grid_cols
            x = col * cell_w
            y = row * cell_h

            img_url = prod.get("image_url", "")
            img_loaded = False
            thumb = None

            if img_url:
                try:
                    resp = client.get(img_url)
                    if resp.status_code == 200:
                        raw_img = Image.open(io.BytesIO(resp.content)).convert("RGB")
                        raw_img.thumbnail((thumb_size, thumb_size))
                        # Center in cell thumbnail box
                        thumb = Image.new("RGB", (thumb_size, thumb_size), (240, 240, 240))
                        offset_x = (thumb_size - raw_img.width) // 2
                        offset_y = (thumb_size - raw_img.height) // 2
                        thumb.paste(raw_img, (offset_x, offset_y))
                        img_loaded = True
                except Exception as e:
                    logger.debug("Failed loading %s: %s", img_url, e)

            if not img_loaded or thumb is None:
                thumb = Image.new("RGB", (thumb_size, thumb_size), (220, 220, 220))
                thumb_draw = ImageDraw.Draw(thumb)
                thumb_draw.text((10, thumb_size // 2 - 10), "No Image", fill=(100, 100, 100))

            sheet.paste(thumb, (x, y))

            # Label below image
            p_id = prod.get("id", "N/A")
            cat = prod.get("category", "")
            price = f"₹{int(prod.get('price', 0))}"
            brand = prod.get("brand", "")[:15]

            text_line1 = f"{p_id} | {cat.upper()}"
            text_line2 = f"{price} | {brand}"

            draw.text((x + 6, y + thumb_size + 4), text_line1, fill=(20, 20, 20))
            draw.text((x + 6, y + thumb_size + 22), text_line2, fill=(80, 80, 80))

            # Grid border
            draw.rectangle([x, y, x + cell_w, y + cell_h], outline=(220, 220, 220), width=1)

    out_path = OUTPUT_DIR / f"contact_sheet_{sheet_index:02d}.jpg"
    sheet.save(out_path, "JPEG", quality=85)
    logger.info("Saved contact sheet: %s", out_path)
    return out_path


def generate_all_contact_sheets(max_sheets: int = 4, items_per_sheet: int = 25) -> List[Path]:
    if not CATALOG_PATH.exists():
        logger.error("Catalog %s does not exist.", CATALOG_PATH)
        return []

    with open(CATALOG_PATH, "r", encoding="utf-8") as f:
        products = json.load(f)

    logger.info("Generating contact sheets for %d catalog products...", len(products))
    generated: List[Path] = []

    for s_idx in range(max_sheets):
        start = s_idx * items_per_sheet
        end = start + items_per_sheet
        batch = products[start:end]
        if not batch:
            break
        sheet_path = create_contact_sheet(batch, sheet_index=s_idx + 1)
        generated.append(sheet_path)

    return generated


if __name__ == "__main__":
    generate_all_contact_sheets()
