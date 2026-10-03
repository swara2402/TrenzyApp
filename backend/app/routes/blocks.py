"""User safety block endpoints.

A block is a bilateral safety boundary: the blocked relationship prevents
new follows/friend requests and removes any existing follow/friend edges.
"""

from __future__ import annotations

import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ..auth_deps import get_current_user
from ..db import get_session
from ..models import Follow, Friend, FriendRequest, User
from ..models_moderation import UserBlock

router = APIRouter(prefix="/api/blocks", tags=["safety"])


class BlockRequest(BaseModel):
    targetFirebaseUid: str = Field(min_length=1, max_length=128)


def _uid(user: dict[str, Any]) -> str:
    value = user.get("uid")
    if not value:
        raise HTTPException(status_code=401, detail="Missing uid claim")
    return value


def is_blocked(session: Session, a: str, b: str) -> bool:
    return (
        session.query(UserBlock)
        .filter(
            ((UserBlock.blocker_firebase_uid == a) & (UserBlock.blocked_firebase_uid == b))
            | ((UserBlock.blocker_firebase_uid == b) & (UserBlock.blocked_firebase_uid == a))
        )
        .first()
        is not None
    )


@router.post("")
def block_user(
    payload: BlockRequest,
    user: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    blocker = _uid(user)
    target = payload.targetFirebaseUid.strip()
    if blocker == target:
        raise HTTPException(status_code=400, detail="Cannot block yourself")
    if not session.query(User).filter(User.firebase_uid == target).first():
        raise HTTPException(status_code=404, detail="User not found")

    existing = session.query(UserBlock).filter(
        UserBlock.blocker_firebase_uid == blocker,
        UserBlock.blocked_firebase_uid == target,
    ).first()
    if not existing:
        session.add(UserBlock(
            id=str(uuid.uuid4()),
            blocker_firebase_uid=blocker,
            blocked_firebase_uid=target,
        ))

    # A block immediately severs the social relationships it supersedes.
    session.query(Follow).filter(
        ((Follow.follower_firebase_uid == blocker) & (Follow.following_firebase_uid == target))
        | ((Follow.follower_firebase_uid == target) & (Follow.following_firebase_uid == blocker))
    ).delete(synchronize_session=False)
    session.query(Friend).filter(
        ((Friend.user_firebase_uid == blocker) & (Friend.friend_firebase_uid == target))
        | ((Friend.user_firebase_uid == target) & (Friend.friend_firebase_uid == blocker))
    ).delete(synchronize_session=False)
    session.query(FriendRequest).filter(
        ((FriendRequest.from_firebase_uid == blocker) & (FriendRequest.to_firebase_uid == target))
        | ((FriendRequest.from_firebase_uid == target) & (FriendRequest.to_firebase_uid == blocker))
    ).delete(synchronize_session=False)

    session.commit()
    return {"success": True, "blocked": True}


@router.get("")
def list_blocks(
    user: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    blocker = _uid(user)
    rows = (
        session.query(UserBlock, User)
        .join(User, User.firebase_uid == UserBlock.blocked_firebase_uid)
        .filter(UserBlock.blocker_firebase_uid == blocker)
        .order_by(UserBlock.created_at.desc())
        .all()
    )
    return {
        "blocks": [
            {
                "firebaseUid": block.blocked_firebase_uid,
                "name": target.name,
                "createdAt": block.created_at.isoformat() if block.created_at else None,
            }
            for block, target in rows
        ]
    }


@router.get("/status")
def block_status(
    target: str,
    user: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    blocker = _uid(user)
    return {"isBlocked": is_blocked(session, blocker, target)}


@router.delete("/{target_firebase_uid}")
def unblock_user(
    target_firebase_uid: str,
    user: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    blocker = _uid(user)
    deleted = session.query(UserBlock).filter(
        UserBlock.blocker_firebase_uid == blocker,
        UserBlock.blocked_firebase_uid == target_firebase_uid,
    ).delete()
    session.commit()
    if not deleted:
        raise HTTPException(status_code=404, detail="Block relationship not found")
    return {"success": True, "blocked": False}
