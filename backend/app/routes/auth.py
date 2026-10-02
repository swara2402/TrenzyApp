"""Authentication endpoints (login, signup, Google, password reset).

Handles the full auth lifecycle:

- **Email/password login**: Proxies to Firebase Identity Toolkit, syncs user
  to the local database, returns a custom token.
- **Email/password signup**: Creates Firebase account, sets display name,
  triggers email verification, initializes default style persona and preferences.
- **Google login**: Verifies a Google-signed Firebase ID token and syncs the user.
- **Password reset**: Sends a Firebase password reset email.
- **Me**: Returns the current user's profile.

The backend uses Firebase Identity Toolkit for email/password operations because
Flutter's web auth expects server-side email/password endpoints. The backend then
mints a custom token that the Flutter client uses for subsequent requests.
"""

import logging
from typing import Any, Optional

import httpx
from fastapi import Request, APIRouter, Depends, HTTPException
from firebase_admin import auth as firebase_admin_auth
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ..config import (
    DEV_AUTH_BYPASS,
    FIREBASE_API_KEY,
    FIREBASE_AUTH_BASE_URL,
)
from ..db import get_session
from ..firebase_auth import init_firebase_admin
from ..auth_deps import get_current_user
from ..models import User, StylePersona, UserPreference
from ..errors import ValidationError
from ..network import get_client_ip

logger = logging.getLogger(__name__)

import time
from collections import defaultdict

# Process-local fallback (dev/test only — single worker)
_auth_rate_local: dict[str, list[float]] = defaultdict(list)
_AUTH_LIMIT = 20
_AUTH_WINDOW = 60.0


def _client_ip(request) -> str:
    if request is None:
        return "unknown"
    return get_client_ip(request)


async def _check_auth_rate_redis(ip: str) -> "bool | None":
    """Increment the Redis sliding-window counter for *ip*.

    Returns:
        True  – request is within the rate limit and should be allowed.
        False – request exceeds the rate limit and should be rejected.
        None  – Redis is unavailable; caller must use the local fallback.

    Uses a Redis sorted set (ZADD + ZREMRANGEBYSCORE + ZCARD) pipeline so
    the check-and-increment is atomic across workers.
    """
    try:
        from ..socket_server import _redis_client, _redis_available
        if not _redis_available or not _redis_client:
            return None  # signal: Redis not available, use local fallback

        key = f"auth_rate:{ip}"
        now = time.time()
        window_start = now - _AUTH_WINDOW

        pipe = _redis_client.pipeline()
        # Remove stale timestamps outside the window
        pipe.zremrangebyscore(key, "-inf", window_start)
        # Add current timestamp as member so each attempt is unique
        pipe.zadd(key, {str(now): now})
        # Count members in window
        pipe.zcard(key)
        # Expire the key after 2× the window to avoid Redis memory leaks
        pipe.expire(key, int(_AUTH_WINDOW * 2))
        results = await pipe.execute()
        count: int = int(results[2])  # zcard result — cast Any → int
        return count <= _AUTH_LIMIT
    except Exception as exc:
        logger.warning("Redis auth rate check failed (%s); using local fallback", exc)
        return None  # signal: use local fallback


def _check_auth_rate_local(ip: str) -> None:
    now = time.time()
    window_start = now - _AUTH_WINDOW
    bucket = _auth_rate_local[ip]
    alive = [t for t in bucket if t >= window_start]
    if len(alive) >= _AUTH_LIMIT:
        raise HTTPException(status_code=429, detail="Too many auth attempts. Try again shortly.")
    alive.append(now)
    _auth_rate_local[ip] = alive


async def _check_auth_rate(request) -> None:
    """Rate-limit authentication attempts per IP.

    Uses Redis when available (multi-worker safe) and falls back to the
    process-local dict in development/test environments.
    """
    from fastapi import HTTPException
    ip = _client_ip(request)
    allowed = await _check_auth_rate_redis(ip)
    if allowed is None:
        # Redis unavailable — use local fallback
        _check_auth_rate_local(ip)
    elif not allowed:
        raise HTTPException(status_code=429, detail="Too many auth attempts. Try again shortly.")


router = APIRouter(prefix="/api/auth", tags=["auth"])


def _generate_custom_token(firebase_uid: str) -> str | None:
    if not init_firebase_admin():
        logger.warning("Firebase Admin not initialized; cannot generate custom token")
        return None
    try:
        token = firebase_admin_auth.create_custom_token(firebase_uid)
        if isinstance(token, bytes):
            return token.decode("utf-8")
        return str(token)
    except Exception as e:
        logger.error("Failed to create custom token: %s", e)
        return None


class LoginRequest(BaseModel):
    email: str
    password: str


class SignupRequest(BaseModel):
    name: str
    email: str
    password: str


def _firebase_url(path: str) -> str:
    if not FIREBASE_API_KEY:
        raise HTTPException(
            status_code=500,
            detail="Missing Firebase API key in backend configuration. Set FIREBASE_API_KEY.",
        )
    return f"{FIREBASE_AUTH_BASE_URL}/{path}?key={FIREBASE_API_KEY}"


async def _firebase_post(path: str, payload: dict[str, Any]) -> dict[str, Any]:
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(_firebase_url(path), json=payload)
    except httpx.RequestError as exc:
        logger.error("Firebase auth request failed: %s", exc)
        raise HTTPException(
            status_code=502, detail="Firebase auth request failed"
        )

    try:
        data: dict[str, Any] = response.json()
    except ValueError as exc:
        logger.error("Firebase auth response was not valid JSON: %s", exc)
        raise HTTPException(
            status_code=502, detail="Firebase auth response was not valid JSON"
        )

    if response.status_code != 200:
        error_detail = data.get("error")
        message: Optional[str] = None
        if isinstance(error_detail, dict):
            message = error_detail.get("message")
        if not message:
            raw = data.get("error_description") or data.get("error")
            message = str(raw) if raw is not None else None
        raise HTTPException(
            status_code=400, detail=message or "Firebase auth request failed"
        )

    return data


def _default_display_name(firebase_uid: str, email: Optional[str]) -> str:
    """Derive a friendly display name when none is provided (placeholder/dev)."""
    if email:
        handle = email.split("@")[0].strip()
        if handle:
            return handle[:1].upper() + handle[1:]
    return "Trenzy Explorer"


def _sync_user(session: Session, firebase_uid: str, name: str, email: Optional[str]) -> dict[str, Any]:
    user = session.query(User).filter(User.firebase_uid == firebase_uid).first()
    is_new = user is None
    if is_new:
        user = User(
            firebase_uid=firebase_uid,
            name=name or _default_display_name(firebase_uid, email),
            email=email,
        )
        session.add(user)
        session.flush()

        persona = StylePersona(
            user_firebase_uid=firebase_uid,
            name="Urban Minimalist",
            description="Clean lines, neutral tones, and effortless sophistication.",
            keywords=["minimal", "clean", "neutral"],
            vibe="Sophisticated Minimalist",
        )
        session.add(persona)

        prefs = UserPreference(user_firebase_uid=firebase_uid)
        session.add(prefs)
        session.commit()
        session.refresh(user)
    else:
        user.name = name or user.name or _default_display_name(firebase_uid, email)
        user.email = email or user.email
        session.commit()

    return {
        "id": user.id,
        "firebaseUid": user.firebase_uid,
        "name": user.name,
        "email": user.email,
        "avatarUrl": user.avatar_url or "",
    }


@router.post("/login")
async def login(request: LoginRequest, http_request: Request, session: Session = Depends(get_session)):
    await _check_auth_rate(http_request)
    if not request.email or not request.email.strip():
        raise HTTPException(status_code=400, detail="Email is required")
    if not request.password:
        raise HTTPException(status_code=400, detail="Password is required")

    auth_data = await _firebase_post(
        "accounts:signInWithPassword",
        {
            "email": request.email,
            "password": request.password,
            "returnSecureToken": True,
        },
    )

    id_token: Optional[str] = auth_data.get("idToken")
    local_id: Optional[str] = auth_data.get("localId")
    email: Optional[str] = auth_data.get("email")

    if not local_id:
        raise HTTPException(status_code=502, detail="Firebase did not return a user ID (localId missing).")

    user_name: Optional[str] = None
    if id_token:
        lookup_data = await _firebase_post("accounts:lookup", {"idToken": id_token})
        users = lookup_data.get("users")
        if isinstance(users, list) and users:
            user_name = users[0].get("displayName")

    if not user_name:
        user_name = email.split("@")[0] if email else "User"

    user = _sync_user(session, local_id, user_name, email)

    custom_token = _generate_custom_token(local_id)
    if not custom_token:
        raise HTTPException(
            status_code=500,
            detail="Failed to generate authentication token. Firebase Admin may not be initialized.",
        )

    return {"token": custom_token, "user": user}


@router.post("/signup")
async def signup(request: SignupRequest, http_request: Request, session: Session = Depends(get_session)):
    await _check_auth_rate(http_request)
    if not request.email or not request.email.strip():
        raise ValidationError("email", "Email is required")
    if not request.password or len(request.password) < 6:
        raise ValidationError("password", "Password must be at least 6 characters")

    # Firebase signup is required; no bypass allowed
    auth_data = await _firebase_post(
        "accounts:signUp",
        {
            "email": request.email,
            "password": request.password,
            "returnSecureToken": True,
        },
    )
    id_token: Optional[str] = auth_data.get("idToken")
    local_id: Optional[str] = auth_data.get("localId")

    if not local_id:
        raise HTTPException(status_code=502, detail="Firebase did not return a user ID (localId missing).")

    if id_token and request.name:
        update_data = await _firebase_post(
            "accounts:update",
            {
                "idToken": id_token,
                "displayName": request.name,
                "returnSecureToken": True,
            },
        )
        id_token = update_data.get("idToken") or id_token
        local_id = update_data.get("localId") or local_id

    # Re-check after the update call which may have returned a refreshed localId
    if not local_id:
        raise HTTPException(status_code=502, detail="Firebase lost the user ID after profile update.")

    if id_token and not DEV_AUTH_BYPASS:
        # Trigger Firebase email verification for web-based registration (skip in dev mode)
        try:
            await _firebase_post(
                "accounts:sendOobCode",
                {
                    "requestType": "VERIFY_EMAIL",
                    "idToken": id_token,
                },
            )
            # SECURITY: Don't log email addresses (PII)
            logger.info("Verification email sent successfully")
        except Exception as e:
            # SECURITY: Don't log email addresses (PII)
            logger.error("Failed to send verification email: %s", e)

    user = _sync_user(session, local_id, request.name, request.email)

    custom_token = _generate_custom_token(local_id)
    if not custom_token:
        raise HTTPException(
            status_code=500,
            detail="Failed to generate authentication token. Firebase Admin may not be initialized.",
        )

    return {"token": custom_token, "user": user}


@router.post("/google-login")
async def google_login(
    http_request: Request,
    user_data: dict = Depends(get_current_user), session: Session = Depends(get_session)
):
    await _check_auth_rate(http_request)
    """Exchange/verify Firebase Google ID token."""
    firebase_uid = user_data.get("uid")
    if not firebase_uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    user = _sync_user(
        session,
        firebase_uid,
        user_data.get("name") or "",
        user_data.get("email"),
    )
    return {"user": user}


class ResetPasswordRequest(BaseModel):
    email: str


@router.post("/reset-password")
async def reset_password(request: ResetPasswordRequest, http_request: Request):
    await _check_auth_rate(http_request)
    """Send password reset email via Firebase."""
    if not request.email or not request.email.strip():
        raise HTTPException(status_code=400, detail="Email is required")
        
    await _firebase_post(
        "accounts:sendOobCode",
        {
            "requestType": "PASSWORD_RESET",
            "email": request.email,
        },
    )
    return {"status": "sent"}


@router.get("/me")
def me(user_data: dict = Depends(get_current_user), session: Session = Depends(get_session)):
    firebase_uid = user_data.get("uid")
    if not firebase_uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    return {
        "user": _sync_user(
            session,
            firebase_uid,
            user_data.get("name") or "",
            user_data.get("email"),
        )
    }