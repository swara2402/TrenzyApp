"""Brand catalog endpoints with product counts.

Lists all brands (optionally filtered by gender/category) with product counts.
Brand data is used by the catalog filters and brand-specific browse pages.
"""
from __future__ import annotations

import logging
from typing import Any, Optional

from fastapi import APIRouter, Depends, Request
from sqlalchemy import func
from sqlalchemy.orm import Session

from ..db import get_session
from ..models import Brand, Product


def _escape_like(value: str) -> str:
    """Escape LIKE wildcards so user input can't inject % or _ patterns."""
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/brands", tags=["brands"])


@router.get("")
def list_brands(request: Request, search: Optional[str] = None, session: Session = Depends(get_session)) -> dict[str, Any]:
    """Return distinct brands from products table with product counts."""
    query = (
        session.query(
            Product.brand,
            func.count(Product.id).label("product_count"),
        )
        .filter(Product.brand.isnot(None))
        .filter(Product.brand != "")
        .filter(Product.brand != "N/A")
        .filter(Product.brand != '"N/A"')
        .filter(~Product.brand.ilike("%n/a%"))
    )
    if search:
        query = query.filter(Product.brand.ilike(f"%{_escape_like(search)}%", escape="\\"))
    query = query.group_by(Product.brand).order_by(Product.brand)

    rows = query.all()
    brands = [
        {
            "id": idx,
            "name": r.brand,
            "description": None,
            "logo_url": None,
            "product_count": r.product_count,
        }
        for idx, r in enumerate(rows)
    ]
    return {"brands": brands}


@router.get("/{brand_id}")
def get_brand(brand_id: int, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    brand = session.query(Brand).filter(Brand.id == brand_id).first()
    if not brand:
        return {"brand": None}
    products = (
        session.query(Product)
        .filter(Product.brand_id == brand_id)
        .all()
    )
    return {
        "brand": {
            "id": brand.id,
            "name": brand.name,
            "description": brand.description,
            "logo_url": brand.logo_url,
        },
        "products": [
            {
                "id": p.id,
                "name": p.name,
                "image_url": p.image_url,
                "price": p.price,
                "category": p.category,
            }
            for p in products
        ],
        "product_count": len(products),
    }
