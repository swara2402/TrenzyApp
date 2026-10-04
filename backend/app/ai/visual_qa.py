"""Visual QA – generate contact sheets for catalog images.

Creates a PNG contact sheet for every batch of 25 images in
`backend/uploads/images/` and saves them under `backend/exports/contact_sheets/`.
A simple log is written to `backend/exports/visual_qa.log`.
"""

import os
from pathlib import Path
from math import ceil
from typing import List

from PIL import Image

# Configuration --------------------------------------------------------------
IMAGE_DIR = Path(os.getenv("IMAGE_DIR", "backend/uploads/images"))
OUTPUT_DIR = Path(os.getenv("CONTACT_SHEET_OUTPUT", "backend/exports/contact_sheets"))
LOG_PATH = Path(os.getenv("VISUAL_QA_LOG", "backend/exports/visual_qa.log"))
BATCH_SIZE = int(os.getenv("CONTACT_SHEET_BATCH_SIZE", "25"))
THUMB_SIZE = (200, 200)  # 200×200 thumbnails – fits nicely in a grid


def get_image_paths() -> List[Path]:
    """Return a list of image file paths sorted alphabetically."""
    return sorted([p for p in IMAGE_DIR.iterdir() if p.is_file() and p.suffix.lower() in {".jpg", ".jpeg", ".png"}])


def make_contact_sheet(batch: List[Path], sheet_index: int) -> None:
    """Create a single contact sheet PNG from a list of image paths.

    The sheet is a simple grid of `THUMB_SIZE` thumbnails. Empty slots are left
    blank (white) if the batch is not a full multiple of the grid size.
    """
    cols = 5
    rows = ceil(len(batch) / cols)
    sheet = Image.new("RGB", (cols * THUMB_SIZE[0], rows * THUMB_SIZE[1]), color="white")
    for i, img_path in enumerate(batch):
        img = Image.open(img_path).convert("RGB")
        img.thumbnail(THUMB_SIZE, Image.Resampling.LANCZOS)
        x = (i % cols) * THUMB_SIZE[0]
        y = (i // cols) * THUMB_SIZE[1]
        sheet.paste(img, (x, y))
    sheet_path = OUTPUT_DIR / f"contact_sheet_{sheet_index:04d}.png"
    sheet.save(sheet_path)
    return sheet_path


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    images = get_image_paths()
    total = len(images)
    with LOG_PATH.open("w", encoding="utf-8") as log:
        log.write(f"Found {total} images in {IMAGE_DIR}\n")
        for i in range(0, total, BATCH_SIZE):
            batch = images[i : i + BATCH_SIZE]
            sheet_path = make_contact_sheet(batch, sheet_index=i // BATCH_SIZE + 1)
            log.write(f"Created {sheet_path}\n")
    print(f"Visual QA complete – contact sheets saved to {OUTPUT_DIR}")

if __name__ == "__main__":
    main()
