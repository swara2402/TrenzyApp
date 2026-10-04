"""Push notification management.

Stores notification preferences (per-type toggles, quiet hours) and device
tokens for FCM push delivery. Notifications are created server-side when
events occur (new message, blend invite, etc.) and can be listed/read/
deleted via REST. Supports FCM token registration and removal.
"""
from __future__ import annotations

import json
import logging
import time
import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..auth_deps import get_current_user, require_admin
from ..models_notifications import Notification

logger = logging.getLogger(__name__)

_notif_metrics = {
    "created": 0,
    "push_attempted": 0,
    "push_succeeded": 0,
    "push_failed": 0,
    "read_marked": 0,
}


router = APIRouter(prefix="/api/notifications", tags=["notifications"])

# Rate limiting for self-send push notifications: max 10 per minute per user
# to prevent abuse or accidental DoS via API
_push_self_send_rate: dict[str, list[float]] = {}
_PUSH_RATE_LIMIT = 10
_PUSH_RATE_WINDOW = 60.0


def _check_push_self_send_rate(user_id: str) -> bool:
    """Check if self-send push is allowed. Returns True if allowed, False if rate-limited."""
    now = time.time()
    timestamps = _push_self_send_rate.setdefault(user_id, [])
    window_start = now - _PUSH_RATE_WINDOW
    timestamps[:] = [t for t in timestamps if t > window_start]
    if len(timestamps) >= _PUSH_RATE_LIMIT:
        return False
    timestamps.append(now)
    return True


class ListNotificationsResponse(BaseModel):
    notifications: list[dict[str, Any]]


class CreateNotificationRequest(BaseModel):
    kind: str = Field(default="in-app")
    title: str = Field(default="New notification")
    body: str
    payload: dict[str, Any] | None = None


def _to_payload_str(payload: dict[str, Any] | None) -> str | None:
    if payload is None:
        return None
    return json.dumps(payload)


def _parse_payload_str(s: str | None) -> dict[str, Any] | None:
    if not s:
        return None
    try:
        return json.loads(s)
    except (json.JSONDecodeError, TypeError) as e:
        logger.warning("Failed to decode notification payload JSON: %s", e)
        return None


@router.get("")
def list_notifications(request: Request, limit: int = 50, offset: int = 0, session: Session = Depends(get_session)) -> ListNotificationsResponse:
    decoded = verify_firebase_token(request)
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    limit = max(1, min(limit, 100))
    offset = max(0, offset)

    stmt = (
        select(Notification)
        .where(Notification.user_firebase_uid == uid)
        .order_by(Notification.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    rows = list(session.execute(stmt).scalars().all())

    notifications = []
    for n in rows:
        notifications.append(
            {
                "id": n.id,
                "kind": n.kind,
                "title": n.title,
                "body": n.body,
                "read": bool(n.read),
                "createdAt": n.created_at.isoformat() if n.created_at else "",
                "payload": _parse_payload_str(getattr(n, "payload_json", None)),
            }
        )

    return ListNotificationsResponse(notifications=notifications)


class MarkReadRequest(BaseModel):
    notificationId: str = Field(min_length=1)


@router.post("/read")
def mark_read(payload: MarkReadRequest, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    n = (
        session.query(Notification)
        .filter(Notification.user_firebase_uid == uid)
        .filter(Notification.id == payload.notificationId)
        .first()
    )
    if not n:
        raise HTTPException(status_code=404, detail="Notification not found")

    n.read = 1
    session.commit()
    return {"ok": True}


@router.post("/read-all")
def mark_all_read(request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    session.query(Notification).filter(
        Notification.user_firebase_uid == uid,
        Notification.read.is_(False),
    ).update({"read": True})
    session.commit()
    return {"ok": True}


@router.get("/unread-count")
def unread_count(request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    count = session.query(Notification).filter(
        Notification.user_firebase_uid == uid,
        Notification.read == 0,
    ).count()
    return {"unreadCount": count}


@router.post("/mvp/create")
def create_notification(
    payload: CreateNotificationRequest, request: Request, session: Session = Depends(get_session)
) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    nid = f"ntf-{uuid.uuid4().hex}"
    n = Notification(
        id=nid,
        user_firebase_uid=uid,
        kind=payload.kind,
        title=payload.title,
        body=payload.body,
        read=0,
        payload_json=_to_payload_str(payload.payload),
    )
    session.add(n)
    session.commit()
    session.refresh(n)
    return {"id": n.id}


# --- Push notification support ---

class PushTokenRequest(BaseModel):
    token: str
    platform: str = Field(default="fcm", pattern="^(fcm|apns)$")


class PushSendRequest(BaseModel):
    userFirebaseUid: str
    title: str
    body: str
    payload: dict[str, Any] | None = None


@router.post("/push/register")
def register_push_token(
    payload: PushTokenRequest,
    request: Request,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    from ..models import PushDevice

    existing = session.query(PushDevice).filter(
        PushDevice.user_firebase_uid == uid,
        PushDevice.token == payload.token,
    ).first()
    if existing:
        pass  # Already registered
    else:
        session.add(PushDevice(
            user_firebase_uid=uid,
            token=payload.token,
            platform=payload.platform,
        ))
    session.commit()
    return {"ok": True}


@router.post("/push/send")
def send_push(
    payload: PushSendRequest,
    request: Request,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    sender_uid = decoded.get("uid")
    if not sender_uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    is_self_send = payload.userFirebaseUid == sender_uid
    
    # Rate limit self-sends to prevent abuse (sending to self is unusual)
    if is_self_send:
        if not _check_push_self_send_rate(sender_uid):
            raise HTTPException(
                status_code=429,
                detail=f"Too many self-send push notifications. Max {_PUSH_RATE_LIMIT} per {_PUSH_RATE_WINDOW:.0f}s"
            )
    else:
        # Verify friendship before sending to another user
        from ..models import Friend
        are_friends = session.query(Friend).filter(
            Friend.user_firebase_uid == sender_uid,
            Friend.friend_firebase_uid == payload.userFirebaseUid,
        ).first()
        if not are_friends:
            raise HTTPException(status_code=403, detail="You can only send push notifications to friends")

    # Validate content length to prevent spam
    if len(payload.title) > 100:
        raise HTTPException(status_code=400, detail="Title too long (max 100 chars)")
    if len(payload.body) > 500:
        raise HTTPException(status_code=400, detail="Body too long (max 500 chars)")

    from ..models import PushDevice

    devices = session.query(PushDevice).filter(
        PushDevice.user_firebase_uid == payload.userFirebaseUid,
    ).all()
    if not devices:
        return {"ok": True, "sent": 0}

    sent = 0
    for device in devices:
        try:
            from firebase_admin import messaging
            message = messaging.Message(
                notification=messaging.Notification(
                    title=payload.title,
                    body=payload.body,
                ),
                data=payload.payload or {},
                token=device.token,
            )
            messaging.send(message)
            sent += 1
        except Exception as e:
            logger.warning("Push send failed for %s: %s", device.token, e)

    return {"ok": True, "sent": sent}


@router.get("/metrics")
def notification_metrics(user: dict = Depends(require_admin)) -> dict:
    """Ops visibility into notification volume and push outcomes."""
    return dict(_notif_metrics)
