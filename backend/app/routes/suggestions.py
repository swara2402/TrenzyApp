"""Product search suggestions and autocomplete.

Provides typeahead suggestions as the user types in the search bar.
Returns up to 8 matching product names with IDs and image URLs for
display in the autocomplete dropdown. Results are filtered by gender
when specified.
"""
from __future__ import annotations

import logging
from typing import Any, Optional

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..models import Product


def _escape_like(value: str) -> str:
    """Escape LIKE wildcards so user input can't inject % or _ patterns."""
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/suggestions", tags=["suggestions"])


@router.get("")
def list_suggestions(
    request: Request,
    query: Optional[str] = None,
    category: Optional[str] = None,
    gender: Optional[str] = None,
    limit: int = 10,
    offset: int = 0,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    verify_firebase_token(request)
    limit = max(1, min(limit, 50))
    offset = max(0, offset)
    q = session.query(Product)
    if query:
        q = q.filter(Product.name.ilike(f"%{_escape_like(query)}%", escape="\\"))
    if category:
        q = q.filter(Product.category == category)
    if gender:
        q = q.filter(Product.gender == gender)

    total = q.count()
    products = q.offset(offset).limit(min(limit, 50)).all()
    return {
        "suggestions": [
            {
                "id": p.id,
                "name": p.name,
                "image_url": p.image_url,
                "price": p.price,
                "brand": p.brand,
                "category": p.category,
            }
            for p in products
        ],
        "pagination": {
            "offset": offset,
            "limit": limit,
            "total": total,
            "hasMore": (offset + limit) < total,
        },
    }


class ReasoningRequest(BaseModel):
    product_ids: list[str]
    preference: Optional[str] = None


@router.post("/reasoning")
def get_reasoning(payload: ReasoningRequest, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    verify_firebase_token(request)
    products = session.query(Product).filter(Product.id.in_(payload.product_ids)).all()
    product_map = {p.id: p for p in products}
    ordered = [product_map.get(pid) for pid in payload.product_ids if pid in product_map]

    explanations = []
    for p in ordered:
        reasons = []
        if p.price and p.price < 50:
            reasons.append("affordable")
        if p.rating and p.rating >= 4.0:
            reasons.append("highly_rated")
        if p.brand:
            reasons.append(f"from_{p.brand.lower().replace(' ', '_')}")
        explanations.append({
            "product_id": p.id,
            "name": p.name,
            "reasons": reasons,
        })

    return {
        "explanations": explanations,
        "preference": payload.preference,
    }
