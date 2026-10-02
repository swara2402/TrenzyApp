"""Friend request and acceptance system.

Implements a friend request flow: send request → accept/reject. Friends are
distinct from followers — following is one-directional, friendship is
mutual. Endpoints: list friends, list pending requests, send request,
accept request, reject request, remove friend.
"""
from __future__ import annotations

import logging
from typing import Any, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..models import Friend, FriendRequest, User
from ..rate_limit import rate_limiter

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/friends", tags=["friends"])


class FriendRequestPayload(BaseModel):
    toFirebaseUid: str = Field(min_length=1)


def _get_uid(decoded: dict[str, Any]) -> str:
    firebase_uid = decoded.get("uid")
    if not firebase_uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")
    return firebase_uid


def _friend_payload(f: Friend) -> dict[str, Any]:
    return {
        "id": f.id,
        "friendFirebaseUid": f.friend_firebase_uid,
        "friendName": f.friend_name,
        "createdAt": f.created_at.isoformat() if f.created_at else None,
    }


def _request_payload(req: FriendRequest) -> dict[str, Any]:
    return {
        "id": req.id,
        "fromFirebaseUid": req.from_firebase_uid,
        "fromName": req.from_name,
        "toFirebaseUid": req.to_firebase_uid,
        "status": req.status,
        "createdAt": req.created_at.isoformat() if req.created_at else None,
    }


def _are_friends(session: Session, a: str, b: str) -> bool:
    return (
        session.query(Friend)
        .filter(
            Friend.user_firebase_uid == a,
            Friend.friend_firebase_uid == b,
        )
        .first()
        is not None
    )


def _create_mutual_friends(
    session: Session,
    uid_a: str,
    name_a: str,
    uid_b: str,
    name_b: str,
) -> None:
    if not _are_friends(session, uid_a, uid_b):
        session.add(
            Friend(
                user_firebase_uid=uid_a,
                friend_firebase_uid=uid_b,
                friend_name=name_b,
            )
        )
    if not _are_friends(session, uid_b, uid_a):
        session.add(
            Friend(
                user_firebase_uid=uid_b,
                friend_firebase_uid=uid_a,
                friend_name=name_a,
            )
        )


@router.post("/request")
def send_friend_request(
    payload: FriendRequestPayload, request: Request, session: Session = Depends(get_session)
) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    from_uid = _get_uid(decoded)
    from_name = decoded.get("name") or "User"
    to_uid = payload.toFirebaseUid.strip()

    if not rate_limiter.is_allowed(f"friend_request:{from_uid}"):
        logger.warning("Rate limit exceeded for friend request from %s", from_uid)
        raise HTTPException(
            status_code=429,
            detail=rate_limiter.error_response()["message"],
            headers={"Retry-After": str(rate_limiter.error_response()["retry_after"])},
        )

    if from_uid == to_uid:
        raise HTTPException(
            status_code=400, detail="Cannot send friend request to yourself"
        )

    to_user = session.query(User).filter(User.firebase_uid == to_uid).first()
    if not to_user:
        raise HTTPException(status_code=404, detail="User not found")

    if _are_friends(session, from_uid, to_uid):
        raise HTTPException(status_code=400, detail="Already friends")

    # Incoming pending from the other user → auto-accept (they already asked).
    reverse = (
        session.query(FriendRequest)
        .filter(
            FriendRequest.from_firebase_uid == to_uid,
            FriendRequest.to_firebase_uid == from_uid,
            FriendRequest.status == "pending",
        )
        .first()
    )
    if reverse:
        reverse.status = "accepted"
        _create_mutual_friends(
            session,
            from_uid,
            from_name,
            to_uid,
            to_user.name or reverse.from_name or "User",
        )
        session.commit()
        return {"success": True, "requestId": reverse.id, "autoAccepted": True}

    existing = (
        session.query(FriendRequest)
        .filter(
            FriendRequest.from_firebase_uid == from_uid,
            FriendRequest.to_firebase_uid == to_uid,
            FriendRequest.status == "pending",
        )
        .first()
    )
    if existing:
        raise HTTPException(status_code=400, detail="Friend request already sent")

    # Re-open a previously rejected request instead of stacking rows.
    rejected = (
        session.query(FriendRequest)
        .filter(
            FriendRequest.from_firebase_uid == from_uid,
            FriendRequest.to_firebase_uid == to_uid,
            FriendRequest.status == "rejected",
        )
        .order_by(FriendRequest.id.desc())
        .first()
    )
    if rejected:
        rejected.status = "pending"
        rejected.from_name = from_name
        session.commit()
        session.refresh(rejected)
        return {"success": True, "requestId": rejected.id}

    friend_request = FriendRequest(
        from_firebase_uid=from_uid,
        from_name=from_name,
        to_firebase_uid=to_uid,
        status="pending",
    )
    session.add(friend_request)
    session.commit()
    session.refresh(friend_request)

    return {"success": True, "requestId": friend_request.id}


@router.get("/requests")
def get_friend_requests(
    request: Request,
    box: Literal["incoming", "outgoing"] = Query("incoming"),
    offset: int = Query(0, ge=0, le=1000),
    limit: int = Query(100, ge=1, le=200),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    uid = _get_uid(decoded)

    q = session.query(FriendRequest).filter(FriendRequest.status == "pending")
    if box == "outgoing":
        q = q.filter(FriendRequest.from_firebase_uid == uid)
    else:
        q = q.filter(FriendRequest.to_firebase_uid == uid)

    requests = q.order_by(FriendRequest.created_at.desc()).offset(offset).limit(limit).all()
    return {"requests": [_request_payload(req) for req in requests], "box": box}


@router.post("/requests/{request_id}/accept")
def accept_friend_request(request_id: int, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    to_uid = _get_uid(decoded)
    to_name = decoded.get("name") or "User"

    req = session.query(FriendRequest).filter(FriendRequest.id == request_id).first()
    if not req or req.to_firebase_uid != to_uid:
        raise HTTPException(status_code=404, detail="Friend request not found")
    if req.status != "pending":
        raise HTTPException(status_code=400, detail="Request already processed")

    req.status = "accepted"
    _create_mutual_friends(
        session,
        to_uid,
        to_name,
        req.from_firebase_uid,
        req.from_name or "User",
    )
    session.commit()
    return {"success": True}


@router.post("/requests/{request_id}/reject")
def reject_friend_request(request_id: int, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    to_uid = _get_uid(decoded)

    req = session.query(FriendRequest).filter(FriendRequest.id == request_id).first()
    if not req or req.to_firebase_uid != to_uid:
        raise HTTPException(status_code=404, detail="Friend request not found")
    if req.status != "pending":
        raise HTTPException(status_code=400, detail="Request already processed")

    req.status = "rejected"
    session.commit()
    return {"success": True}


@router.get("")
def get_friends(
    request: Request,
    offset: int = Query(0, ge=0, le=1000),
    limit: int = Query(100, ge=1, le=200),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    user_uid = _get_uid(decoded)

    friends = (
        session.query(Friend)
        .filter(Friend.user_firebase_uid == user_uid)
        .order_by(Friend.id.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    return {"friends": [_friend_payload(f) for f in friends]}


@router.delete("/{friend_id}")
def remove_friend(friend_id: int, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    user_uid = _get_uid(decoded)

    friend = (
        session.query(Friend)
        .filter(Friend.id == friend_id, Friend.user_firebase_uid == user_uid)
        .first()
    )
    if not friend:
        raise HTTPException(status_code=404, detail="Friend not found")

    reciprocal = (
        session.query(Friend)
        .filter(
            Friend.user_firebase_uid == friend.friend_firebase_uid,
            Friend.friend_firebase_uid == user_uid,
        )
        .first()
    )
    if reciprocal:
        session.delete(reciprocal)

    session.delete(friend)
    session.commit()
    return {"success": True}