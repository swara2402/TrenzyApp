"""Community product reviews.

Reviews are independent from checkout because Trenzy is affiliate-first at beta.
A user may maintain one review per product and update it later.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..models import Product, ProductReview, User

router = APIRouter(prefix="/api/products", tags=["product-reviews"])


class ReviewRequest(BaseModel):
    rating: int = Field(ge=1, le=5)
    title: str | None = Field(default=None, max_length=120)
    body: str = Field(min_length=1, max_length=2000)


def _uid(token: dict) -> str:
    uid = token.get("uid") or token.get("user_id")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")
    return uid


def _review_payload(review: ProductReview, user: User | None) -> dict:
    return {
        "id": review.id,
        "productId": review.product_id,
        "userFirebaseUid": review.user_firebase_uid,
        "userName": (user.name if user else None) or "User",
        "rating": review.rating,
        "title": review.title,
        "body": review.body,
        "createdAt": review.created_at.isoformat() if review.created_at else "",
        "updatedAt": review.updated_at.isoformat() if review.updated_at else "",
    }


@router.get("/{product_id}/reviews")
def list_reviews(
    product_id: str,
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    session: Session = Depends(get_session),
) -> dict:
    product = session.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    reviews = session.execute(
        select(ProductReview)
        .where(ProductReview.product_id == product_id)
        .order_by(ProductReview.created_at.desc())
        .offset(offset)
        .limit(limit)
    ).scalars().all()
    uids = {review.user_firebase_uid for review in reviews}
    users = {
        user.firebase_uid: user
        for user in session.execute(select(User).where(User.firebase_uid.in_(uids))).scalars().all()
    } if uids else {}

    stats = session.execute(
        select(func.count(ProductReview.id), func.avg(ProductReview.rating))
        .where(ProductReview.product_id == product_id)
    ).one()
    return {
        "reviews": [_review_payload(review, users.get(review.user_firebase_uid)) for review in reviews],
        "summary": {
            "count": int(stats[0] or 0),
            "averageRating": round(float(stats[1] or 0), 2),
        },
    }


@router.put("/{product_id}/reviews/me")
def upsert_review(
    product_id: str,
    payload: ReviewRequest,
    token: dict = Depends(verify_firebase_token),
    session: Session = Depends(get_session),
) -> dict:
    uid = _uid(token)
    product = session.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    review = session.query(ProductReview).filter(
        ProductReview.product_id == product_id,
        ProductReview.user_firebase_uid == uid,
    ).first()
    if review is None:
        review = ProductReview(product_id=product_id, user_firebase_uid=uid)
        session.add(review)

    review.rating = payload.rating
    review.title = payload.title.strip() if payload.title and payload.title.strip() else None
    review.body = payload.body.strip()
    if not review.body:
        raise HTTPException(status_code=422, detail="Review body cannot be empty")
    session.commit()
    session.refresh(review)

    user = session.query(User).filter(User.firebase_uid == uid).first()
    return {"review": _review_payload(review, user)}


@router.delete("/{product_id}/reviews/me")
def delete_review(
    product_id: str,
    token: dict = Depends(verify_firebase_token),
    session: Session = Depends(get_session),
) -> dict:
    uid = _uid(token)
    review = session.query(ProductReview).filter(
        ProductReview.product_id == product_id,
        ProductReview.user_firebase_uid == uid,
    ).first()
    if not review:
        raise HTTPException(status_code=404, detail="Review not found")
    session.delete(review)
    session.commit()
    return {"ok": True}
