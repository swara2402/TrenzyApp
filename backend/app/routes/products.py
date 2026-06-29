from __future__ import annotations

from typing import Any, Optional

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy import select, or_

from ..db import SessionLocal
from ..firebase_auth import verify_firebase_token
from ..models import Product

router = APIRouter(prefix="/api", tags=["products"])


def _escape_like(value: str) -> str:
    """Escape LIKE wildcards so user input can't inject % or _ patterns."""
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def _product_payload(product):
    return {
        "id": product.id,
        "name": product.name,
        "category": product.category,
        "subcategory": product.subcategory,
        "article_type": product.article_type,
        "gender": product.gender,
        "color": product.color,
        "season": product.season,
        "usage": product.usage,
        "price": product.price,
        "brand": product.brand,
        "rating": product.rating,
        "image_url": product.image_url,
        "tags": product.tags,
        "affiliate_links": product.affiliate_links,
    }


class ProductQuery(BaseModel):
    query: str


@router.get("/categories")
def list_categories(request: Request):
    verify_firebase_token(request)

    db = SessionLocal()
    try:
        categories = (
            db.query(Product.category)
            .distinct()
            .all()
        )
        return [c[0] for c in categories if c[0]]
    finally:
        db.close()


@router.get("/products")
def list_products(request: Request, category: Optional[str] = None, limit: int = 24):
    verify_firebase_token(request)

    limit = max(1, min(limit, 100))
    db = SessionLocal()
    try:
        stmt = select(Product)
        if category:
            stmt = stmt.where(
                Product.category.ilike(f"%{_escape_like(category)}%", escape="\\")
            )

        stmt = stmt.order_by(Product.id).limit(limit)
        products = list(db.execute(stmt).scalars().all())
        return [_product_payload(p) for p in products]
    finally:
        db.close()


@router.get("/products/search")
def search_products(
    request: Request,
    q: str = "",
    category: Optional[str] = None,
    minPrice: Optional[float] = None,
    maxPrice: Optional[float] = None,
    sort: str = "relevance",
    limit: int = 24,
):
    verify_firebase_token(request)

    limit = max(1, min(limit, 100))
    normalized_query = q.strip()

    db = SessionLocal()
    try:
        stmt = select(Product)
        if category:
            stmt = stmt.where(
                Product.category.ilike(f"%{_escape_like(category)}%", escape="\\")
            )

        if normalized_query:
            pattern = f"%{_escape_like(normalized_query)}%"
            stmt = stmt.where(
                or_(
                    Product.name.ilike(pattern, escape="\\"),
                    Product.brand.ilike(pattern, escape="\\"),
                    Product.category.ilike(pattern, escape="\\"),
                    Product.subcategory.ilike(pattern, escape="\\"),
                    Product.article_type.ilike(pattern, escape="\\"),
                )
            )

        products = list(db.execute(stmt).scalars().all())
        payload = [_product_payload(p) for p in products]

        # Price filtering
        if minPrice is not None:
            payload = [p for p in payload if (p["price"] or 0) >= minPrice]
        if maxPrice is not None:
            payload = [p for p in payload if (p["price"] or 0) <= maxPrice]

        # Sorting
        if sort == "price_asc":
            payload.sort(key=lambda p: p["price"] or 0)
        elif sort == "price_desc":
            payload.sort(key=lambda p: p["price"] or 0, reverse=True)
        elif sort == "rating_desc":
            payload.sort(key=lambda p: p.get("rating") or 0, reverse=True)
        elif normalized_query:
            query_lower = normalized_query.lower()
            payload.sort(
                key=lambda p: (
                    0 if query_lower in (p.get("name") or "").lower() else 1,
                    -(p.get("rating") or 0),
                )
            )

        return payload[:limit]
    finally:
        db.close()


@router.get("/products/{product_id}")
def product_details(request: Request, product_id: str):
    verify_firebase_token(request)

    db = SessionLocal()
    try:
        p = db.query(Product).filter(Product.id == product_id).first()
        if not p:
            raise HTTPException(status_code=404, detail="Product not found")
        return _product_payload(p)
    finally:
        db.close()