from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

from ..db import SessionLocal
from ..firebase_auth import verify_firebase_token
from ..models import Friend, FriendRequest, User

router = APIRouter(prefix="/api/friends", tags=["friends"])


class FriendRequestPayload(BaseModel):
    toFirebaseUid: str = Field(min_length=1)


def _get_uid(decoded: dict[str, Any]) -> str:
    firebase_uid = decoded.get("uid")
    if not firebase_uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")
    return firebase_uid


@router.post("/request")
def send_friend_request(payload: FriendRequestPayload, request: Request) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    from_uid = _get_uid(decoded)
    from_name = decoded.get("name") or "User"
    to_uid = payload.toFirebaseUid

    if from_uid == to_uid:
        raise HTTPException(status_code=400, detail="Cannot send friend request to yourself")

    db = SessionLocal()
    try:
        to_user = db.query(User).filter(User.firebase_uid == to_uid).first()
        if not to_user:
            raise HTTPException(status_code=404, detail="User not found")

        existing = (
            db.query(FriendRequest)
            .filter(
                FriendRequest.from_firebase_uid == from_uid,
                FriendRequest.to_firebase_uid == to_uid,
                FriendRequest.status == "pending",
            )
            .first()
        )
        if existing:
            raise HTTPException(status_code=400, detail="Friend request already sent")

        existing_friend = (
            db.query(Friend)
            .filter(
                Friend.user_firebase_uid == from_uid,
                Friend.friend_firebase_uid == to_uid,
            )
            .first()
        )
        if existing_friend:
            raise HTTPException(status_code=400, detail="Already friends")

        friend_request = FriendRequest(
            from_firebase_uid=from_uid,
            from_name=from_name,
            to_firebase_uid=to_uid,
            status="pending",
        )
        db.add(friend_request)
        db.commit()
        db.refresh(friend_request)

        return {"success": True, "requestId": friend_request.id}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to send friend request: {e}")
    finally:
        db.close()


@router.get("/requests")
def get_friend_requests(request: Request) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    to_uid = _get_uid(decoded)

    db = SessionLocal()
    try:
        requests = (
            db.query(FriendRequest)
            .filter(FriendRequest.to_firebase_uid == to_uid, FriendRequest.status == "pending")
            .all()
        )
        return {
            "requests": [
                {
                    "id": req.id,
                    "fromFirebaseUid": req.from_firebase_uid,
                    "fromName": req.from_name,
                    "createdAt": req.created_at.isoformat(),
                }
                for req in requests
            ]
        }
    finally:
        db.close()


@router.post("/requests/{request_id}/accept")
def accept_friend_request(request_id: int, request: Request) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    to_uid = _get_uid(decoded)

    db = SessionLocal()
    try:
        req = db.query(FriendRequest).filter(FriendRequest.id == request_id).first()
        if not req:
            raise HTTPException(status_code=404, detail="Friend request not found")
        if req.to_firebase_uid != to_uid:
            raise HTTPException(status_code=403, detail="Not authorized to accept this request")
        if req.status != "pending":
            raise HTTPException(status_code=400, detail="Request already processed")

        req.status = "accepted"
        db.add(
            Friend(
                user_firebase_uid=to_uid,
                friend_firebase_uid=req.from_firebase_uid,
                friend_name=req.from_name,
            )
        )
        db.add(
            Friend(
                user_firebase_uid=req.from_firebase_uid,
                friend_firebase_uid=to_uid,
                friend_name=decoded.get("name") or "User",
            )
        )
        db.commit()
        return {"success": True}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to accept friend request: {e}")
    finally:
        db.close()


@router.post("/requests/{request_id}/reject")
def reject_friend_request(request_id: int, request: Request) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    to_uid = _get_uid(decoded)

    db = SessionLocal()
    try:
        req = db.query(FriendRequest).filter(FriendRequest.id == request_id).first()
        if not req:
            raise HTTPException(status_code=404, detail="Friend request not found")
        if req.to_firebase_uid != to_uid:
            raise HTTPException(status_code=403, detail="Not authorized to reject this request")
        if req.status != "pending":
            raise HTTPException(status_code=400, detail="Request already processed")

        req.status = "rejected"
        db.commit()
        return {"success": True}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to reject friend request: {e}")
    finally:
        db.close()


@router.get("")
def get_friends(request: Request) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    user_uid = _get_uid(decoded)

    db = SessionLocal()
    try:
        friends = db.query(Friend).filter(Friend.user_firebase_uid == user_uid).all()
        return {
            "friends": [
                {
                    "id": f.id,
                    "friendFirebaseUid": f.friend_firebase_uid,
                    "friendName": f.friend_name,
                }
                for f in friends
            ]
        }
    finally:
        db.close()


@router.delete("/{friend_id}")
def remove_friend(friend_id: int, request: Request) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    user_uid = _get_uid(decoded)

    db = SessionLocal()
    try:
        friend = (
            db.query(Friend)
            .filter(Friend.id == friend_id, Friend.user_firebase_uid == user_uid)
            .first()
        )
        if not friend:
            raise HTTPException(status_code=404, detail="Friend not found")

        db.delete(friend)
        db.commit()
        return {"success": True}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to remove friend: {e}")
    finally:
        db.close()