"""Purchase history and affiliate click tracking.

Records product purchases (linked to product_id and user) and tracks
affiliate link clicks for commission calculation. Click tracking includes
the affiliate_campaign_id for attribution.
"""
from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..launch_flags import require_beta_commerce
from ..models import Product, Purchase

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/purchases", tags=["purchases"], dependencies=[Depends(require_beta_commerce)])


@router.get("")
def get_purchases(
    request: Request,
    offset: int = 0,
    limit: int = 100,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    offset = max(0, min(offset, 1000))
    limit = max(1, min(limit, 200))

    rows = (
        session.query(Purchase, Product)
        .join(Product, Product.id == Purchase.product_id)
        .filter(Purchase.user_firebase_uid == uid)
        .order_by(Purchase.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    purchases = [
        {
            "id": p.id,
            "product_id": p.product_id,
            "quantity": p.quantity,
            "price_cents": p.price_cents,
            "currency": p.currency,
            "order_id": p.order_id,
            "created_at": p.created_at.isoformat() if p.created_at else None,
            "product": {
                "id": product.id,
                "name": product.name,
                "image_url": product.image_url,
                "price": product.price,
                "brand": product.brand,
            } if product else None,
        }
        for p, product in rows
    ]
    return {
        "purchases": purchases,
        "pagination": {"offset": offset, "limit": limit},
    }
