"""One-to-one friend chat REST API.

Direct messages are available only between accepted friends and are denied
across a block boundary. Messages are persisted so clients can load history
after reconnecting; the same conversation key works in either direction.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..models import DirectMessage, Friend, User
from ..models_notifications import Notification
from ..models_moderation import UserBlock

router = APIRouter(prefix="/api/chat", tags=["direct-chat"])


class SendDirectMessageRequest(BaseModel):
    toFirebaseUid: str = Field(min_length=1)
    message: str = Field(min_length=1, max_length=2000)


def _uid(request: Request) -> str:
    decoded = verify_firebase_token(request)
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")
    return uid


def _conversation_key(a: str, b: str) -> str:
    return ":".join(sorted((a, b)))


def _assert_friend_chat(session: Session, a: str, b: str) -> None:
    if a == b:
        raise HTTPException(status_code=400, detail="Cannot message yourself")

    blocked = session.query(UserBlock).filter(
        ((UserBlock.blocker_firebase_uid == a) & (UserBlock.blocked_firebase_uid == b))
        | ((UserBlock.blocker_firebase_uid == b) & (UserBlock.blocked_firebase_uid == a))
    ).first()
    if blocked:
        raise HTTPException(status_code=403, detail="This conversation is blocked")

    friends = session.query(Friend).filter(
        or_(
            (Friend.user_firebase_uid == a) & (Friend.friend_firebase_uid == b),
            (Friend.user_firebase_uid == b) & (Friend.friend_firebase_uid == a),
        )
    ).count()
    if friends < 2:
        raise HTTPException(status_code=403, detail="Direct chat is available only between friends")


def _message_payload(message: DirectMessage) -> dict[str, Any]:
    return {
        "id": message.id,
        "conversationId": message.conversation_key,
        "senderFirebaseUid": message.sender_firebase_uid,
        "recipientFirebaseUid": message.recipient_firebase_uid,
        "message": message.content,
        "createdAt": message.created_at.isoformat() if message.created_at else "",
    }


@router.get("/conversations/{friend_firebase_uid}/messages")
def list_direct_messages(
    friend_firebase_uid: str,
    request: Request,
    limit: int = Query(50, ge=1, le=200),
    before_id: int | None = Query(None, ge=1),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    uid = _uid(request)
    _assert_friend_chat(session, uid, friend_firebase_uid)

    key = _conversation_key(uid, friend_firebase_uid)
    stmt = (
        select(DirectMessage)
        .where(DirectMessage.conversation_key == key)
        .order_by(DirectMessage.id.desc())
        .limit(limit)
    )
    if before_id is not None:
        stmt = stmt.where(DirectMessage.id < before_id)

    rows = list(session.execute(stmt).scalars().all())
    rows.reverse()
    return {
        "conversationId": key,
        "messages": [_message_payload(row) for row in rows],
        "nextBeforeId": rows[0].id if rows else None,
    }


@router.post("/messages")
def send_direct_message(
    payload: SendDirectMessageRequest,
    request: Request,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    uid = _uid(request)
    recipient = payload.toFirebaseUid.strip()
    content = payload.message.strip()
    if not content:
        raise HTTPException(status_code=422, detail="Message cannot be empty")

    _assert_friend_chat(session, uid, recipient)

    recipient_user = session.query(User).filter(User.firebase_uid == recipient).first()
    if not recipient_user:
        raise HTTPException(status_code=404, detail="User not found")

    message = DirectMessage(
        conversation_key=_conversation_key(uid, recipient),
        sender_firebase_uid=uid,
        recipient_firebase_uid=recipient,
        content=content,
        created_at=datetime.now(timezone.utc),
    )
    session.add(message)

    # Keep an in-app notification for the recipient. This is intentionally
    # separate from push delivery so push preferences can be added later.
    sender = session.query(User).filter(User.firebase_uid == uid).first()
    sender_name = (sender.name if sender else None) or "A friend"
    session.add(Notification(
        id=f"chat-{message.id or 'pending'}-{datetime.now(timezone.utc).timestamp()}",
        user_firebase_uid=recipient,
        kind="direct_message",
        title=sender_name,
        body=content[:200],
        read=False,
        payload_json=None,
    ))
    session.commit()
    session.refresh(message)

    return {"message": _message_payload(message)}
