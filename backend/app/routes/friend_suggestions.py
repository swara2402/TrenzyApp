"""Friend suggestions based on blend compatibility.

Suggests users as friends based on:
1. Users with the highest blend compatibility scores
2. Users who are already followed but not yet friends
3. Users with similar style profiles

Suggestions are cached in the FriendSuggestion table to avoid recomputing
on every request.
"""
from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import desc
from sqlalchemy.orm import Session

from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..models import BlendMember, Follow, FriendSuggestion, User

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/friends/suggestions", tags=["friend_suggestions"])


@router.get("")
def get_friend_suggestions(request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    followed_uids = [
        r[0] for r in session.query(Follow.following_firebase_uid)
        .filter(Follow.follower_firebase_uid == uid)
        .all()
    ]
    followed_uids.append(uid)

    suggestions = (
        session.query(FriendSuggestion, User)
        .join(User, User.firebase_uid == FriendSuggestion.suggested_firebase_uid)
        .filter(
            FriendSuggestion.suggester_firebase_uid == uid,
            ~FriendSuggestion.suggested_firebase_uid.in_(followed_uids),
        )
        .order_by(desc(FriendSuggestion.score))
        .limit(20)
        .all()
    )

    if not suggestions:
        my_groups = [
            row[0] for row in session.query(BlendMember.blend_id)
            .filter(BlendMember.user_firebase_uid == uid)
            .distinct()
            .all()
        ]
        blend_suggestions = []
        if my_groups:
            other_members = (
                session.query(User)
                .join(BlendMember, BlendMember.user_firebase_uid == User.firebase_uid)
                .filter(
                    BlendMember.blend_id.in_(my_groups),
                    BlendMember.user_firebase_uid != uid,
                    ~BlendMember.user_firebase_uid.in_(followed_uids),
                )
                .distinct()
                .limit(20)
                .all()
            )
            for u in other_members:
                blend_suggestions.append({
                    "firebase_uid": u.firebase_uid,
                    "name": u.name if u else None,
                    "avatar_url": u.avatar_url if u else None,
                    "score": 0.8,
                    "reason": "shared_blend_group",
                })
        results = blend_suggestions
    else:
        results = [
            {
                "firebase_uid": s.suggested_firebase_uid,
                "name": u.name if u else None,
                "avatar_url": u.avatar_url if u else None,
                "score": s.score,
                "reason": s.reason,
            }
            for s, u in suggestions
        ]

    return {"suggestions": results}
