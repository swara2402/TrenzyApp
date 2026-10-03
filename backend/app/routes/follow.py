"""Follow/unfollow user relationships.

Implements a Twitter-style follow model: follow another user, unfollow,
list followers, and list following. Follow relationships are bidirectional
(follower + following) and are used by the feed algorithm to boost content
from followed users.
"""
from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..models import Follow, User
from ..models_moderation import UserBlock

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/follow", tags=["follow"])


def _get_uid(decoded_token: dict[str, Any]) -> str:
    uid = decoded_token.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")
    return uid


class FollowRequest(BaseModel):
    target_firebase_uid: str


@router.post("")
def follow_user(payload: FollowRequest, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    uid = _get_uid(decoded)
    target_uid = payload.target_firebase_uid
    if uid == target_uid:
        raise HTTPException(status_code=400, detail="Cannot follow yourself")

    if session.query(UserBlock).filter(
        ((UserBlock.blocker_firebase_uid == uid) & (UserBlock.blocked_firebase_uid == target_uid))
        | ((UserBlock.blocker_firebase_uid == target_uid) & (UserBlock.blocked_firebase_uid == uid))
    ).first():
        raise HTTPException(status_code=403, detail="This social relationship is blocked")

    existing = session.query(Follow).filter(
        Follow.follower_firebase_uid == uid,
        Follow.following_firebase_uid == target_uid,
    ).first()
    if existing:
        return {"status": "already_following"}

    target_user = session.query(User).filter(User.firebase_uid == target_uid).first()
    if not target_user:
        raise HTTPException(status_code=404, detail="User not found")

    session.add(Follow(follower_firebase_uid=uid, following_firebase_uid=target_uid))
    session.commit()
    return {"status": "following"}


@router.get("/followers")
def get_followers(
    request: Request,
    offset: int = 0,
    limit: int = 50,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    uid = _get_uid(decoded)

    limit = max(1, min(limit, 200))
    offset = max(0, offset)

    rows = (
        session.query(Follow, User)
        .join(User, User.firebase_uid == Follow.follower_firebase_uid)
        .filter(Follow.following_firebase_uid == uid)
        .filter(~Follow.follower_firebase_uid.in_(session.query(UserBlock.blocker_firebase_uid).filter(UserBlock.blocked_firebase_uid == uid)))
        .filter(~Follow.follower_firebase_uid.in_(session.query(UserBlock.blocked_firebase_uid).filter(UserBlock.blocker_firebase_uid == uid)))
        .order_by(Follow.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    followers = [
        {
            "firebase_uid": f.follower_firebase_uid,
            "name": u.name if u else None,
            "avatar_url": u.avatar_url if u else None,
            "created_at": f.created_at.isoformat() if f.created_at else None,
        }
        for f, u in rows
    ]
    return {"followers": followers}


@router.get("/following")
def get_following(
    request: Request,
    offset: int = 0,
    limit: int = 50,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    uid = _get_uid(decoded)

    limit = max(1, min(limit, 200))
    offset = max(0, offset)

    rows = (
        session.query(Follow, User)
        .join(User, User.firebase_uid == Follow.following_firebase_uid)
        .filter(Follow.follower_firebase_uid == uid)
        .filter(~Follow.following_firebase_uid.in_(session.query(UserBlock.blocker_firebase_uid).filter(UserBlock.blocked_firebase_uid == uid)))
        .filter(~Follow.following_firebase_uid.in_(session.query(UserBlock.blocked_firebase_uid).filter(UserBlock.blocker_firebase_uid == uid)))
        .order_by(Follow.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    following = [
        {
            "firebase_uid": f.following_firebase_uid,
            "name": u.name if u else None,
            "avatar_url": u.avatar_url if u else None,
            "created_at": f.created_at.isoformat() if f.created_at else None,
        }
        for f, u in rows
    ]
    return {"following": following}


@router.get("/status")
def get_follow_status(request: Request, target: str, session: Session = Depends(get_session)) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    uid = _get_uid(decoded)

    if session.query(UserBlock).filter(
        ((UserBlock.blocker_firebase_uid == uid) & (UserBlock.blocked_firebase_uid == target))
        | ((UserBlock.blocker_firebase_uid == target) & (UserBlock.blocked_firebase_uid == uid))
    ).first():
        return {"isFollowing": False}

    follows = session.query(Follow).filter(
        Follow.follower_firebase_uid == uid,
        Follow.following_firebase_uid == target,
    ).first() is not None
    return {"isFollowing": follows}


@router.delete("/{target_firebase_uid}")
def unfollow_user(target_firebase_uid: str, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    uid = _get_uid(decoded)

    result = session.query(Follow).filter(
        Follow.follower_firebase_uid == uid,
        Follow.following_firebase_uid == target_firebase_uid,
    ).delete()
    session.commit()
    if result == 0:
        raise HTTPException(status_code=404, detail="Follow relationship not found")
    return {"status": "unfollowed"}