"""Centralized authorization helpers for Socket.IO and REST endpoints.

Provides reusable functions to enforce:
- User authentication (verified Firebase UID)
- Blend membership (user is a member of a blend)
- Blend ownership (user created the blend)
- Private blend authorization (user has valid invitation)

These helpers prevent IDOR (Insecure Direct Object Reference) vulnerabilities
by ensuring that knowledge of an ID (blend_id, message_id, etc.) is not
sufficient — the user must have proper authorization.

Usage in Socket.IO event handlers:
    @sio.event
    async def some_event(sid, data):
        user_id = _verified_uid(sid)
        if not user_id:
            await sio.emit("socket_error", "Not authenticated", to=sid)
            return
        
        blend_id = data.get("groupId")
        is_member = await require_blend_member(user_id, blend_id)
        if not is_member:
            await sio.emit("socket_error", "Not a member of this blend", to=sid)
            return

Usage in REST endpoints:
    @router.post("/blends/{blend_id}/messages")
    def send_message(blend_id: str, body: MessageRequest, 
                     request: Request, session: Session = Depends(get_session)):
        user_id = get_current_user_id(request)
        
        if not require_blend_member_sync(user_id, blend_id, session):
            raise HTTPException(status_code=403, detail="Not a member of this blend")
        
        # Safe to proceed — user is authorized
        ...
"""

import logging
from sqlalchemy.orm import Session
from fastapi import HTTPException

from .db import SessionLocal
from .models import Blend, BlendMember, BlendInvitation

logger = logging.getLogger(__name__)


# ============================================================================
# SYNC HELPERS (for REST endpoints)
# ============================================================================

def user_is_admin(decoded: dict | None, session) -> bool:
    """Single source of truth for admin authorization.

    Admin status is granted by EITHER:
    1. A Firebase custom claim set via the Admin SDK:
       ``set_custom_user_claims(uid, {"admin": True})`` (or legacy
       ``{"role": "admin"}``), OR
    2. The server-side ``users.is_admin`` column, which can only be set
       directly in the database by an operator.

    Deny-by-default: anything else is NOT an admin. Dev bypass tokens are not
    admins unless the corresponding DB row has ``is_admin=True``.
    """
    if not decoded:
        return False

    if decoded.get("admin") is True or decoded.get("role") == "admin":
        return True

    uid = decoded.get("uid") or decoded.get("user_id")
    if not uid:
        return False

    from .models import User

    row = session.query(User.is_admin).filter(User.firebase_uid == uid).first()
    return bool(row and row.is_admin)


def require_authenticated_sync(user_id: str | None) -> str:
    """Ensure user is authenticated, return verified UID.
    
    Raises HTTPException(401) if user_id is None or empty.
    Use this at the start of REST endpoints that require auth.
    
    Args:
        user_id: Firebase UID from get_current_user_id() or similar
        
    Returns:
        The verified user_id
        
    Raises:
        HTTPException(401): If user_id is missing or invalid
    """
    if not user_id or not user_id.strip():
        raise HTTPException(
            status_code=401,
            detail="Authentication required"
        )
    return user_id


def require_blend_member_sync(user_id: str, blend_id: str, session: Session) -> bool:
    """Check if user is a member of a blend (sync version for REST).
    
    Prevents IDOR: knowing the blend_id is not enough; user must be a member.
    
    Args:
        user_id: Firebase UID of the user
        blend_id: ID of the blend to check membership
        session: Database session
        
    Returns:
        True if user is a member, False otherwise
    """
    if not user_id or not blend_id:
        return False
    
    member = session.query(BlendMember).filter(
        BlendMember.blend_id == blend_id,
        BlendMember.user_firebase_uid == user_id,
    ).first()
    
    return member is not None


def require_blend_owner_sync(user_id: str, blend_id: str, session: Session) -> bool:
    """Check if user is the owner (creator) of a blend (sync version for REST).
    
    Prevents IDOR: only the creator can perform certain operations.
    
    Args:
        user_id: Firebase UID of the user
        blend_id: ID of the blend to check ownership
        session: Database session
        
    Returns:
        True if user is the owner, False otherwise
    """
    if not user_id or not blend_id:
        return False
    
    blend = session.query(Blend).filter(
        Blend.id == blend_id,
        Blend.user_firebase_uid == user_id,
    ).first()
    
    return blend is not None


def require_private_blend_auth_sync(user_id: str, blend_id: str, session: Session) -> bool:
    """Check if user has valid invitation to a private blend (sync version for REST).
    
    For private blends, user must have a pending or accepted invitation.
    
    Args:
        user_id: Firebase UID of the user
        blend_id: ID of the blend
        session: Database session
        
    Returns:
        True if user has valid invitation, False otherwise
    """
    if not user_id or not blend_id:
        return False
    
    # Get the blend to check if it's private
    blend = session.query(Blend).filter(Blend.id == blend_id).first()
    if not blend:
        return False
    
    # Public blends don't need invitation
    if not blend.is_private:
        return True
    
    # Private blend: check for exact uid match in pending/accepted invitations
    invitation = session.query(BlendInvitation).filter(
        BlendInvitation.blend_id == blend_id,
        BlendInvitation.invitee_firebase_uid == user_id,
        BlendInvitation.status.in_(("pending", "accepted")),
    ).first()
    
    return invitation is not None


# ============================================================================
# ASYNC HELPERS (for Socket.IO event handlers)
# ============================================================================

async def require_blend_member_async(user_id: str, blend_id: str) -> bool:
    """Check if user is a member of a blend (async version for Socket.IO).
    
    Prevents IDOR: knowing the blend_id is not enough; user must be a member.
    
    Args:
        user_id: Firebase UID of the user
        blend_id: ID of the blend to check membership
        
    Returns:
        True if user is a member, False otherwise
    """
    if not user_id or not blend_id:
        return False
    
    db = SessionLocal()
    try:
        member = db.query(BlendMember).filter(
            BlendMember.blend_id == blend_id,
            BlendMember.user_firebase_uid == user_id,
        ).first()
        return member is not None
    finally:
        db.close()


async def require_blend_owner_async(user_id: str, blend_id: str) -> bool:
    """Check if user is the owner of a blend (async version for Socket.IO).
    
    Prevents IDOR: only the creator can perform certain operations.
    
    Args:
        user_id: Firebase UID of the user
        blend_id: ID of the blend to check ownership
        
    Returns:
        True if user is the owner, False otherwise
    """
    if not user_id or not blend_id:
        return False
    
    db = SessionLocal()
    try:
        blend = db.query(Blend).filter(
            Blend.id == blend_id,
            Blend.user_firebase_uid == user_id,
        ).first()
        return blend is not None
    finally:
        db.close()


async def require_private_blend_auth_async(user_id: str, blend_id: str) -> bool:
    """Check if user has valid invitation to a private blend (async version for Socket.IO).
    
    For private blends, user must have a pending or accepted invitation.
    
    Args:
        user_id: Firebase UID of the user
        blend_id: ID of the blend
        
    Returns:
        True if user has valid invitation, False otherwise
    """
    if not user_id or not blend_id:
        return False
    
    db = SessionLocal()
    try:
        # Get the blend to check if it's private
        blend = db.query(Blend).filter(Blend.id == blend_id).first()
        if not blend:
            return False
        
        # Public blends don't need invitation
        if not blend.is_private:
            return True
        
        # Private blend: check for exact uid match
        invitation = db.query(BlendInvitation).filter(
            BlendInvitation.blend_id == blend_id,
            BlendInvitation.invitee_firebase_uid == user_id,
            BlendInvitation.status.in_(("pending", "accepted")),
        ).first()
        
        return invitation is not None
    finally:
        db.close()


# ============================================================================
# ERROR HELPERS
# ============================================================================

def raise_forbidden(detail: str = "Access denied") -> None:
    """Raise 403 Forbidden error with a message."""
    raise HTTPException(status_code=403, detail=detail)


def raise_not_found(detail: str = "Resource not found") -> None:
    """Raise 404 Not Found error with a message."""
    raise HTTPException(status_code=404, detail=detail)


def raise_unauthorized(detail: str = "Unauthorized") -> None:
    """Raise 401 Unauthorized error with a message."""
    raise HTTPException(status_code=401, detail=detail)
