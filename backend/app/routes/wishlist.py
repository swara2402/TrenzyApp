from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

from ..db import SessionLocal
from ..firebase_auth import verify_firebase_token
from ..models import WishlistItem

router = APIRouter(prefix="/api", tags=["wishlist"])


class WishlistUpdateRequest(BaseModel):
    productIds: list[str]


@router.get("/wishlist")
def get_wishlist(request: Request) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = decoded.get("uid")
    if not firebase_uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    db = SessionLocal()
    try:
        items = db.query(WishlistItem).filter(WishlistItem.user_firebase_uid == firebase_uid).all()
        product_ids = [item.product_id for item in items]
        return {"productIds": product_ids}
    finally:
        db.close()


@router.post("/wishlist")
def set_wishlist(payload: WishlistUpdateRequest, request: Request) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = decoded.get("uid")
    if not firebase_uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    db = SessionLocal()
    try:
        # Delete old wishlist items
        db.query(WishlistItem).filter(WishlistItem.user_firebase_uid == firebase_uid).delete()
        
        # Insert new wishlist items
        for p_id in payload.productIds:
            db.add(WishlistItem(user_firebase_uid=firebase_uid, product_id=p_id))
        
        db.commit()
        return {"productIds": payload.productIds}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to update wishlist: {e}")
    finally:
        db.close()


