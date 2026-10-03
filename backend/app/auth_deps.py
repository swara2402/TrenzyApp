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
from .models import User

_AGE_EXEMPT_PATHS = {
    "/api/auth/login",
    "/api/auth/signup",
    "/api/auth/google-login",
    "/api/auth/reset-password",
    "/api/auth/me",
    "/api/users/me/age-verification",
}

def _enforce_age_verification(request: Request, uid: str, db) -> None:
    """Fail closed for authenticated app routes until 13+ is verified."""
    if request.url.path in _AGE_EXEMPT_PATHS:
        return
    user = db.query(User).filter(User.firebase_uid == uid).first()
    if user is None:
        raise HTTPException(status_code=403, detail="AGE_VERIFICATION_REQUIRED")
    if user.date_of_birth is None:
        raise HTTPException(status_code=403, detail="AGE_VERIFICATION_REQUIRED")


def get_bearer_token(request: Request) -> str | None:
    """Extract bearer token from Authorization header.
    
    Returns None if no valid Authorization header found.
    """
    return firebase_auth.get_bearer_token(request)


def get_current_user(
    request: Request,
    token: str | None = Depends(get_bearer_token),
    db=Depends(get_session),
) -> dict[str, any]:
    """Verify Firebase auth and enforce the 13+ account gate."""
    if not token:
        raise HTTPException(status_code=401, detail="Missing authentication token")
    claims = firebase_auth.verify_token_string(token)
    uid = claims.get("uid") or claims.get("user_id")
    if not isinstance(uid, str) or not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")
    _enforce_age_verification(request, uid, db)
    return claims


def get_current_user_id(
    request: Request,
    db=Depends(get_session),
) -> str:
    """Return the verified UID after enforcing the 13+ account gate."""
    token = get_bearer_token(request)
    if not token:
        raise HTTPException(status_code=401, detail="Missing authentication token")
    claims = firebase_auth.verify_token_string(token)
    uid = claims.get("uid") or claims.get("user_id")
    if not isinstance(uid, str) or not uid:
        raise HTTPException(status_code=401, detail="Unable to extract user ID from authentication token")
    _enforce_age_verification(request, uid, db)
    return uid


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
