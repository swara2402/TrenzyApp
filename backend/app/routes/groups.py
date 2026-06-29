from __future__ import annotations

import uuid
from typing import Any, Optional

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy import func

from ..blend_helpers import compute_blend_results
from ..db import SessionLocal
from ..firebase_auth import verify_firebase_token
from ..models import Group, GroupMember, GroupSwipe, Product

router = APIRouter(prefix="/api/groups", tags=["groups"])


class GroupCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=80)


class GroupJoinRequest(BaseModel):
    groupId: str
    userName: Optional[str] = None



class GroupSwipeRequest(BaseModel):
    groupId: str
    productId: str
    swipeType: str  # "like", "love", "dislike"


SCORE_MAP = {"like": 1, "love": 2, "dislike": -1}


def _get_uid(decoded: dict[str, Any]) -> str:
    firebase_uid = decoded.get("uid")
    if not firebase_uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")
    return firebase_uid


def _group_payload(group: Group, members: list[GroupMember], db) -> dict[str, Any]:
    swipe_counts = (
        db.query(GroupSwipe.user_firebase_uid, func.count(GroupSwipe.id))
        .filter(GroupSwipe.group_id == group.id)
        .group_by(GroupSwipe.user_firebase_uid)
        .all()
    )
    swipe_map = {uid: count for uid, count in swipe_counts}

    return {
        "id": group.id,
        "name": group.name,
        "inviteCode": group.id,
        "memberCount": len(members),
        "members": [
            {
                "userId": m.user_firebase_uid,
                "userName": m.user_name,
                "swipeCount": swipe_map.get(m.user_firebase_uid, 0),
            }
            for m in members
        ],
    }


@router.post("")
def create_group(payload: GroupCreateRequest, request: Request) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)
    user_name = decoded.get("name") or "You"

    db = SessionLocal()
    try:
        group_id = f"blend-{uuid.uuid4().hex[:6]}"
        group = Group(id=group_id, name=payload.name.strip())
        db.add(group)
        db.add(
            GroupMember(
                group_id=group_id,
                user_firebase_uid=firebase_uid,
                user_name=user_name,
            )
        )
        db.commit()
        db.refresh(group)
        members = db.query(GroupMember).filter(GroupMember.group_id == group_id).all()
        return _group_payload(group, members, db)
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to create group: {e}")
    finally:
        db.close()


@router.post("/join")
def join_group(payload: GroupJoinRequest, request: Request) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)
    user_name = payload.userName or decoded.get("name") or "Guest"
    group_id = payload.groupId.strip()

    db = SessionLocal()
    try:
        group = db.query(Group).filter(Group.id == group_id).first()
        if not group:
            raise HTTPException(status_code=404, detail="Blend group not found")

        existing = (
            db.query(GroupMember)
            .filter(
                GroupMember.group_id == group_id,
                GroupMember.user_firebase_uid == firebase_uid,
            )
            .first()
        )
        if not existing:
            db.add(
                GroupMember(
                    group_id=group_id,
                    user_firebase_uid=firebase_uid,
                    user_name=user_name,
                )
            )
            db.commit()

        members = db.query(GroupMember).filter(GroupMember.group_id == group_id).all()
        return _group_payload(group, members, db)
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to join group: {e}")
    finally:
        db.close()


@router.get("/{group_id}")
def get_group(group_id: str, request: Request) -> dict[str, Any]:
    verify_firebase_token(request)

    db = SessionLocal()
    try:
        group = db.query(Group).filter(Group.id == group_id).first()
        if not group:
            raise HTTPException(status_code=404, detail="Blend group not found")
        members = db.query(GroupMember).filter(GroupMember.group_id == group_id).all()
        return {"group": _group_payload(group, members, db)}
    finally:
        db.close()


@router.delete("/{group_id}/leave")
def leave_group(group_id: str, request: Request) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)

    db = SessionLocal()
    try:
        member = (
            db.query(GroupMember)
            .filter(
                GroupMember.group_id == group_id,
                GroupMember.user_firebase_uid == firebase_uid,
            )
            .first()
        )
        if not member:
            raise HTTPException(status_code=404, detail="You are not a member of this blend")

        db.delete(member)
        db.commit()

        remaining = db.query(GroupMember).filter(GroupMember.group_id == group_id).count()
        return {"success": True, "memberCount": remaining}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to leave group: {e}")
    finally:
        db.close()


@router.post("/swipe")
def record_swipe(payload: GroupSwipeRequest, request: Request) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)
    score = SCORE_MAP.get(payload.swipeType.lower(), 0)

    db = SessionLocal()
    try:
        group = db.query(Group).filter(Group.id == payload.groupId).first()
        if not group:
            raise HTTPException(status_code=404, detail="Blend group not found")

        member = (
            db.query(GroupMember)
            .filter(
                GroupMember.group_id == payload.groupId,
                GroupMember.user_firebase_uid == firebase_uid,
            )
            .first()
        )
        if not member:
            raise HTTPException(status_code=403, detail="Join the blend before swiping")

        existing = (
            db.query(GroupSwipe)
            .filter(
                GroupSwipe.group_id == payload.groupId,
                GroupSwipe.user_firebase_uid == firebase_uid,
                GroupSwipe.product_id == payload.productId,
            )
            .first()
        )
        if existing:
            existing.score = score
        else:
            db.add(
                GroupSwipe(
                    group_id=payload.groupId,
                    user_firebase_uid=firebase_uid,
                    product_id=payload.productId,
                    score=score,
                )
            )
        db.commit()
        return {"success": True, "score": score, "swipeType": payload.swipeType.lower()}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to record swipe: {e}")
    finally:
        db.close()


@router.get("/{group_id}/blend")
def get_blend_recommendations(group_id: str, request: Request) -> dict[str, Any]:
    verify_firebase_token(request)

    db = SessionLocal()
    try:
        group = db.query(Group).filter(Group.id == group_id).first()
        if not group:
            raise HTTPException(status_code=404, detail="Blend group not found")

        members = db.query(GroupMember).filter(GroupMember.group_id == group_id).all()
        results = compute_blend_results(db, group_id)

        return {
            "groupId": group_id,
            "groupName": group.name,
            "memberCount": len(members),
            **results,
        }
    finally:
        db.close()


@router.get("/{group_id}/results")
def get_blend_results(group_id: str, request: Request) -> dict[str, Any]:
    """Compatibility endpoint for the Flutter client.

    Flutter calls: GET /api/groups/<groupId>/results
    while the backend originally implemented: GET /api/groups/<groupId>/blend
    """
    return get_blend_recommendations(group_id=group_id, request=request)

