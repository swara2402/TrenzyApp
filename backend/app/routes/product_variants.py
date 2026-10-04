"""Product size/color variants.

Returns available sizes and colors for a product. Each ProductVariant row
represents a unique size+color combination with optional stock tracking.
"""
from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..db import get_session
from ..models import ProductVariant

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/products/{product_id}/variants", tags=["product_variants"])


@router.get("")
def list_product_variants(product_id: str, session: Session = Depends(get_session)) -> dict[str, Any]:
    variants = (
        session.query(ProductVariant)
        .filter(ProductVariant.product_id == product_id)
        .all()
    )
    return {
        "variants": [
            {
                "id": v.id,
                "size": v.size,
                "color": v.color,
                "stock": v.stock,
                "price_modifier": v.price_modifier,
            }
            for v in variants
        ]
    }
