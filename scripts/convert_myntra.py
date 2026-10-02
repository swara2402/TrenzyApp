#!/usr/bin/env python3
"""Convert Myntra styles.csv (or similar) to the products.csv format expected
by load_products.py.

Usage:
    python scripts/convert_myntra.py data/styles.csv -o backend/data/products.csv
    python scripts/convert_myntra.py data/styles.csv --format json -o backend/data/products.json

If the input has no affiliate_url column, a placeholder Google Search link is
generated so the CTA still works (falls back to search by product name + brand).
"""

import argparse
import csv
import json
import sys
from pathlib import Path

# Column mapping: Myntra source column → Trenzy target column
COLUMN_MAP = {
    "id": "id",
    "product_id": "id",
    "productDisplayName": "name",
    "productDisplayName_myntra": "name",
    "productName": "name",
    "name": "name",
    "brandName": "brand",
    "brand": "brand",
    "price": "price",
    "MRP": "price",
    "colour": "color",
    "color": "color",
    "masterCategory": "category",
    "category": "category",
    "subCategory": "subcategory",
    "subcategory": "subcategory",
    "articleType": "article_type",
    "article_type": "article_type",
    "gender": "gender",
    "season": "season",
    "usage": "usage",
    "img": "image_url",
    "image_url": "image_url",
    "imageUrl": "image_url",
    "product_url": "affiliate_url",
    "affiliate_url": "affiliate_url",
    "link": "affiliate_url",
    "rating": "rating",
    "avg_rating": "rating",
}

TARGET_FIELDS = [
    "id", "name", "brand", "price", "color", "category", "subcategory",
    "article_type", "gender", "season", "usage", "image_url", "affiliate_url",
    "rating", "tags",
]


def _affiliate_fallback(name: str, brand: str) -> str:
    """Generate a Google Search fallback URL when no affiliate link exists."""
    query = f"{name} {brand} buy online".replace(" ", "+")
    return f"https://www.google.com/search?q={query}"


def _detect_delimiter(path: Path) -> str:
    """Sniff the delimiter from the first line."""
    with open(path, encoding="utf-8") as f:
        first = f.readline()
    if "\t" in first:
        return "\t"
    if ";" in first and first.count(";") > first.count(","):
        return ";"
    return ","


def convert_row(row: dict, affiliate_fallback: bool) -> dict:
    """Map one source row to the target schema."""
    mapped = {}
    for src_col, val in row.items():
        target = COLUMN_MAP.get(src_col)
        if target and val:
            mapped[target] = val.strip()

    # Ensure numeric fields
    if "price" in mapped:
        try:
            mapped["price"] = float(mapped["price"])
        except ValueError:
            mapped["price"] = 0.0
    if "rating" in mapped:
        try:
            r = float(mapped["rating"])
            mapped["rating"] = min(max(r, 0.0), 5.0)
        except ValueError:
            mapped["rating"] = 0.0

    # Generate fallback affiliate URL if missing
    if affiliate_fallback and not mapped.get("affiliate_url"):
        mapped["affiliate_url"] = _affiliate_fallback(
            mapped.get("name", ""), mapped.get("brand", "")
        )

    return mapped


def convert_csv(input_path: Path, output_path: Path, affiliate_fallback: bool) -> int:
    """Convert CSV input to CSV output. Returns row count."""
    delimiter = _detect_delimiter(input_path)
    rows_written = 0

    with open(input_path, encoding="utf-8") as fin, \
         open(output_path, "w", newline="", encoding="utf-8") as fout:
        reader = csv.DictReader(fin, delimiter=delimiter)
        writer = csv.DictWriter(fout, fieldnames=TARGET_FIELDS, extrasaction="ignore")
        writer.writeheader()

        for row in reader:
            mapped = convert_row(row, affiliate_fallback)
            if not mapped.get("id"):
                continue
            writer.writerow({f: mapped.get(f, "") for f in TARGET_FIELDS})
            rows_written += 1

    return rows_written


def convert_json(input_path: Path, output_path: Path, affiliate_fallback: bool) -> int:
    """Convert CSV/JSON input to JSON output. Returns row count."""
    with open(input_path, encoding="utf-8") as f:
        raw = json.load(f)

    if isinstance(raw, dict):
        items = raw.get("products", raw.get("data", []))
    elif isinstance(raw, list):
        items = raw
    else:
        items = []

    # If input is CSV-style list of dicts (from json.load of CSV-like data)
    # and keys don't match our target, try mapping
    products = []
    for item in items:
        mapped = convert_row(item, affiliate_fallback)
        if not mapped.get("id"):
            continue
        products.append({f: mapped.get(f, "") for f in TARGET_FIELDS})

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(products, f, indent=2, ensure_ascii=False)

    return len(products)


def main():
    parser = argparse.ArgumentParser(description="Convert Myntra styles.csv to Trenzy products format")
    parser.add_argument("input", type=Path, help="Path to source CSV or JSON file")
    parser.add_argument("-o", "--output", type=Path, default=None,
                        help="Output path (default: backend/data/products.<ext>)")
    parser.add_argument("--format", choices=["csv", "json"], default="csv",
                        help="Output format (default: csv)")
    parser.add_argument("--no-fallback", action="store_true",
                        help="Don't generate Google Search fallback affiliate URLs")
    args = parser.parse_args()

    if not args.input.exists():
        print(f"Error: {args.input} not found", file=sys.stderr)
        sys.exit(1)

    suffix = ".csv" if args.format == "csv" else ".json"
    output = args.output or Path(f"backend/data/products{suffix}")

    affiliate_fallback = not args.no_fallback

    if args.format == "csv":
        count = convert_csv(args.input, output, affiliate_fallback)
    else:
        count = convert_json(args.input, output, affiliate_fallback)

    print(f"Converted {count} products → {output}")


if __name__ == "__main__":
    main()
