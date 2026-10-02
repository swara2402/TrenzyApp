"""Authentication dependencies for FastAPI routes.

Provides reusable dependency injection functions for Firebase authentication.
These can be imported and used with Depends() in route handlers.

Usage:
    from fastapi import Depends
    from .auth_deps import get_current_user, get_current_user_id

    @router.get("/api/me")
    def get_me(user: dict = Depends(get_current_user)):
        return {"uid": user["uid"]}

    @router.get("/api/my-data")
    def get_my_data(user_id: str = Depends(get_current_user_id)):
        # user_id is a guaranteed UID string, already verified
        return {"owner": user_id}

Standard user dict from get_current_user():
    {
        "uid": "firebase-uid-string",
        "firebase_uid": "firebase-uid-string",
        "email": "user@example.com" (optional),
        "bypass": False (if dev token was used)
    }
"""

from __future__ import annotations

from fastapi import Depends, HTTPException, Request
from . import firebase_auth
from .db import get_session


def get_bearer_token(request: Request) -> str | None:
    """Extract bearer token from Authorization header.
    
    Returns None if no valid Authorization header found.
    """
    return firebase_auth.get_bearer_token(request)


def get_current_user(token: str | None = Depends(get_bearer_token)) -> dict[str, any]:
    """Dependency that verifies and returns the current authenticated user.
    
    Raises HTTPException(401) if token is invalid or missing.
    
    Returns:
        dict with keys: uid, firebase_uid, email (optional), bypass (bool)
    """
    if not token:
        raise HTTPException(
            status_code=401,
            detail="Missing authentication token",
        )
    return firebase_auth.verify_token_string(token)


def get_current_user_id(request: Request) -> str:
    """Dependency that returns the current user's verified UID.
    
    This is a convenience wrapper around get_current_user() that extracts
    just the UID string. Use this when you only need the user ID, not the
    full user dict.
    
    Raises HTTPException(401) if token is invalid.
    
    Returns:
        User's Firebase UID as a string
    """
    return firebase_auth.get_current_user_id(request)


def get_current_db_user(
    token: str | None = Depends(get_bearer_token),
    db=Depends(get_session),
):
    """Dependency resolving the verified token to the ORM ``User`` row.

    Use in routes that need an integer user id or join with the users table.
    Raises 401 for a missing/invalid token and 404 if the user has no profile
    row yet.
    """
    from .models import User

    user_info = firebase_auth.verify_token_string(token)  # raises 401
    uid = user_info.get("uid") or user_info.get("firebase_uid")
    user = db.query(User).filter(User.firebase_uid == uid).first()
    if user is None:
        raise HTTPException(
            status_code=404,
            detail="User profile not found",
        )
    return user


def require_admin(
    user: dict = Depends(get_current_user),
    session=Depends(get_session),
) -> dict:
    """Dependency that ensures the user has admin privileges.

    Authorization is deny-by-default and checked via
    ``auth_helpers.user_is_admin``:
      1. Firebase custom claim ``admin: True`` (or legacy ``role == "admin"``), OR
      2. The server-side ``users.is_admin`` DB column.

    Raises HTTPException(403) for any authenticated non-admin.
    """
    from .auth_helpers import user_is_admin

    if not user_is_admin(user, session):
        raise HTTPException(
            status_code=403,
            detail="Admin access required",
        )
    return user


def require_authenticated(user: dict = Depends(get_current_user)) -> dict:
    """Dependency that simply requires authentication.
    
    This is a no-op dependency useful for documentation and clarity.
    Routes marked with Depends(require_authenticated) are explicitly
    requiring user authentication.
    
    Returns:
        The user dict
    """
    return user


__all__ = [
    "get_bearer_token",
    "get_current_user",
    "get_current_user_id",
    "require_admin",
    "require_authenticated",
]
