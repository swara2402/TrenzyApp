"""Export a read-only HTML gallery for visual catalog QA.

Run from backend/:
    python -m app.scripts.export_catalog_review
    python -m app.scripts.export_catalog_review --all
    python -m app.scripts.export_catalog_review --output /tmp/trenzy-catalog-review.html

The script never changes the catalog or database. The default gallery shows
records with missing/unrecognized item types, category mismatches, or missing
image URLs. Use --all to inspect every record visually.
"""
from __future__ import annotations

import argparse
import html
import json
from pathlib import Path
from typing import Any

from ..catalog_categories import canonical_category

CATALOG_PATH = Path(__file__).resolve().parents[2] / "data" / "products.json"


def _text(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, (list, tuple, set)):
        return ", ".join(str(item) for item in value)
    if isinstance(value, dict):
        return json.dumps(value, ensure_ascii=False)
    return str(value)


def _needs_review(product: dict[str, Any]) -> bool:
    expected = canonical_category(product.get("subcategory"))
    current = _text(product.get("category")).strip()
    return (
        not expected
        or current.casefold() != expected.casefold()
        or not _text(product.get("image_url")).strip()
    )


def export_gallery(
    source: Path = CATALOG_PATH,
    output: Path = Path("catalog-review.html"),
    include_all: bool = False,
) -> dict[str, int]:
    products = json.loads(source.read_text(encoding="utf-8"))
    selected = [
        product for product in products
        if include_all or _needs_review(product)
    ]

    cards: list[str] = []
    for product in selected:
        product_id = _text(product.get("id"))
        name = _text(product.get("name")) or "(missing name)"
        category = _text(product.get("category")) or "(empty)"
        subcategory = _text(product.get("subcategory")) or "(empty)"
        expected = canonical_category(product.get("subcategory")) or "(unclassified)"
        image_url = _text(product.get("image_url")).strip()
        tags = _text(product.get("tags")) or "(none)"
        price = _text(product.get("price")) or "(unavailable)"
        mismatch = expected == "(unclassified)" or category.casefold() != expected.casefold()
        status = "review" if mismatch or not image_url else "check-image"
        safe_url = html.escape(image_url, quote=True)
        image = (
            f'<img loading="lazy" src="{safe_url}" alt="{html.escape(name, quote=True)}" '
            'onerror="this.hidden=true;this.nextElementSibling.hidden=false">'
            '<div class="broken" hidden>Image failed to load</div>'
            if image_url else '<div class="broken">Missing image URL</div>'
        )
        cards.append(
            f'<article class="product" data-status="{status}" '
            f'data-search="{html.escape(" ".join((product_id, name, category, subcategory, expected, tags)).casefold(), quote=True)}">'
            f'<div class="photo">{image}</div>'
            f'<div class="meta"><strong>{html.escape(product_id)}</strong> '
            f'<span class="badge">{html.escape(status)}</span></div>'
            f'<h2>{html.escape(name)}</h2>'
            f'<p><b>Stored category:</b> {html.escape(category)}</p>'
            f'<p><b>Subcategory:</b> {html.escape(subcategory)}</p>'
            f'<p><b>Rule-based category:</b> {html.escape(expected)}</p>'
            f'<p><b>Price:</b> {html.escape(price)}</p>'
            f'<p><b>Tags:</b> {html.escape(tags)}</p>'
            f'<p class="url">{html.escape(image_url or "(missing)")}</p>'
            '</article>'
        )

    output.parent.mkdir(parents=True, exist_ok=True)
    page = """<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Trenzy catalog visual review</title>
<style>
:root{color-scheme:light dark;font:14px/1.45 system-ui,sans-serif}
body{margin:0;padding:20px;background:#171717;color:#f3f3f3}
header{position:sticky;top:0;background:#171717;padding:12px 0;z-index:2;border-bottom:1px solid #444}
.controls{display:flex;gap:8px;flex-wrap:wrap;margin:10px 0}
input,select{padding:10px;border-radius:8px;border:1px solid #666;background:#222;color:inherit}
#count{color:#cbb78b}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:14px;margin-top:18px}
.product{border:1px solid #444;border-radius:12px;padding:10px;background:#222;min-width:0}
.photo{height:230px;background:#333;border-radius:8px;display:grid;place-items:center;overflow:hidden}
.photo img{width:100%;height:100%;object-fit:contain}
.broken{color:#ffb4a9;padding:12px;text-align:center}
.meta{display:flex;justify-content:space-between;gap:6px;margin-top:10px}
.badge{font-size:11px;background:#51452f;padding:2px 6px;border-radius:6px}
h2{font-size:15px;margin:8px 0;overflow-wrap:anywhere}
p{margin:5px 0;overflow-wrap:anywhere}
.url{font-size:10px;color:#aaa}
</style></head><body>
<header><h1>Trenzy catalog visual review</h1>
<p>Read-only review gallery. A rule-based category is a suggestion, not ground truth. Verify each image visually before changing product metadata.</p>
<div class="controls"><input id="search" placeholder="Search ID, name, category, tags…">
<select id="status"><option value="all">All shown records</option><option value="review">Unclassified / category mismatch</option><option value="check-image">Classified — verify image</option></select></div>
<div id="count"></div></header>
<main class="grid">__CARDS__</main>
<script>
const search=document.querySelector('#search'),status=document.querySelector('#status'),cards=[...document.querySelectorAll('.product')],count=document.querySelector('#count');
function filter(){let n=0;const q=search.value.toLowerCase();for(const c of cards){const ok=c.dataset.search.includes(q)&&(status.value==='all'||c.dataset.status===status.value);c.hidden=!ok;if(ok)n++;}count.textContent=n+' of '+cards.length+' shown in this gallery';}
search.addEventListener('input',filter);status.addEventListener('change',filter);filter();
</script></body></html>"""
    output.write_text(page.replace("__CARDS__", "\n".join(cards)), encoding="utf-8")
    return {
        "catalog_records": len(products),
        "records_in_gallery": len(selected),
        "records_flagged_for_review": sum(_needs_review(p) for p in products),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=CATALOG_PATH)
    parser.add_argument("--output", type=Path, default=Path("catalog-review.html"))
    parser.add_argument("--all", action="store_true", help="include every catalog record")
    args = parser.parse_args()
    print(json.dumps(export_gallery(args.source, args.output, args.all), indent=2))
    print(f"Read-only gallery written to: {args.output.resolve()}")


if __name__ == "__main__":
    main()
