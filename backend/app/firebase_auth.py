import json
import logging
from typing import Any

import firebase_admin
from firebase_admin import auth as firebase_auth
from fastapi import HTTPException, Request

from .config import (
    FIREBASE_SERVICE_ACCOUNT_JSON,
    FIREBASE_SERVICE_ACCOUNT_FILE,
)

logger = logging.getLogger(__name__)

_firebase_initialized = False
_init_attempted = False


def init_firebase_admin() -> None:
    """Initialize Firebase Admin SDK."""
    global _firebase_initialized, _init_attempted
    if _init_attempted:
        return
    _init_attempted = True

    if firebase_admin._apps:
        _firebase_initialized = True
        return

    try:
        if FIREBASE_SERVICE_ACCOUNT_JSON:
            cred_obj = json.loads(FIREBASE_SERVICE_ACCOUNT_JSON)
            cred = firebase_admin.credentials.Certificate(cred_obj)
        elif FIREBASE_SERVICE_ACCOUNT_FILE:
            import os
            if not os.path.exists(FIREBASE_SERVICE_ACCOUNT_FILE):
                raise FileNotFoundError(
                    f"Firebase service account file not found: {FIREBASE_SERVICE_ACCOUNT_FILE}"
                )
            cred = firebase_admin.credentials.Certificate(FIREBASE_SERVICE_ACCOUNT_FILE)
        else:
            raise ValueError(
                "No service account configured. "
                "Set FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_SERVICE_ACCOUNT_FILE."
            )

        firebase_admin.initialize_app(cred)
        _firebase_initialized = True
        logger.info("Firebase Admin initialized successfully.")
    except Exception as e:
        logger.error(f"Firebase Admin initialization failed: {e}")
        _firebase_initialized = False


def verify_firebase_token(request: Request) -> dict[str, Any]:
    """Verify a Firebase ID token."""
    token = get_bearer_token(request)

    if not _init_attempted:
        init_firebase_admin()

    if not _firebase_initialized:
        raise HTTPException(
            status_code=503,
            detail="Authentication backend unavailable. Firebase Admin not initialized.",
        )

    try:
        decoded = firebase_auth.verify_id_token(token, check_revoked=True)
        return decoded
    except Exception as e:
        logger.warning(f"Token verification failed: {e}")
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired authentication token.",
        )


def verify_token_string(token: str) -> dict[str, Any]:
    """Verify a Firebase ID token passed as a raw string."""
    if not _init_attempted:
        init_firebase_admin()

    if not _firebase_initialized:
        raise ValueError("Firebase Admin not initialized")

    decoded = firebase_auth.verify_id_token(token, check_revoked=True)
    return decoded


def get_bearer_token(request: Request) -> str | None:
    """Extract bearer token from Authorization header."""
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        return auth_header[7:]
    return None
