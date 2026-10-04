"""Shopping cart endpoints.

One cart per user, created lazily on first add. Items reference products by ID
and include quantity and optional selected_size/selected_color. The cart
supports add, update quantity, remove, and clear operations. The get endpoint
returns the full cart with embedded product details.
"""
from __future__ import annotations

import logging
from decimal import Decimal
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..launch_flags import require_beta_commerce
from ..models import Cart, CartItem, Product, ProductImage
from .products import _product_payload

router = APIRouter(prefix="/api/cart", tags=["cart"], dependencies=[Depends(require_beta_commerce)])
logger = logging.getLogger(__name__)


# Dependency to get the current user's UID
def get_current_user_uid(request: Request) -> str:
    decoded = verify_firebase_token(request)
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing uid claim")
    return uid


def _get_or_create_cart(session: Session, uid: str):
    cart = session.query(Cart).filter(Cart.user_firebase_uid == uid).first()
    if not cart:
        cart = Cart(user_firebase_uid=uid)
        session.add(cart)
        session.flush()
    return cart


class AddCartItemRequest(BaseModel):
    product_id: str
    quantity: int = Field(default=1, ge=1, le=99)


class UpdateCartItemRequest(BaseModel):
    quantity: int = Field(ge=0, le=99) # Allow 0 to remove item


@router.get("")
def get_cart(session: Session = Depends(get_session), uid: str = Depends(get_current_user_uid)) -> dict[str, Any]:
    cart = (
        session.query(Cart)
        .filter(Cart.user_firebase_uid == uid)
        .first()
    )

    if not cart:
        return {
            "cart": None,
            "items": [],
            "subtotal": 0.0,
            "tax": 0.0,
            "total": 0.0,
        }

    cart_items = (
        session.query(CartItem)
        .filter(CartItem.cart_id == cart.id)
        .all()
    )

    # Batch-fetch all products in a single query (avoid N+1)
    product_ids = [ci.product_id for ci in cart_items]
    products_map = {}
    if product_ids:
        products_list = session.query(Product).filter(Product.id.in_(product_ids)).all()
        products_map = {p.id: p for p in products_list}

    # Batch-fetch all product images in a single query (avoid N+1)
    images_map: dict[str, list[str]] = {}
    if product_ids:
        all_images = session.query(ProductImage).filter(
            ProductImage.product_id.in_(product_ids)
        ).all()
        for img in all_images:
            images_map.setdefault(img.product_id, []).append(img.image_url)

    items_with_products = []
    subtotal = Decimal("0.00")
    for ci in cart_items:
        product = products_map.get(ci.product_id)
        if product:
            item_price = Decimal(str(product.price)) if product.price is not None else Decimal("0.00")
            item_total = item_price * ci.quantity
            subtotal += item_total
            items_with_products.append({
                "id": ci.id,
                "quantity": ci.quantity,
                "product": {
                    **_product_payload(product),
                    "images": images_map.get(product.id, []),
                },
            })
    
    # Assuming 0 tax for now, as per existing implementation
    tax = Decimal("0.00")
    total = subtotal + tax

    return {
        "cart": {
            "id": cart.id,
            "created_at": cart.created_at.isoformat() if cart.created_at else None,
        },
        "items": items_with_products,
        "subtotal": float(subtotal),
        "tax": float(tax),
        "total": float(total),
    }


@router.post("/items")
def add_cart_item(payload: AddCartItemRequest, session: Session = Depends(get_session), uid: str = Depends(get_current_user_uid)) -> dict[str, Any]:
    product = session.query(Product).filter(Product.id == payload.product_id).first()
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

    cart = _get_or_create_cart(session, uid)

    existing = session.query(CartItem).filter(
        CartItem.cart_id == cart.id,
        CartItem.product_id == payload.product_id,
    ).first()
    if existing:
        existing.quantity = min(existing.quantity + payload.quantity, 99)
        item = existing
    else:
        item = CartItem(
            cart_id=cart.id,
            user_firebase_uid=uid,
            product_id=payload.product_id,
            quantity=payload.quantity,
        )
        session.add(item)

    session.commit()
    session.refresh(item)

    return {
        "id": item.id,
        "product_id": item.product_id,
        "title": product.name,
        "price": float(product.price) if product.price is not None else 0.0,
        "quantity": item.quantity,
    }


@router.put("/items/{product_id}")
def update_cart_item(product_id: str, payload: UpdateCartItemRequest, session: Session = Depends(get_session), uid: str = Depends(get_current_user_uid)) -> dict[str, Any]:
    cart = session.query(Cart).filter(Cart.user_firebase_uid == uid).first()
    if not cart:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cart not found for user")

    item = (
        session.query(CartItem)
        .filter(CartItem.cart_id == cart.id, CartItem.product_id == product_id)
        .first()
    )
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cart item not found")

    if payload.quantity == 0:
        session.delete(item)
        session.commit()
        return {"message": "Item removed from cart"}
    else:
        item.quantity = payload.quantity
        session.commit()
        session.refresh(item)

        product = session.query(Product).filter(Product.id == item.product_id).first()

        return {
            "id": item.id,
            "product_id": item.product_id,
            "title": product.name if product else "",
            "price": float(product.price) if product and product.price is not None else 0.0,
            "quantity": item.quantity,
        }


@router.delete("/items/{product_id}")
def remove_cart_item(product_id: str, session: Session = Depends(get_session), uid: str = Depends(get_current_user_uid)) -> dict[str, Any]:
    cart = session.query(Cart).filter(Cart.user_firebase_uid == uid).first()
    if not cart:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cart not found for user")

    item = (
        session.query(CartItem)
        .filter(CartItem.cart_id == cart.id, CartItem.product_id == product_id)
        .first()
    )
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cart item not found")

    session.delete(item)
    session.commit()
    return {"message": "Item removed from cart"}


@router.delete("")
def clear_cart(session: Session = Depends(get_session), uid: str = Depends(get_current_user_uid)) -> dict[str, Any]:
    cart = session.query(Cart).filter(Cart.user_firebase_uid == uid).first()
    if cart:
        session.query(CartItem).filter(CartItem.cart_id == cart.id).delete()
        session.delete(cart)
        session.commit()
    return {"message": "Cart cleared"}