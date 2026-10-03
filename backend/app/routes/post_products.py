"""Product tagging for Inspiration posts."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..models import Post, PostProductTag, Product

router = APIRouter(prefix="/api/posts", tags=["post-product-tags"])


class ProductTagRequest(BaseModel):
    productIds: list[str] = Field(min_length=1, max_length=10)


def _uid(token: dict) -> str:
    uid = token.get("uid") or token.get("user_id")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")
    return uid


@router.get("/{post_id}/products")
def get_tagged_products(post_id: int, token: dict = Depends(verify_firebase_token), session: Session = Depends(get_session)):
    post = session.query(Post).filter(Post.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")

    rows = session.execute(
        select(Product).join(PostProductTag, PostProductTag.product_id == Product.id)
        .where(PostProductTag.post_id == post_id)
        .order_by(PostProductTag.id.asc())
    ).scalars().all()
    return {"products": [
        {"id": p.id, "name": p.name, "brand": p.brand, "price": p.price, "image_url": p.image_url}
        for p in rows
    ]}


@router.put("/{post_id}/products")
def set_tagged_products(
    post_id: int,
    payload: ProductTagRequest,
    token: dict = Depends(verify_firebase_token),
    session: Session = Depends(get_session),
):
    uid = _uid(token)
    post = session.query(Post).filter(Post.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    if post.user_firebase_uid != uid:
        raise HTTPException(status_code=403, detail="Only the post author can edit product tags")

    ids = list(dict.fromkeys(product_id.strip() for product_id in payload.productIds if product_id.strip()))
    if not ids:
        raise HTTPException(status_code=422, detail="At least one product is required")
    found = {
        row[0] for row in session.execute(select(Product.id).where(Product.id.in_(ids))).all()
    }
    missing = [product_id for product_id in ids if product_id not in found]
    if missing:
        raise HTTPException(status_code=400, detail=f"Products not found: {missing}")

    session.execute(delete(PostProductTag).where(PostProductTag.post_id == post_id))
    for product_id in ids:
        session.add(PostProductTag(post_id=post_id, product_id=product_id))
    session.commit()
    return {"ok": True, "productIds": ids}
