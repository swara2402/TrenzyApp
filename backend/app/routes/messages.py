from __future__ import annotations

import datetime
from typing import Any, Optional


from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy import select

from ..db import SessionLocal
from ..firebase_auth import verify_firebase_token
# Note: GroupMessage model is added in backend/app/models.py during Phase 3.
from ..models import GroupMessage



router = APIRouter(prefix="/api/groups", tags=["group-messages"])


class SendMessageRequest(BaseModel):
    groupId: str = Field(min_length=1)
    message: str = Field(min_length=1, max_length=2000)
    # Product sharing support
    attachedProductId: Optional[str] = None

    attachedProductTitle: Optional[str] = None

    attachedProductImage: Optional[str] = None

    attachedProductPrice: Optional[str] = None



@router.post("/messages/send")
def send_message(payload: SendMessageRequest, request: Request) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    db = SessionLocal()
    try:
        sender_name = decoded.get("name") or decoded.get("email") or "Guest"

        msg = GroupMessage(
            group_id=payload.groupId.strip(),
            sender_firebase_uid=uid,
            sender_name=sender_name,
            message=payload.message.strip(),
            attached_product_id=payload.attachedProductId,
            attached_product_title=payload.attachedProductTitle,
            attached_product_image=payload.attachedProductImage,
            attached_product_price=payload.attachedProductPrice,
            created_at=datetime.datetime.now(datetime.timezone.utc),
        )
        db.add(msg)
        db.commit()
        db.refresh(msg)

        return {
            "message": {
                "id": msg.id,
                "groupId": msg.group_id,
                "senderId": msg.sender_firebase_uid,
                "senderName": msg.sender_name,
                "message": msg.message,
                "attachedProductId": msg.attached_product_id,
                "attachedProductTitle": msg.attached_product_title,
                "attachedProductImage": msg.attached_product_image,
                "attachedProductPrice": msg.attached_product_price,
                "createdAt": msg.created_at.isoformat() if msg.created_at else "",
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to send message: {e}")
    finally:
        db.close()


@router.get("/{group_id}/messages", response_model=None)
def list_messages(group_id: str, limit: int = 50, cursor: Optional[int] = None, request: Request = None) -> dict[str, Any]:
    decoded = verify_firebase_token(request)

    uid = decoded.get("uid")

    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    limit = max(1, min(limit, 200))

    db = SessionLocal()
    try:
        # Simple cursor strategy: cursor = last_message_id
        q = select(GroupMessage).where(GroupMessage.group_id == group_id).order_by(GroupMessage.id.desc())
        if cursor is not None:
            q = q.where(GroupMessage.id < cursor)

        rows = list(db.execute(q.limit(limit)).scalars().all())
        rows.reverse()  # oldest->newest

        messages = [
            {
                "id": r.id,
                "groupId": r.group_id,
                "senderId": r.sender_firebase_uid,
                "senderName": r.sender_name,
                "message": r.message,
                "attachedProductId": r.attached_product_id,
                "attachedProductTitle": r.attached_product_title,
                "attachedProductImage": r.attached_product_image,
                "attachedProductPrice": r.attached_product_price,
                "createdAt": r.created_at.isoformat() if r.created_at else "",
            }
            for r in rows
        ]

        # Cursor strategy: when ordering oldest->newest for the response,
        # we return cursor = id of the first element returned.
        # Client can pass that cursor to fetch older messages.
        next_cursor = messages[0]["id"] if messages else None

        return {
            "messages": messages,
            "nextCursor": next_cursor,
        }

    finally:
        db.close()

