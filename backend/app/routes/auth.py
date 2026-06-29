import httpx
from typing import Any

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

from ..config import FIREBASE_API_KEY, FIREBASE_AUTH_BASE_URL
from ..firebase_auth import verify_firebase_token
from ..db import SessionLocal
from ..models import User


router = APIRouter(prefix="/api/auth", tags=["auth"])


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
        raise HTTPException(status_code=502, detail=f"Firebase auth request failed: {exc}")

    try:
        data = response.json()
    except ValueError as exc:
        raise HTTPException(status_code=502, detail=f"Firebase auth response was not valid JSON: {exc}")

    if response.status_code != 200:
        error_detail = data.get("error")
        message = None
        if isinstance(error_detail, dict):
            message = error_detail.get("message")
        if not message:
            message = data.get("error_description") or data.get("error")
        raise HTTPException(status_code=400, detail=message or "Firebase auth request failed")

    return data


def _sync_user(firebase_uid: str, name: str, email: 'Optional[str]') -> dict[str, Any]:

    db = SessionLocal()
    try:
        user = db.query(User).filter(User.firebase_uid == firebase_uid).first()
        if not user:
            user = User(firebase_uid=firebase_uid, name=name or "", email=email)
            db.add(user)
            db.commit()
            db.refresh(user)
        else:
            user.name = name or user.name
            user.email = email or user.email
            db.commit()

        return {
            "id": user.id,
            "firebaseUid": user.firebase_uid,
            "name": user.name,
            "email": user.email,
        }
    finally:
        db.close()


@router.post("/login")
async def login(request: LoginRequest):
    auth_data = await _firebase_post(
        "accounts:signInWithPassword",
        {
            "email": request.email,
            "password": request.password,
            "returnSecureToken": True,
        },
    )

    id_token = auth_data.get("idToken")
    local_id = auth_data.get("localId")
    email = auth_data.get("email")

    user_name = None
    if id_token:
        lookup_data = await _firebase_post("accounts:lookup", {"idToken": id_token})
        users = lookup_data.get("users")
        if isinstance(users, list) and users:
            user_name = users[0].get("displayName")

    if not user_name:
        user_name = email.split("@")[0] if email else "User"

    user = _sync_user(local_id, user_name, email)

    return {"token": id_token, "user": user}


@router.post("/signup")
async def signup(request: SignupRequest):
    auth_data = await _firebase_post(
        "accounts:signUp",
        {
            "email": request.email,
            "password": request.password,
            "returnSecureToken": True,
        },
    )

    id_token = auth_data.get("idToken")
    local_id = auth_data.get("localId")

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

    if id_token:
        # Trigger Firebase email verification for web-based registration
        try:
            await _firebase_post(
                "accounts:sendOobCode",
                {
                    "requestType": "VERIFY_EMAIL",
                    "idToken": id_token,
                },
            )
        except Exception:
            pass

    user = _sync_user(local_id, request.name, request.email)

    return {"token": id_token, "user": user}


@router.post("/google-login")
async def google_login(request: Request):
    """Exchange/verify Firebase Google ID token.

    Client sends `Authorization: Bearer <firebaseIdToken>`.
    Backend verifies the token with Firebase Admin, then upserts the
    corresponding user record.
    """
    decoded = verify_firebase_token(request)
    firebase_uid = decoded.get("uid")
    if not firebase_uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    user = _sync_user(
        firebase_uid,
        decoded.get("name") or "",
        decoded.get("email"),
    )
    return {"user": user}


@router.get("/me")
def me(request: Request):
    decoded = verify_firebase_token(request)
    firebase_uid = decoded.get("uid")
    if not firebase_uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    return {"user": _sync_user(firebase_uid, decoded.get("name") or "", decoded.get("email"))}





