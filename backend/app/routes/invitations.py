"""Blend group invitations: send, accept, reject.

Invitations allow blend group creators to invite users to join. Each invitation
has a unique token, expiry (24 hours by default), and status (pending/accepted/
rejected/expired). Accepting an invitation auto-adds the user as a BlendMember.
"""
from __future__ import annotations

import datetime
import logging
import uuid
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..auth_helpers import require_blend_member_sync
from ..models import Blend, BlendInvitation, BlendMember
from ..models_moderation import UserBlock

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/invitations", tags=["invitations"])


class CreateInvitationRequest(BaseModel):
    groupId: str = Field(min_length=1)
    expiresInSeconds: Optional[int] = Field(
        default=60 * 60 * 24 * 7, ge=60, le=60 * 60 * 24 * 60
    )


class AcceptInvitationRequest(BaseModel):
    token: str = Field(min_length=10, max_length=120)


def _get_uid(decoded: dict[str, Any]) -> str:
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")
    return uid


@router.post("")
def create_invitation(
    payload: CreateInvitationRequest, request: Request, session: Session = Depends(get_session)
) -> dict[str, Any]:
    """Create an invitation to a blend group.
    
    AUTHORIZATION: User must be a blend member to create invites.
    """
    decoded = verify_firebase_token(request)
    creator_uid = _get_uid(decoded)
    creator_name = decoded.get("name") or "You"

    group_id = payload.groupId.strip()
    group = session.query(Blend).filter(Blend.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Blend group not found")

    # AUTHORIZATION: Only members can create invites (use central helper)
    if not require_blend_member_sync(creator_uid, group_id, session):
        raise HTTPException(status_code=403, detail="Only blend members can create invites")

    token = f"inv-{uuid.uuid4().hex}"
    invitation = BlendInvitation(
        id=f"inv-{uuid.uuid4().hex}",
        token=token,
        blend_id=group_id,
        inviter_firebase_uid=creator_uid,
        inviter_name=creator_name,
        invitee_firebase_uid="",  # Set when the invitee accepts via token
        expires_seconds=payload.expiresInSeconds or (60 * 60 * 24 * 7),
        status="pending",
    )
    session.add(invitation)
    session.commit()
    session.refresh(invitation)

    return {
        "token": invitation.token,
        "groupId": invitation.blend_id,
        "expiresInSeconds": invitation.expires_seconds,
    }


@router.post("/accept")
def accept_invitation(
    payload: AcceptInvitationRequest, request: Request, session: Session = Depends(get_session)
) -> dict[str, Any]:
    """Accept an invitation to join a blend group.
    
    AUTHORIZATION: Any authenticated user can accept valid invitations.
    PRODUCT: Invitation must be pending and not expired.
    """
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)

    token = payload.token.strip()
    inv = session.query(BlendInvitation).filter(BlendInvitation.token == token).first()
    if not inv:
        raise HTTPException(status_code=400, detail="Invalid invitation")

    # PRODUCT: Enforce expiry check
    if inv.status == "expired":
        raise HTTPException(status_code=400, detail="Invitation has expired")
    
    if inv.status != "pending":
        raise HTTPException(status_code=400, detail="Invitation already used or revoked")

    created_at = inv.created_at
    if created_at is None:
        raise HTTPException(status_code=400, detail="Invalid invitation")

    expires_at = created_at + datetime.timedelta(seconds=inv.expires_seconds or 0)
    now_utc = datetime.datetime.now(datetime.timezone.utc)
    if now_utc > expires_at.replace(tzinfo=datetime.timezone.utc):
        inv.status = "expired"
        session.commit()
        raise HTTPException(status_code=400, detail="Invitation has expired")

    group = session.query(Blend).filter(Blend.id == inv.blend_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Blend group not found")

    blocked = session.query(UserBlock).filter(
        ((UserBlock.blocker_firebase_uid == firebase_uid) & (UserBlock.blocked_firebase_uid == inv.inviter_firebase_uid))
        | ((UserBlock.blocker_firebase_uid == inv.inviter_firebase_uid) & (UserBlock.blocked_firebase_uid == firebase_uid))
    ).first()
    if blocked:
        raise HTTPException(status_code=403, detail="This collaboration is blocked")

    # Check if user is already a member
    existing = (
        session.query(BlendMember)
        .filter(
            BlendMember.blend_id == inv.blend_id,
            BlendMember.user_firebase_uid == firebase_uid,
        )
        .first()
    )
    if not existing:
        session.add(
            BlendMember(
                blend_id=inv.blend_id,
                user_firebase_uid=firebase_uid,
                user_name=decoded.get("name") or inv.inviter_name or "Guest",
            )
        )
        session.commit()

    # PRODUCT: Update invitation status and track acceptor
    inv.status = "accepted"
    inv.accepted_by_firebase_uid = firebase_uid
    inv.invitee_firebase_uid = firebase_uid  # Track who accepted
    inv.accepted_at = now_utc
    session.commit()

    members = (
        session.query(BlendMember).filter(BlendMember.blend_id == inv.blend_id).all()
    )
    return {
        "groupId": inv.blend_id,
        "inviteToken": inv.token,
        "memberCount": len(members),
    }


@router.post("/revoke")
def revoke_invitation(
    payload: dict, request: Request, session: Session = Depends(get_session)
) -> dict[str, Any]:
    """Revoke a pending invitation.
    
    AUTHORIZATION: Only inviter or blend creator can revoke.
    """
    decoded = verify_firebase_token(request)
    uid = _get_uid(decoded)
    
    token = payload.get("token", "").strip()
    inv = session.query(BlendInvitation).filter(BlendInvitation.token == token).first()
    if not inv:
        raise HTTPException(status_code=404, detail="Invitation not found")
    
    # AUTHORIZATION: Only inviter can revoke their own invitations
    if inv.inviter_firebase_uid != uid:
        raise HTTPException(status_code=403, detail="Only the inviter can revoke this invitation")
    
    if inv.status != "pending":
        raise HTTPException(status_code=400, detail="Invitation cannot be revoked (not pending)")
    
    inv.status = "revoked"
    session.commit()
    
    return {"success": True, "token": inv.token}
