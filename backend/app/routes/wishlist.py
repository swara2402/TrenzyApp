"""Wishlist management endpoints.

Provides CRUD operations for the user's product wishlist:

- ``GET /api/wishlist``: Get all wishlist item IDs (with pagination).
- ``POST /api/wishlist``: Full replacement sync (sends all IDs, replaces server state).
- ``POST /api/wishlist/add``: Add a single product (idempotent — no duplicate).
- ``DELETE /api/wishlist/{product_id}``: Remove a product.

The wishlist stores only product IDs, not full product objects. The Flutter client
fetches full product details separately via ``/api/products/batch``. This keeps
the wishlist lightweight and avoids stale product data.
"""

from __future__ import annotations

import logging

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..models import Cart, CartItem, Product, Wishlist

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["wishlist"])

# Hard cap on wishlist size — keeps the full-replacement sync bounded.
_MAX_WISHLIST_ITEMS = 500


class WishlistUpdateRequest(BaseModel):
    productIds: list[str]


@router.get("/wishlist")
def get_wishlist(request: Request, offset: int = 0, limit: int = 100, session: Session = Depends(get_session)) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = decoded.get("uid")
    if not firebase_uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    limit = max(1, min(limit, 500))
    offset = max(0, offset)

    total = session.query(func.count(Wishlist.id)).filter(Wishlist.user_firebase_uid == firebase_uid).scalar() or 0
    items = (
        session.query(Wishlist)
        .filter(Wishlist.user_firebase_uid == firebase_uid)
        .order_by(Wishlist.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    product_ids = [item.product_id for item in items]
    return {
        "productIds": product_ids,
        "pagination": {
            "offset": offset,
            "limit": limit,
            "total": total,
            "hasMore": (offset + limit) < total,
        },
    }


@router.post("/wishlist")
def set_wishlist(payload: WishlistUpdateRequest, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = decoded.get("uid")
    if not firebase_uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    if len(payload.productIds) > _MAX_WISHLIST_ITEMS:
        raise HTTPException(
            status_code=400,
            detail=f"Wishlist cannot contain more than {_MAX_WISHLIST_ITEMS} items",
        )

    # Dedupe while preserving client order — the unique constraint on
    # (user, product_id) would otherwise reject duplicate inserts.
    seen: set[str] = set()
    unique_ids = [pid for pid in payload.productIds if not (pid in seen or seen.add(pid))]

    # Validate all referenced products exist so the sync can't insert
    # dangling rows (clear 400 instead of a raw FK IntegrityError).
    existing_ids = set()
    if unique_ids:
        existing_ids = {
            row[0]
            for row in session.query(Product.id).filter(Product.id.in_(unique_ids)).all()
        }
    missing = [pid for pid in unique_ids if pid not in existing_ids]
    if missing:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown product id(s): {', '.join(missing[:10])}",
        )

    # Atomic replacement: delete old items then insert new ones in single transaction
    session.query(Wishlist).filter(
        Wishlist.user_firebase_uid == firebase_uid
    ).delete()

    for p_id in unique_ids:
        session.add(Wishlist(user_firebase_uid=firebase_uid, product_id=p_id))

    session.commit()
    return {"productIds": unique_ids}


class WishlistAddRequest(BaseModel):
    productId: str


@router.post("/wishlist/add")
def add_wishlist_item(payload: WishlistAddRequest, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = decoded.get("uid")
    if not firebase_uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    # Clear 404 instead of a raw FK error when the product doesn't exist.
    product = session.query(Product.id).filter(Product.id == payload.productId).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    existing = session.query(Wishlist).filter(
        Wishlist.user_firebase_uid == firebase_uid,
        Wishlist.product_id == payload.productId,
    ).first()
    if not existing:
        try:
            session.add(Wishlist(user_firebase_uid=firebase_uid, product_id=payload.productId))
            session.commit()
        except IntegrityError:
            # Concurrent add from another device — the item is in the
            # wishlist either way; treat as idempotent success.
            session.rollback()
    return {"status": "added"}


@router.post("/wishlist/{product_id}/move-to-cart")
def move_wishlist_item_to_cart(product_id: str, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    """One-step "move to cart": adds the product to the user's cart (quantity 1,
    or bumps an existing row) and removes it from the wishlist atomically."""
    decoded = verify_firebase_token(request)
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    product = session.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    wish = session.query(Wishlist).filter(
        Wishlist.user_firebase_uid == uid,
        Wishlist.product_id == product_id,
    ).first()
    if not wish:
        raise HTTPException(
            status_code=404,
            detail="Product is not in your wishlist",
        )

    cart = session.query(Cart).filter(Cart.user_firebase_uid == uid).first()
    if not cart:
        cart = Cart(user_firebase_uid=uid)
        session.add(cart)
        session.flush()

    item = session.query(CartItem).filter(
        CartItem.cart_id == cart.id,
        CartItem.product_id == product_id,
    ).first()
    if item:
        item.quantity += 1
    else:
        session.add(CartItem(cart_id=cart.id, user_firebase_uid=uid, product_id=product_id, quantity=1))

    session.delete(wish)
    session.commit()

    return {
        "status": "moved",
        "cartItem": {
            "product_id": product_id,
            "quantity": item.quantity if item else 1,
        },
    }


@router.delete("/wishlist/{product_id}")
def remove_wishlist_item(product_id: str, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = decoded.get("uid")
    if not firebase_uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    session.query(Wishlist).filter(
        Wishlist.user_firebase_uid == firebase_uid,
        Wishlist.product_id == product_id,
    ).delete()
    session.commit()
    return {"status": "removed"}