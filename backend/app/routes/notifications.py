from __future__ import annotations

import uuid
from typing import Any

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy import select

from ..db import SessionLocal
from ..firebase_auth import verify_firebase_token
from ..models_notifications import Notification


router = APIRouter(prefix="/api/notifications", tags=["notifications"])


class ListNotificationsResponse(BaseModel):
    notifications: list[dict[str, Any]]


class CreateNotificationRequest(BaseModel):
    # MVP: server can create notifications for the authenticated user.
    kind: str = Field(default="in-app")
    title: str = Field(default="New notification")
    body: str
    payload: dict[str, Any] | None = None


def _to_payload_str(payload: dict[str, Any] | None) -> str | None:
    if payload is None:
        return None
    import json

    return json.dumps(payload)


def _parse_payload_str(s: str | None) -> dict[str, Any] | None:
    if not s:
        return None
    import json

    try:
        return json.loads(s)
    except Exception:
        return None


@router.get("")
def list_notifications(request: Request, limit: int = 50) -> ListNotificationsResponse:
    decoded = verify_firebase_token(request)
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    limit = max(1, min(limit, 100))

    db = SessionLocal()
    try:
        stmt = (
            select(Notification)
            .where(Notification.user_firebase_uid == uid)
            .order_by(Notification.created_at.desc())
            .limit(limit)
        )
        rows = list(db.execute(stmt).scalars().all())

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
    finally:
        db.close()


class MarkReadRequest(BaseModel):
    notificationId: str = Field(min_length=1)


@router.post("/read")
def mark_read(payload: MarkReadRequest, request: Request) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    db = SessionLocal()
    try:
        n = (
            db.query(Notification)
            .filter(Notification.user_firebase_uid == uid)
            .filter(Notification.id == payload.notificationId)
            .first()
        )
        if not n:
            raise HTTPException(status_code=404, detail="Notification not found")

        n.read = 1
        db.commit()
        return {"ok": True}
    finally:
        db.close()


@router.post("/mvp/create")
def create_notification(payload: CreateNotificationRequest, request: Request) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    db = SessionLocal()
    try:
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
        db.add(n)
        db.commit()
        db.refresh(n)
        return {"id": n.id}
    finally:
        db.close()

