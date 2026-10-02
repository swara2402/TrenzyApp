"""Blend group management endpoints (create, join, swipe, recommend).

Blends are Trenzy's core social shopping feature. A blend group is a set of
users who swipe on products together, and the system computes collective
recommendations based on their shared preferences.

Key concepts:
- **Blend group**: Created by a user, joined by invite code or direct invite.
- **Swipe**: Members swipe on products (like/love/dislike). Scores: like=1, love=2, dislike=-1.
- **Blend recommendations**: Products ranked by total swipe score, grouped by
  category, with tie detection and per-category winners.
- **Group compatibility**: Jaccard similarity of brand, category, color, and
  style preferences across all member pairs.

The blend state (recommendations + compatibility) is computed on-demand via
``compute_blend_results()`` in blend_helpers.py and also emitted in real-time
via Socket.IO events.

Role model (enforced, deny-by-default):
- **Create**: any authenticated user (becomes the blend owner).
- **Invite**: any member of the blend (REST ``POST /{blend_id}/invitations``,
  or direct invites). Invitations are bound to a specific invitee uid.
- **Join**: anyone via invite code for public blends; private blends require
  a pending/accepted invitation for that exact uid (REST + Socket.IO).
- **Vote/swipe**: members only.
- **Finalize/decide**: results are computed for all members from swipes;
  only the owner can disband (``DELETE /{blend_id}``). The obvious product
  path is: wishlist item → blend swipe → winners → save to wishlist / add
  winning products to cart.
"""

from __future__ import annotations

import json
import logging
import threading
import time
import uuid
from typing import Any, Literal, Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy import func
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

from ..blend_helpers import compute_blend_results, generate_invite_code
from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..auth_helpers import (
    require_blend_member_sync,
    require_blend_owner_sync,
    raise_forbidden,
    raise_not_found,
)
from ..models import Blend, BlendInvitation, BlendMember, BlendSwipe, Product
from .products import _product_payload

router = APIRouter(prefix="/api/blends", tags=["blends"])

# Simple per-user rate limiter for join operations: max 10 joins per minute.
# NOTE: in-memory only; production multi-worker deployments require Redis
# (or another shared store) for a global limit.
_join_rate: dict[str, list[float]] = {}
_join_rate_lock = threading.Lock()
_MAX_JOINS_PER_MINUTE = 10
_RATE_WINDOW = 60.0
_MAX_RATE_LIMITED_USERS = 10_000


def _check_join_rate(firebase_uid: str) -> None:
    """Enforce the per-user join rate limit (thread-safe, memory-bounded).

    Records the attempt and raises HTTPException(429) when the user exceeds
    the limit within the window. Callers should invoke this only after the
    join request has been validated (i.e. the group exists) so that failed
    lookups don't burn a user's quota.
    """
    global _join_rate
    now = time.time()
    with _join_rate_lock:
        recent = [t for t in _join_rate.get(firebase_uid, []) if now - t < _RATE_WINDOW]
        if len(recent) >= _MAX_JOINS_PER_MINUTE:
            raise HTTPException(
                status_code=429,
                detail="Too many join requests. Try again in a minute.",
            )
        recent.append(now)
        # Bound memory: drop buckets emptied by the window and, if the dict is
        # still oversized, forget the stale-most entries.
        if len(_join_rate) > _MAX_RATE_LIMITED_USERS:
            _join_rate = {uid: ts for uid, ts in _join_rate.items() if ts}
        _join_rate[firebase_uid] = recent


class GroupCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    description: Optional[str] = Field(default=None, max_length=500)
    theme: Optional[str] = Field(default=None, max_length=100)
    coverImage: Optional[str] = Field(default=None, max_length=500)
    isPrivate: bool = False
    maxMembers: Optional[int] = Field(default=None, ge=2, le=50)


class GroupJoinRequest(BaseModel):
    groupId: str
    userName: Optional[str] = None


class BlendSwipeRequest(BaseModel):
    groupId: str
    productId: str
    swipeType: str  # "like", "love", "dislike"


SCORE_MAP = {"like": 1, "love": 2, "dislike": -1}


def _get_uid(decoded: dict[str, Any]) -> str:
    firebase_uid = decoded.get("uid")
    if not firebase_uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")
    return firebase_uid


def _unique_invite_code(session) -> str:
    """Generate an invite code that does not collide with existing rows."""
    for _ in range(10):
        code = generate_invite_code()
        if not session.query(Blend.id).filter(Blend.invite_code == code).first():
            return code
    # Practically unreachable with 31^6 combinations; fail loudly rather than
    # silently reusing a duplicate code.
    raise RuntimeError("Could not generate a unique invite code")


# Size of the shared swipe deck served to every blend member.
_BLEND_DECK_SIZE = 10


def _stable_deck(session, group: Blend) -> list[dict[str, Any]]:
    """Return this blend's swipe deck — the SAME 10 products for every member.

    The deck is generated once and persisted on the blend row (``deck_json``).
    Subsequent requests reuse the persisted ids so all members swipe identical
    products, which is what makes group agreement scores meaningful.
    """
    deck_ids: list[str] | None = None
    if group.deck_json:
        try:
            parsed = json.loads(group.deck_json)
            if isinstance(parsed, list) and all(isinstance(x, str) for x in parsed):
                deck_ids = parsed[: _BLEND_DECK_SIZE]
        except (ValueError, TypeError):
            deck_ids = None

    if deck_ids:
        products = (
            session.query(Product)
            .filter(Product.id.in_(deck_ids), Product.is_archived.is_(False))
            .all()
        )
        by_id = {p.id: p for p in products}
        ordered = [by_id[pid] for pid in deck_ids if pid in by_id]
        if len(ordered) == len(deck_ids):
            return [_product_payload(p) for p in ordered]
        # A product was archived/unseeded — regenerate the deck below.

    products = (
        session.query(Product)
        .filter(Product.is_archived.is_(False))
        .order_by(func.random())
        .limit(_BLEND_DECK_SIZE)
        .all()
    )
    group.deck_json = json.dumps([p.id for p in products])
    session.add(group)
    session.commit()
    return [_product_payload(p) for p in products]


def _group_payload(
    group: Blend,
    members: list[BlendMember],
    session,
    swipe_map: dict[str, int] | None = None,
) -> dict[str, Any]:
    if swipe_map is None:
        swipe_counts = (
            session.query(BlendSwipe.user_firebase_uid, func.count(BlendSwipe.id))
            .filter(BlendSwipe.blend_id == group.id)
            .group_by(BlendSwipe.user_firebase_uid)
            .all()
        )
        swipe_map = {uid: count for uid, count in swipe_counts}

    return {
        "id": group.id,
        "name": group.name,
        "description": group.description,
        "theme": group.theme,
        "coverImage": group.cover_image,
        "isPrivate": group.is_private,
        "maxMembers": group.max_members,
        # Real invite code — never the blend id (id would leak a guessable handle).
        "inviteCode": group.invite_code or "",
        "memberCount": len(members),
        "members": [
            {
                "userId": m.user_firebase_uid,
                "userName": m.user_name,
                "swipeCount": swipe_map.get(m.user_firebase_uid, 0),
            }
            for m in members
        ],
        # Swipe deck for the blend — a shared, persisted product pool so every
        # member swipes the SAME products (group agreement is computable).
        "options": _stable_deck(session, group),
    }


def _batch_swipe_counts(session, group_ids: list[str]) -> dict[str, dict[str, int]]:
    rows = (
        session.query(
            BlendSwipe.blend_id,
            BlendSwipe.user_firebase_uid,
            func.count(BlendSwipe.id),
        )
        .filter(BlendSwipe.blend_id.in_(group_ids))
        .group_by(BlendSwipe.blend_id, BlendSwipe.user_firebase_uid)
        .all()
    )
    result: dict[str, dict[str, int]] = {}
    for gid, uid, cnt in rows:
        result.setdefault(gid, {})[uid] = cnt
    return result


@router.get("")
def get_user_groups(request: Request, session: Session = Depends(get_session)) -> list[dict[str, Any]]:
    """Get all groups the authenticated user is a member of."""
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)

    memberships = (
        session.query(BlendMember)
        .filter(BlendMember.user_firebase_uid == firebase_uid)
        .all()
    )
    if not memberships:
        return []

    group_ids = list({m.blend_id for m in memberships})
    groups_map = {
        g.id: g
        for g in session.query(Blend).filter(Blend.id.in_(group_ids)).all()
    }
    swipe_map = _batch_swipe_counts(session, group_ids)

    members_by_group: dict[str, list[BlendMember]] = {}
    for m in session.query(BlendMember).filter(BlendMember.blend_id.in_(group_ids)).all():
        members_by_group.setdefault(m.blend_id, []).append(m)

    groups_data = []
    for membership in memberships:
        group = groups_map.get(membership.blend_id)
        if not group:
            continue
        members = members_by_group.get(group.id, [])
        g_swipe_map = swipe_map.get(group.id, {})
        groups_data.append(_group_payload(group, members, session, swipe_map=g_swipe_map))

    return groups_data


@router.post("")
def create_group(payload: GroupCreateRequest, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)
    user_name = decoded.get("name") or "You"

    group_id = f"blend-{uuid.uuid4().hex[:6]}"
    group = Blend(
        id=group_id,
        name=payload.name.strip(),
        user_firebase_uid=firebase_uid,
        description=payload.description,
        theme=payload.theme,
        cover_image=payload.coverImage,
        is_private=payload.isPrivate,
        max_members=payload.maxMembers,
        invite_code=_unique_invite_code(session),
    )
    session.add(group)
    session.add(
        BlendMember(
            blend_id=group_id,
            user_firebase_uid=firebase_uid,
            user_name=user_name,
        )
    )
    session.commit()
    session.refresh(group)
    members = session.query(BlendMember).filter(BlendMember.blend_id == group_id).all()
    return _group_payload(group, members, session)


@router.post("/join")
def join_group(payload: GroupJoinRequest, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)

    user_name = payload.userName or decoded.get("name") or "Guest"
    group_id = payload.groupId.strip()

    # Join-by-code: resolve invite codes first (case-insensitive), then fall
    # back to blend id so existing deep links keep working. Membership and
    # private-blend invitation checks below apply to both paths.
    group = None
    code = group_id.upper()
    if len(code) <= 10 and not code.startswith("blend-"):
        group = session.query(Blend).filter(Blend.invite_code == code).first()
    if group is None:
        group = session.query(Blend).filter(Blend.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Blend group not found")
    group_id = group.id

    _check_join_rate(firebase_uid)

    existing = (
        session.query(BlendMember)
        .filter(
            BlendMember.blend_id == group_id,
            BlendMember.user_firebase_uid == firebase_uid,
        )
        .first()
    )
    if not existing and group.is_private:
        invited = (
            session.query(BlendInvitation)
            .filter(
                BlendInvitation.blend_id == group_id,
                BlendInvitation.invitee_firebase_uid == firebase_uid,
                BlendInvitation.status.in_(("pending", "accepted")),
            )
            .first()
        )
        if not invited:
            raise HTTPException(status_code=403, detail="This blend is private. Join via an invitation link.")
        
        # PRODUCT EDGE: Enforce invitation expiry on REST join (match Socket.IO enforcement)
        from datetime import datetime, timezone, timedelta
        created_at = invited.created_at
        if created_at is None:
            raise HTTPException(status_code=400, detail="Invalid invitation")
        
        expires_at = created_at + timedelta(seconds=invited.expires_seconds or 0)
        now_utc = datetime.now(timezone.utc)
        if now_utc > expires_at.replace(tzinfo=timezone.utc):
            invited.status = "expired"
            session.commit()
            raise HTTPException(status_code=400, detail="Invitation has expired. Request a new invite.")
        
        # Check for revocation
        if invited.status == "revoked":
            raise HTTPException(status_code=400, detail="This invitation has been revoked.")
    if not existing:
        session.add(
            BlendMember(
                blend_id=group_id,
                user_firebase_uid=firebase_uid,
                user_name=user_name,
            )
        )
        session.commit()

    members = session.query(BlendMember).filter(BlendMember.blend_id == group_id).all()
    return _group_payload(group, members, session)


@router.get("/{group_id}")
def get_group(group_id: str, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    """Get details of a specific blend group.
    
    AUTHORIZATION: User must be a member of the blend (prevent IDOR).
    """
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)

    group = session.query(Blend).filter(Blend.id == group_id).first()
    if not group:
        raise_not_found("Blend group not found")
    
    # AUTHORIZATION: Verify user is a member
    if not require_blend_member_sync(firebase_uid, group_id, session):
        raise_forbidden("Not a member of this blend")
    
    members = session.query(BlendMember).filter(BlendMember.blend_id == group_id).all()
    return _group_payload(group, members, session)


@router.delete("/{group_id}/leave")
def leave_group(group_id: str, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    """Leave a blend group (removes BlendMember record).
    
    AUTHORIZATION: User must be a member to leave.
    """
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)

    # AUTHORIZATION: Verify user is a member
    if not require_blend_member_sync(firebase_uid, group_id, session):
        raise_not_found("You are not a member of this blend")

    member = session.query(BlendMember).filter(
        BlendMember.blend_id == group_id,
        BlendMember.user_firebase_uid == firebase_uid,
    ).first()
    
    if member:
        # A departing member's votes and pending invitations must not keep
        # influencing the blend after they've left.
        session.query(BlendSwipe).filter(
            BlendSwipe.blend_id == group_id,
            BlendSwipe.user_firebase_uid == firebase_uid,
        ).delete()
        session.query(BlendInvitation).filter(
            BlendInvitation.blend_id == group_id,
            BlendInvitation.status == "pending",
            (
                (BlendInvitation.invitee_firebase_uid == firebase_uid)
                | (BlendInvitation.inviter_firebase_uid == firebase_uid)
            ),
        ).delete()
        session.delete(member)
        session.commit()

    remaining = session.query(BlendMember).filter(BlendMember.blend_id == group_id).count()
    return {"success": True, "memberCount": remaining}


@router.delete("/{group_id}")
def disband_group(group_id: str, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    """Disband a blend group (only creator can do this).
    
    AUTHORIZATION: User must be the creator/owner of the blend.
    """
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)

    blend = session.query(Blend).filter(Blend.id == group_id).first()
    if not blend:
        raise_not_found("Blend not found")

    # AUTHORIZATION: Only creator can disband
    if not require_blend_owner_sync(firebase_uid, group_id, session):
        raise_forbidden("Only the creator can disband this blend")

    member = (
        session.query(BlendMember)
        .filter(
            BlendMember.blend_id == group_id,
            BlendMember.user_firebase_uid == firebase_uid,
        )
        .first()
    )
    if not member:
        raise HTTPException(
            status_code=404, detail="You are not a member of this blend"
        )

    session.query(BlendSwipe).filter(BlendSwipe.blend_id == group_id).delete()
    session.query(BlendMember).filter(BlendMember.blend_id == group_id).delete()
    session.query(Blend).filter(Blend.id == group_id).delete()
    session.commit()
    return {"success": True}


@router.post("/swipe")
def record_swipe(payload: BlendSwipeRequest, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    """Record a user's swipe on a product within a blend.
    
    AUTHORIZATION: User must be a member of the blend (prevent IDOR).
    """
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)
    swipe_type = payload.swipeType.lower()
    if swipe_type not in SCORE_MAP:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid swipe type: {payload.swipeType}. Must be one of: {', '.join(SCORE_MAP)}",
        )
    score = SCORE_MAP[swipe_type]

    group = session.query(Blend).filter(Blend.id == payload.groupId).first()
    if not group:
        raise_not_found("Blend group not found")

    # AUTHORIZATION: Verify user is a member
    if not require_blend_member_sync(firebase_uid, payload.groupId, session):
        raise_forbidden("Not a member of this blend")

    existing = (
        session.query(BlendSwipe)
        .filter(
            BlendSwipe.blend_id == payload.groupId,
            BlendSwipe.user_firebase_uid == firebase_uid,
            BlendSwipe.product_id == payload.productId,
        )
        .first()
    )
    if existing:
        existing.score = score
    else:
        session.add(
            BlendSwipe(
                blend_id=payload.groupId,
                user_firebase_uid=firebase_uid,
                product_id=payload.productId,
                score=score,
            )
        )
    session.commit()
    return {"success": True, "score": score, "swipeType": payload.swipeType.lower()}


@router.delete("/{group_id}/swipes/{product_id}")
def undo_swipe(
    group_id: str,
    product_id: str,
    request: Request,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    """Undo a user's swipe on a product within a blend.

    Lets members correct a swipe (undo/fat-finger fix) and keeps the blend
    votes consistent across devices. The swipe is removed entirely; the user
    can re-swipe the product from their deck afterward.

    AUTHORIZATION: User must be a member of the blend (prevent IDOR).
    """
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)

    group = session.query(Blend).filter(Blend.id == group_id).first()
    if not group:
        raise_not_found("Blend group not found")

    if not require_blend_member_sync(firebase_uid, group_id, session):
        raise_forbidden("Not a member of this blend")

    deleted = (
        session.query(BlendSwipe)
        .filter(
            BlendSwipe.blend_id == group_id,
            BlendSwipe.user_firebase_uid == firebase_uid,
            BlendSwipe.product_id == product_id,
        )
        .delete()
    )
    session.commit()
    return {"success": True, "removed": deleted > 0}


@router.get("/{group_id}/blend")
def get_blend_recommendations(group_id: str, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)

    group = session.query(Blend).filter(Blend.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Blend group not found")

    member = session.query(BlendMember).filter(
        BlendMember.blend_id == group_id,
        BlendMember.user_firebase_uid == firebase_uid,
    ).first()
    if not member:
        raise HTTPException(status_code=403, detail="You must be a member of this blend")

    members = session.query(BlendMember).filter(BlendMember.blend_id == group_id).all()
    results = compute_blend_results(session, group_id)

    return {
        "groupId": group_id,
        "groupName": group.name,
        "memberCount": len(members),
        **results,
    }


@router.get("/{group_id}/results")
def get_blend_results(group_id: str, request: Request, session: Session = Depends(get_session)) -> dict[str, Any]:
    """Compatibility endpoint for the Flutter client."""
    return get_blend_recommendations(group_id=group_id, request=request, session=session)


class DirectInviteRequest(BaseModel):
    # inviter_id is ignored — the verified token uid is always the inviter.
    inviter_id: Optional[str] = None
    invitee_id: str = Field(min_length=1, max_length=128)


@router.post("/{blend_id}/invitations")
def invite_to_blend_direct(
    blend_id: str,
    payload: DirectInviteRequest,
    request: Request,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    """Create a direct invitation to a blend.

    WHO CAN INVITE: any blend member. The invitation is bound to the
    verified uid of the caller (the client-supplied inviter_id is ignored).
    """
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)

    blend = session.query(Blend).filter(Blend.id == blend_id).first()
    if not blend:
        raise HTTPException(status_code=404, detail="Blend not found")

    member = session.query(BlendMember).filter(
        BlendMember.blend_id == blend_id,
        BlendMember.user_firebase_uid == firebase_uid,
    ).first()
    if not member:
        raise HTTPException(status_code=403, detail="Only members can invite")

    if payload.invitee_id == firebase_uid:
        raise HTTPException(status_code=400, detail="You are already in this blend")

    from ..models import User
    invitee = session.query(User.firebase_uid).filter(
        User.firebase_uid == payload.invitee_id
    ).first()
    if not invitee:
        raise HTTPException(status_code=404, detail="Invited user not found")

    already_member = session.query(BlendMember.id).filter(
        BlendMember.blend_id == blend_id,
        BlendMember.user_firebase_uid == payload.invitee_id,
    ).first()
    if already_member:
        raise HTTPException(status_code=400, detail="User is already a member of this blend")

    # Enforce the blend's member cap so invites can't overfill it.
    if blend.max_members:
        count = session.query(func.count(BlendMember.id)).filter(
            BlendMember.blend_id == blend_id
        ).scalar() or 0
        if count >= blend.max_members:
            raise HTTPException(status_code=400, detail="This blend is full")

    existing = session.query(BlendInvitation).filter(
        BlendInvitation.blend_id == blend_id,
        BlendInvitation.invitee_firebase_uid == payload.invitee_id,
        BlendInvitation.status == "pending",
    ).first()
    if existing:
        return {"invitationId": existing.id, "status": "already_pending"}

    invitation = BlendInvitation(
        id=f"inv-{uuid.uuid4().hex}",
        blend_id=blend_id,
        inviter_firebase_uid=firebase_uid,
        inviter_name=decoded.get("name") or "You",
        invitee_firebase_uid=payload.invitee_id,
        status="pending",
        # Direct REST invites default to 7 days. Without this the invitation
        # would be instantly expired (expires_at == created_at), making the
        # accept/join flow impossible for real users.
        expires_seconds=7 * 24 * 60 * 60,
    )
    session.add(invitation)
    session.commit()
    session.refresh(invitation)
    return {"invitationId": invitation.id, "status": "pending"}


class RespondInviteRequest(BaseModel):
    # Only accept/reject are valid responses; anything else is rejected so
    # callers can't set arbitrary states (e.g. keep "pending" forever).
    status: Literal["accepted", "rejected"]


@router.put("/invitations/{invitation_id}")
def respond_to_blend_invitation(
    invitation_id: str,
    payload: RespondInviteRequest,
    request: Request,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    """Accept or reject a blend invitation.

    WHO CAN RESPOND: only the invited user (invitee_firebase_uid must match
    the verified uid). Expired invitations cannot be accepted.
    """
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)

    inv = session.query(BlendInvitation).filter(
        BlendInvitation.id == invitation_id
    ).first()
    if not inv or inv.status != "pending":
        raise HTTPException(status_code=404, detail="Invitation not found or not pending")

    # SECURITY: Verify the invitation is intended for this user.
    # Never allow empty invitee_uid to bypass this check.
    if not inv.invitee_firebase_uid or inv.invitee_firebase_uid != firebase_uid:
        raise HTTPException(status_code=403, detail="This invitation is not for you")

    # PRODUCT EDGE: Check invitation expiry (match Socket.IO enforcement)
    if payload.status == "accepted":
        from datetime import datetime, timezone, timedelta
        created_at = inv.created_at
        if created_at is None:
            raise HTTPException(status_code=400, detail="Invalid invitation")
        
        expires_at = created_at + timedelta(seconds=inv.expires_seconds or 0)
        now_utc = datetime.now(timezone.utc)
        if now_utc > expires_at.replace(tzinfo=timezone.utc):
            inv.status = "expired"
            session.commit()
            raise HTTPException(status_code=400, detail="Invitation has expired. Request a new invite.")
        
        # Check for revocation
        if inv.status == "revoked":
            raise HTTPException(status_code=400, detail="This invitation has been revoked.")

    inv.status = payload.status
    if payload.status == "accepted":
        existing = session.query(BlendMember).filter(
            BlendMember.blend_id == inv.blend_id,
            BlendMember.user_firebase_uid == firebase_uid,
        ).first()
        if not existing:
            session.add(BlendMember(
                blend_id=inv.blend_id,
                user_firebase_uid=firebase_uid,
                # The JOINING user's name — never fall back to the inviter's.
                user_name=decoded.get("name") or "You",
            ))
    session.commit()
    return {"status": payload.status}