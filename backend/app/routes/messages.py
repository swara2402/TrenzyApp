"""Blend group chat messaging (REST endpoints).

Provides HTTP endpoints for sending and listing messages within blend groups.
The same functionality is also available via Socket.IO for real-time delivery.

- ``POST /api/blends/messages/send``: Send a message with optional product attachment.
- ``GET /api/blends/{group_id}/messages``: List messages with cursor-based pagination.

Messages are stored as BlendMessage records. The REST endpoints are used for
initial message loading (history) and as a fallback when Socket.IO is unavailable.
Real-time new messages are delivered via Socket.IO ``message_created`` events.
"""

from __future__ import annotations

import datetime
import logging
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..auth_helpers import require_blend_member_sync
from ..models import BlendMessage

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/blends", tags=["blend-messages"])


class SendMessageRequest(BaseModel):
    groupId: str = Field(min_length=1)
    message: str = Field(min_length=1, max_length=2000)
    attachedProductId: Optional[str] = None
    attachedProductTitle: Optional[str] = None
    attachedProductImage: Optional[str] = None
    attachedProductPrice: Optional[str] = None


@router.post("/messages/send")
def send_message(payload: SendMessageRequest, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    """Send a message to a blend group.
    
    AUTHORIZATION: User must be a member of the blend.
    """
    decoded = verify_firebase_token(request)
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    sender_name = decoded.get("name") or decoded.get("email") or "Guest"
    blend_id = payload.groupId.strip()

    # AUTHORIZATION: Verify membership using central helper
    if not require_blend_member_sync(uid, blend_id, session):
        raise HTTPException(status_code=403, detail="Not a member of this blend")

    msg = BlendMessage(
        blend_id=blend_id,
        sender_firebase_uid=uid,
        sender_name=sender_name,
        content=payload.message.strip(),
        created_at=datetime.datetime.now(datetime.timezone.utc),
    )
    session.add(msg)
    session.commit()
    session.refresh(msg)

    return {
        "message": {
            "id": msg.id,
            "groupId": msg.blend_id,
            "senderId": msg.sender_firebase_uid,
            "senderName": msg.sender_name,
            "message": msg.content,
            "attachedProductId": msg.attached_product_id,
            "attachedProductTitle": msg.attached_product_title,
            "attachedProductImage": msg.attached_product_image,
            "attachedProductPrice": msg.attached_product_price,
            "createdAt": msg.created_at.isoformat() if msg.created_at else "",
        }
    }


@router.get("/{group_id}/messages", response_model=None)
def list_messages(
    group_id: str,
    request: Request,
    limit: int = 50,
    cursor: Optional[int] = None,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    """List messages in a blend group.
    
    AUTHORIZATION: User must be a member of the blend.
    """
    decoded = verify_firebase_token(request)
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    limit = max(1, min(limit, 200))

    # AUTHORIZATION: Verify membership using central helper
    if not require_blend_member_sync(uid, group_id, session):
        raise HTTPException(status_code=403, detail="Not a member of this blend")

    q = (
        select(BlendMessage)
        .where(BlendMessage.blend_id == group_id)
        .order_by(BlendMessage.id.desc())
    )
    if cursor is not None:
        q = q.where(BlendMessage.id < cursor)

    rows = list(session.execute(q.limit(limit)).scalars().all())
    rows.reverse()  # oldest->newest

    messages = [
        {
            "id": r.id,
            "groupId": r.blend_id,
            "senderId": r.sender_firebase_uid,
            "senderName": r.sender_name,
            "message": r.content,
            "createdAt": r.created_at.isoformat() if r.created_at else "",
        }
        for r in rows
    ]

    next_cursor = messages[-1]["id"] if messages else None

    return {
        "messages": messages,
        "nextCursor": next_cursor,
    }
