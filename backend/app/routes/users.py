"""User profile management endpoints.

Provides user CRUD and account management:
- ``PATCH /api/users/me``: Update profile fields (name, avatar, bio).
- ``DELETE /api/users/me``: Delete account and associated data with financial compliance preservation.
- ``GET /api/users/{user_id}``: Public profile lookup by Firebase UID or internal ID.
- ``POST /api/users/report``: Submit a report/issue (stored as ActivityEvent).
"""

from __future__ import annotations

import logging
from datetime import date
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ..db import get_session
from ..auth_deps import get_current_user
from ..firebase_auth import _firebase_initialized
from ..models import (
    User, ActivityEvent,
    Blend, BlendMember, BlendSwipe, BlendMessage, BlendInvitation,
    Wishlist, Post, Like, Comment, Save, Follow, Friend, FriendRequest,
    WardrobeItem, Outfit, Decision, StylePersona, UserPreference,
    PushDevice, Cart, CartItem, DiscoverySwipe, Order, Purchase
)
from ..models_moderation import UserBlock
from ..models_payments import Payment
from ..models_notifications import Notification
from ..age_policy import is_minor, validate_date_of_birth

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/users", tags=["users"])


class UserUpdateRequest(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=120)
    avatar_url: Optional[str] = Field(default=None, max_length=2048)
    bio: Optional[str] = Field(default=None, max_length=500)


class ReportRequest(BaseModel):
    category: str
    description: str


class AgeVerificationRequest(BaseModel):
    date_of_birth: date


@router.post("/me/age-verification")
def verify_age(
    payload: AgeVerificationRequest,
    user: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    """Record DOB after server-side validation of the 13+ launch rule.

    DOB is private account data. The response exposes only verification state
    and derived minor status.
    """
    firebase_uid = user.get("uid") or user.get("firebase_uid")
    if not firebase_uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    try:
        age = validate_date_of_birth(payload.date_of_birth)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    db_user = session.query(User).filter(User.firebase_uid == str(firebase_uid)).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")

    db_user.date_of_birth = payload.date_of_birth
    session.commit()

    return {
        "ageVerified": True,
        "isMinor": 13 <= age <= 17,
    }


def _user_payload(
    user: User,
    session: Optional[Session] = None,
    include_firebase_uid: bool = False,
    include_email: bool = False,
) -> dict[str, Any]:
    data: dict[str, Any] = {
        "id": user.id,
        "name": user.name,
        "avatarUrl": user.avatar_url or "",
        "bio": user.bio or "",
    }
    if include_email:
        data["email"] = user.email
    if include_firebase_uid:
        data["firebaseUid"] = user.firebase_uid
    if session is not None:
        data["followersCount"] = (
            session.query(Follow)
            .filter(Follow.following_firebase_uid == user.firebase_uid)
            .count()
        )
        data["followingCount"] = (
            session.query(Follow)
            .filter(Follow.follower_firebase_uid == user.firebase_uid)
            .count()
        )
        posts = (
            session.query(Post)
            .filter(Post.user_firebase_uid == user.firebase_uid)
            .order_by(Post.created_at.desc())
            .limit(50)
            .all()
        )
        data["postsCount"] = len(posts)
        data["posts"] = [
            {
                "id": p.id,
                "imageUrl": p.attachment or "",
                "content": p.content,
                "createdAt": p.created_at.isoformat() if p.created_at else None,
            }
            for p in posts
        ]
    return data


def _safe_int(value: str) -> int | None:
    try:
        return int(value)
    except (ValueError, TypeError):
        return None


@router.patch("/me")
def update_me(
    payload: UserUpdateRequest,
    user: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    firebase_uid = user.get("uid") or user.get("firebase_uid")
    if not firebase_uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    if payload.name is None and payload.avatar_url is None and payload.bio is None:
        raise HTTPException(status_code=400, detail="No fields to update")

    db_user = session.query(User).filter(User.firebase_uid == str(firebase_uid)).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")

    if payload.name is not None:
        db_user.name = payload.name
    if payload.avatar_url is not None:
        db_user.avatar_url = payload.avatar_url or None
    if payload.bio is not None:
        db_user.bio = payload.bio or None

    session.commit()
    session.refresh(db_user)
    return {"user": _user_payload(db_user, session, include_email=True)}


@router.delete("/me")
def delete_account(
    user: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """Delete the authenticated user's account with compliance-aware retention.
    
    Cascades through user activity, social, wardrobe, and carts.
    Financial and tax-relevant audit records (orders, payments) are anonymized
    for regulatory retention rather than deleted.
    """
    firebase_uid = str(user.get("uid") or user.get("firebase_uid"))
    if not firebase_uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    db_user = session.query(User).filter(User.firebase_uid == firebase_uid).first()
    if not db_user:
        return {"ok": True}

    # Anonymize legal & financial audit records (Orders, Payments, Purchases)
    anonymized_id = f"anonymized_{firebase_uid[:8]}"
    session.query(Order).filter(Order.user_firebase_uid == firebase_uid).update(
        {Order.user_firebase_uid: anonymized_id}, synchronize_session=False
    )
    session.query(Payment).filter(Payment.user_firebase_uid == firebase_uid).update(
        {Payment.user_firebase_uid: anonymized_id}, synchronize_session=False
    )
    session.query(Purchase).filter(Purchase.user_firebase_uid == firebase_uid).update(
        {Purchase.user_firebase_uid: anonymized_id}, synchronize_session=False
    )

    # Cascade-delete user profile, preferences, social, wardrobe, cart, notifications
    for model, col in [
        (CartItem, CartItem.user_firebase_uid),
        (Cart, Cart.user_firebase_uid),
        (DiscoverySwipe, DiscoverySwipe.user_firebase_uid),
        (BlendMessage, BlendMessage.sender_firebase_uid),
        (BlendSwipe, BlendSwipe.user_firebase_uid),
        (BlendMember, BlendMember.user_firebase_uid),
        (BlendInvitation, BlendInvitation.inviter_firebase_uid),
        (BlendInvitation, BlendInvitation.invitee_firebase_uid),
        (Blend, Blend.user_firebase_uid),
        (Wishlist, Wishlist.user_firebase_uid),
        (Post, Post.user_firebase_uid),
        (Like, Like.user_firebase_uid),
        (Comment, Comment.user_firebase_uid),
        (Save, Save.user_firebase_uid),
        (Follow, Follow.follower_firebase_uid),
        (Follow, Follow.following_firebase_uid),
        (Friend, Friend.user_firebase_uid),
        (Friend, Friend.friend_firebase_uid),
        (FriendRequest, FriendRequest.from_firebase_uid),
        (FriendRequest, FriendRequest.to_firebase_uid),
        (UserBlock, UserBlock.blocker_firebase_uid),
        (UserBlock, UserBlock.blocked_firebase_uid),
        (WardrobeItem, WardrobeItem.user_firebase_uid),
        (Outfit, Outfit.user_firebase_uid),
        (Decision, Decision.user_firebase_uid),
        (StylePersona, StylePersona.user_firebase_uid),
        (UserPreference, UserPreference.user_firebase_uid),
        (ActivityEvent, ActivityEvent.user_firebase_uid),
        (Notification, Notification.user_firebase_uid),
        (PushDevice, PushDevice.user_firebase_uid),
    ]:
        session.query(model).filter(col == firebase_uid).delete(synchronize_session=False)

    session.delete(db_user)
    session.commit()

    # Attempt Firebase Auth deletion if initialized
    if _firebase_initialized:
        try:
            from firebase_admin import auth as fb_auth
            fb_auth.delete_user(firebase_uid)
        except Exception as e:
            logger.warning("Firebase user deletion handled: %s", e)

    return {"ok": True}


@router.get("/{user_id}")
def get_public_profile(user_id: str, session: Session = Depends(get_session)):
    """Public profile lookup — Firebase UID is never exposed publicly."""
    db_user = session.query(User).filter(
        (User.firebase_uid == user_id) | (User.id == _safe_int(user_id))
    ).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
    return {"user": _user_payload(db_user, session, include_firebase_uid=False)}


@router.post("/report")
def report_issue(
    payload: ReportRequest,
    user: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """Submit a report/issue from the authenticated user."""
    firebase_uid = str(user.get("uid") or user.get("firebase_uid"))
    if not firebase_uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    event = ActivityEvent(
        user_firebase_uid=firebase_uid,
        kind="report",
        description=f"[{payload.category}] {payload.description}",
        metadata_json={"category": payload.category},
    )
    session.add(event)
    session.commit()
    return {"ok": True}
