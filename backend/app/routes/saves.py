"""Saved items (bookmarks) for posts and products.

Endpoints:
- GET /api/saves — list user's saves with embedded post/product data
- POST /api/saves — save a post or product (idempotent, returns already_saved)
- DELETE /api/saves/{id} — remove a save

Saves can reference either a post_id or a product_id. The GET endpoint
batch-loads referenced posts and products to avoid N+1 queries. The POST
endpoint checks for existing saves before inserting (idempotent behavior).
"""
from __future__ import annotations

import logging
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..models import Post, Product, Save

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/saves", tags=["saves"])


class SaveRequest(BaseModel):
    post_id: Optional[int] = None
    product_id: Optional[str] = None


@router.get("")
def get_saves(request: Request, offset: int = 0, limit: int = 20, session: Session = Depends(get_session)) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    uid = decoded.get("uid") or decoded.get("firebase_uid") or decoded.get("user_id")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    limit = max(1, min(limit, 100))
    offset = max(0, offset)

    stmt = (
        select(Save)
        .where(Save.user_firebase_uid == uid)
        .order_by(Save.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    items = session.execute(stmt).scalars().all()

    post_ids = [s.post_id for s in items if s.post_id]
    product_ids = [s.product_id for s in items if s.product_id]

    posts_by_id = {}
    if post_ids:
        posts = session.execute(select(Post).where(Post.id.in_(post_ids))).scalars().all()
        posts_by_id = {post.id: post for post in posts}

    products_by_id = {}
    if product_ids:
        products = session.execute(select(Product).where(Product.id.in_(product_ids))).scalars().all()
        products_by_id = {product.id: product for product in products}

    results = []
    for s in items:
        entry = {
            "id": s.id,
            "post_id": s.post_id,
            "product_id": s.product_id,
            "created_at": s.created_at.isoformat() if s.created_at else None,
        }
        if s.post_id:
            post = posts_by_id.get(s.post_id)
            if post:
                entry["post"] = {
                    "id": post.id,
                    "user_firebase_uid": post.user_firebase_uid,
                    "user_name": post.user_name,
                    "content": post.content,
                    "attachment": post.attachment,
                    "created_at": post.created_at.isoformat() if post.created_at else None,
                }
        if s.product_id:
            product = products_by_id.get(s.product_id)
            if product:
                entry["product"] = {
                    "id": product.id,
                    "title": product.name,
                    "image_url": product.image_url,
                    "price": product.price,
                    "brand_name": product.brand,
                }
        results.append(entry)
    return {"saves": results}


@router.post("")
def create_save(payload: SaveRequest, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    uid = decoded.get("uid") or decoded.get("firebase_uid") or decoded.get("user_id")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    if not payload.post_id and not payload.product_id:
        raise HTTPException(status_code=400, detail="Must provide post_id or product_id")

    existing = session.query(Save).filter(
        Save.user_firebase_uid == uid,
        Save.post_id == payload.post_id,
        Save.product_id == payload.product_id,
    ).first()
    if existing:
        return {"status": "already_saved", "id": existing.id}

    if payload.post_id:
        post = session.query(Post).filter(Post.id == payload.post_id).first()
        if not post:
            raise HTTPException(status_code=404, detail="Post not found")
    if payload.product_id:
        product = session.query(Product).filter(Product.id == payload.product_id).first()
        if not product:
            raise HTTPException(status_code=404, detail="Product not found")

    save = Save(
        user_firebase_uid=uid,
        post_id=payload.post_id,
        product_id=payload.product_id,
    )
    session.add(save)
    session.commit()
    session.refresh(save)
    return {"status": "saved", "id": save.id}


@router.delete("/{save_id}")
def delete_save(save_id: int, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    uid = decoded.get("uid") or decoded.get("firebase_uid") or decoded.get("user_id")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    save = session.query(Save).filter(Save.id == save_id, Save.user_firebase_uid == uid).first()
    if not save:
        raise HTTPException(status_code=404, detail="Save not found")
    session.delete(save)
    session.commit()
    return {"status": "unsaved"}
