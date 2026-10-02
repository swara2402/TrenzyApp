"""Category catalog endpoints with product counts.

Lists all categories (optionally filtered by gender) with product counts.
Categories map to the three main catalog sections: Uppers, Bottoms, Footwear.
"""
from __future__ import annotations

import logging
from typing import Any, Optional

from fastapi import APIRouter, Depends, Request
from sqlalchemy import func
from sqlalchemy.orm import Session

from ..db import get_session
from ..models import Category, Product

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/categories", tags=["categories"])


def _build_tree(session: Session, parent_id: Optional[int] = None) -> list[dict[str, Any]]:
    query = (
        session.query(
            Category.id,
            Category.name,
            Category.parent_category_id,
            func.count(Product.id).label("product_count"),
        )
        .outerjoin(Product, Product.category_id == Category.id)
    )
    if parent_id is None:
        query = query.filter(Category.parent_category_id.is_(None))
    else:
        query = query.filter(Category.parent_category_id == parent_id)
    query = query.group_by(Category.id, Category.name, Category.parent_category_id).order_by(Category.name)
    rows = query.all()
    result = []
    for r in rows:
        children = _build_tree(session, parent_id=r.id)
        node: dict[str, Any] = {
            "id": r.id,
            "name": r.name,
            "product_count": r.product_count,
        }
        if children:
            node["children"] = children
        result.append(node)
    return result


@router.get("")
def list_categories(request: Request, session: Session = Depends(get_session)):
    """Return a flat list of distinct category name strings from products (Flutter frontend expects List<String>)."""
    cats = session.query(Product.category).filter(Product.category.isnot(None)).distinct().order_by(Product.category).all()
    return [c[0] for c in cats if c[0]]


@router.get("/{category_name}/subcategories")
def list_subcategories(request: Request, category_name: str, session: Session = Depends(get_session)):
    """Return subcategories for a given parent category name from products."""
    subcats = session.query(Product.subcategory).filter(
        Product.category == category_name,
        Product.subcategory.isnot(None)
    ).distinct().order_by(Product.subcategory).all()
    return [c[0] for c in subcats if c[0]]


@router.get("/{category_id}")
def get_category(category_id: int, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    category = session.query(Category).filter(Category.id == category_id).first()
    if not category:
        return {"category": None, "products": []}

    # Add pagination to prevent loading all products for large categories
    try:
        offset = int(request.query_params.get("offset", 0))
    except (ValueError, TypeError):
        offset = 0
    try:
        limit = int(request.query_params.get("limit", 24))
    except (ValueError, TypeError):
        limit = 24
    limit = max(1, min(limit, 100))
    
    total_products = session.query(Product).filter(Product.category_id == category_id).count()
    products = (
        session.query(Product)
        .filter(Product.category_id == category_id)
        .offset(offset)
        .limit(limit)
        .all()
    )
    children = _build_tree(session, parent_id=category_id)

    return {
        "category": {
            "id": category.id,
            "name": category.name,
            "parent_category_id": category.parent_category_id,
        },
        "children": children,
        "products": [
            {
                "id": p.id,
                "name": p.name,
                "image_url": p.image_url,
                "price": p.price,
                "brand": p.brand,
                "display_brand": p.display_brand,
                "display_price": p.display_price,
            }
            for p in products
        ],
        "product_count": total_products,
        "pagination": {
            "offset": offset,
            "limit": limit,
            "total": total_products,
            "hasMore": (offset + limit) < total_products,
        },
    }