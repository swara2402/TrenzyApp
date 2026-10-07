"""User activity feed.

The client writes an activity row for every analytics event
(``POST /api/activity``) and reads the feed back on the History/Social
screens (``GET /api/activity``). Backed by the existing ``activity_events``
table.

Endpoints:
- GET  /api/activity — list the caller's activities (newest first)
- POST /api/activity — record one activity event
"""
from __future__ import annotations

from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..models import ActivityEvent, User

router = APIRouter(prefix="/api/activity", tags=["activity"])

_MAX_KIND = 64
_MAX_DESCRIPTION = 2000


class ActivityCreate(BaseModel):
    kind: str = Field(min_length=1, max_length=_MAX_KIND)
    description: str = Field(min_length=1, max_length=_MAX_DESCRIPTION)
    target_id: Optional[str] = Field(default=None, max_length=128)
    target_type: Optional[str] = Field(default=None, max_length=64)
    metadata_json: Optional[dict[str, Any]] = None


def _uid(request: Request) -> str:
    decoded = verify_firebase_token(request)
    uid = decoded.get("uid") or decoded.get("firebase_uid") or decoded.get("user_id")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")
    return str(uid)


def _iso(value: Any) -> Optional[str]:
    if value is None:
        return None
    try:
        return value.isoformat()
    except AttributeError:
        return str(value)


def _serialize(event: ActivityEvent, user: Optional[User]) -> dict[str, Any]:
    # The client reads this payload two ways: raw maps on the History screen
    # (`kind`, `created_at`) and SocialActivity.fromJson on the Social screen
    # (`type`, `createdAt`), so both key styles are emitted.
    created_at = _iso(event.created_at)
    payload: dict[str, Any] = {
        "id": str(event.id),
        "type": event.kind,
        "kind": event.kind,
        "description": event.description,
        "target_id": event.target_id,
        "target_type": event.target_type,
        "metadata": event.metadata_json or {},
        "metadata_json": event.metadata_json or {},
        "created_at": created_at,
        "createdAt": created_at,
        "isLoaded": True,
    }
    if user is not None:
        payload["user"] = {
            "id": event.user_firebase_uid,
            "firebaseUid": event.user_firebase_uid,
            "name": user.name,
            "displayName": user.name,
            "avatarUrl": user.avatar_url or "",
            "ageVerified": user.date_of_birth is not None,
        }
    return payload


@router.get("")
def list_activity(
    request: Request,
    offset: int = 0,
    limit: int = 20,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    uid = _uid(request)
    limit = max(1, min(limit, 100))
    offset = max(0, offset)

    stmt = (
        select(ActivityEvent)
        .where(ActivityEvent.user_firebase_uid == uid)
        .order_by(ActivityEvent.created_at.desc(), ActivityEvent.id.desc())
        .offset(offset)
        .limit(limit)
    )
    events = session.execute(stmt).scalars().all()

    user = session.execute(
        select(User).where(User.firebase_uid == uid)
    ).scalar_one_or_none()

    return {"activities": [_serialize(e, user) for e in events]}


@router.post("", status_code=201)
def create_activity(
    request: Request,
    body: ActivityCreate,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    uid = _uid(request)

    event = ActivityEvent(
        user_firebase_uid=uid,
        kind=body.kind.strip(),
        description=body.description.strip(),
        target_id=body.target_id,
        target_type=body.target_type,
        metadata_json=body.metadata_json,
    )
    session.add(event)
    session.commit()
    session.refresh(event)

    user = session.execute(
        select(User).where(User.firebase_uid == uid)
    ).scalar_one_or_none()

    return _serialize(event, user)
