"""Product image URLs for multi-image product detail views.

Returns all images associated with a product, ordered by display_order.
Images are stored as ProductImage rows with url, alt_text, and
display_order fields.
"""
from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..db import get_session
from ..models import ProductImage

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/products/{product_id}/images", tags=["product_images"])


@router.get("")
def list_product_images(product_id: str, session: Session = Depends(get_session)) -> dict[str, Any]:
    images = (
        session.query(ProductImage)
        .filter(ProductImage.product_id == product_id)
        .order_by(ProductImage.sort_order)
        .all()
    )
    return {
        "images": [
            {
                "id": img.id,
                "url": img.url,
                "alt_text": img.alt_text,
                "sort_order": img.sort_order,
            }
            for img in images
        ]
    }
