from __future__ import annotations

import uuid
from typing import Any, Optional


from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy import select

from ..db import SessionLocal
from ..firebase_auth import verify_firebase_token
from ..models import Group, GroupMember, GroupInvitation

router = APIRouter(prefix="/api/invitations", tags=["invitations"])


class CreateInvitationRequest(BaseModel):
    groupId: str = Field(min_length=1)
    expiresInSeconds: Optional[int] = Field(default=60 * 60 * 24 * 7, ge=60, le=60 * 60 * 24 * 60)



class AcceptInvitationRequest(BaseModel):
    token: str = Field(min_length=10, max_length=120)


def _get_uid(decoded: dict[str, Any]) -> str:
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")
    return uid


@router.post("")
def create_invitation(payload: CreateInvitationRequest, request: Request) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    creator_uid = _get_uid(decoded)
    creator_name = decoded.get("name") or "You"

    db = SessionLocal()
    try:
        group_id = payload.groupId.strip()
        group = db.query(Group).filter(Group.id == group_id).first()
        if not group:
            raise HTTPException(status_code=404, detail="Blend group not found")

        # MVP: creator must already be a member of the blend
        member = (
            db.query(GroupMember)
            .filter(GroupMember.group_id == group_id, GroupMember.user_firebase_uid == creator_uid)
            .first()
        )
        if not member:
            raise HTTPException(status_code=403, detail="Only blend members can create invites")

        token = f"inv-{uuid.uuid4().hex}"
        invitation = GroupInvitation(
            token=token,
            group_id=group_id,
            inviter_firebase_uid=creator_uid,
            inviter_name=creator_name,
            expires_seconds=payload.expiresInSeconds or (60 * 60 * 24 * 7),
            status="pending",
        )
        db.add(invitation)
        db.commit()
        db.refresh(invitation)

        return {
            "token": invitation.token,
            "groupId": invitation.group_id,
            "expiresInSeconds": invitation.expires_seconds,
        }
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to create invitation: {e}")
    finally:
        db.close()


@router.post("/accept")
def accept_invitation(payload: AcceptInvitationRequest, request: Request) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)

    db = SessionLocal()
    try:
        token = payload.token.strip()
        inv = db.query(GroupInvitation).filter(GroupInvitation.token == token).first()
        if not inv or inv.status != "pending":
            raise HTTPException(status_code=400, detail="Invalid or expired invitation")

        # Very simple expiry check (store expiry in seconds server-side at creation)
        # For MVP we treat missing created_at as immediate expiry handled by DB defaults.
        created_at = inv.created_at
        if created_at is None:
            raise HTTPException(status_code=400, detail="Invalid or expired invitation")

        # Compute expiry
        import datetime as _dt

        expires_at = created_at + _dt.timedelta(seconds=inv.expires_seconds or 0)
        if _dt.datetime.now(_dt.timezone.utc) > expires_at.replace(tzinfo=_dt.timezone.utc):
            inv.status = "expired"
            db.commit()
            raise HTTPException(status_code=400, detail="Invalid or expired invitation")

        group = db.query(Group).filter(Group.id == inv.group_id).first()
        if not group:
            raise HTTPException(status_code=404, detail="Blend group not found")

        existing = (
            db.query(GroupMember)
            .filter(GroupMember.group_id == inv.group_id, GroupMember.user_firebase_uid == firebase_uid)
            .first()
        )
        if not existing:
            db.add(
                GroupMember(
                    group_id=inv.group_id,
                    user_firebase_uid=firebase_uid,
                    user_name=decoded.get("name") or inv.inviter_name or "Guest",
                )
            )
            db.commit()

        inv.status = "accepted"
        inv.accepted_by_firebase_uid = firebase_uid
        inv.accepted_at = _dt.datetime.now(_dt.timezone.utc)
        db.commit()

        members = db.query(GroupMember).filter(GroupMember.group_id == inv.group_id).all()
        return {
            "groupId": inv.group_id,
            "inviteToken": inv.token,
            "memberCount": len(members),
        }
    finally:
        db.close()

