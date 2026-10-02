"""Firebase Authentication middleware for FastAPI.

Handles three authentication flows:

1. **Firebase ID token verification**: The primary flow. The Flutter app sends
   a Firebase ID token in the ``Authorization: Bearer <token>`` header. This
   module verifies it against Firebase Admin SDK and returns the decoded claims
   (including ``uid``).

2. **Dev auth bypass**: For local development without Firebase credentials.
   Sends ``Authorization: Bearer dev-token-{SECRET}`` and the server trusts
   it as ``DEV_AUTH_UID``. Locked to a single UID to prevent impersonation.

3. **Firebase Identity Toolkit**: Used for email/password login and signup.
   The backend proxies requests to Firebase's Identity Toolkit REST API,
   then generates a custom token for the client.

Why the backend handles auth instead of the Flutter SDK directly:
- The backend needs to verify tokens for every API request
- Custom tokens allow the backend to mint session tokens after login
- Server-side verification prevents token forgery
"""

import hmac as _hmac
import hashlib
import json
import logging
import os
from typing import Any
import time

import firebase_admin
from fastapi import Depends, HTTPException, Request
from firebase_admin import auth as firebase_auth

from .config import (DEV_AUTH_BYPASS, DEV_AUTH_UID, DEV_AUTH_SECRET,
                     DEV_AUTH_NAME, DEV_AUTH_EMAIL, DEV_AUTH_USERS,
                     IS_PRODUCTION, FIREBASE_PROJECT_ID,
                     FIREBASE_SERVICE_ACCOUNT_FILE, FIREBASE_SERVICE_ACCOUNT_JSON)

logger = logging.getLogger(__name__)

_firebase_initialized = False
_init_attempted = False

# Token validation cache: (token_hash) -> (decoded_claims, cache_time)
# TTL: 5 minutes. This reduces Firebase API calls but respects token revocation.
_token_cache: dict[str, tuple[dict[str, Any], float]] = {}
_TOKEN_CACHE_TTL = 300  # 5 minutes
_TOKEN_CACHE_MAX_SIZE = 10_000  # Prevent unbounded memory growth


def _resolve_service_account_source() -> str | dict[str, Any] | None:
    """Resolve a usable Firebase service account source.

    Returns either a file path or a parsed JSON object. Credentials must be
    explicitly configured via FIREBASE_SERVICE_ACCOUNT_JSON or 
    FIREBASE_SERVICE_ACCOUNT_FILE environment variables.
    
    No fallback search paths are used for security: accidentally included
    credential files in the container will not be auto-discovered.
    """
    if FIREBASE_SERVICE_ACCOUNT_JSON:
        try:
            parsed = json.loads(FIREBASE_SERVICE_ACCOUNT_JSON)
            if not isinstance(parsed, dict):
                raise ValueError("FIREBASE_SERVICE_ACCOUNT_JSON must be a JSON object")
            return parsed
        except json.JSONDecodeError as e:
            raise ValueError(
                "Invalid JSON in FIREBASE_SERVICE_ACCOUNT_JSON"
            ) from e

    if FIREBASE_SERVICE_ACCOUNT_FILE:
        candidate = FIREBASE_SERVICE_ACCOUNT_FILE
        if not os.path.isabs(candidate) and not os.path.exists(candidate):
            backend_candidate = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), candidate)
            if os.path.exists(backend_candidate):
                candidate = backend_candidate
        if not os.path.exists(candidate):
            raise FileNotFoundError(
                f"Firebase service account file not found: {candidate}"
            )
        if os.path.getsize(candidate) == 0:
            raise ValueError("Firebase service account file is empty")

        try:
            with open(candidate, "r", encoding="utf-8") as f:
                content = f.read()
        except OSError as exc:
            raise RuntimeError(
                f"Failed to read Firebase service account file {candidate}: {exc}"
            ) from exc

        try:
            parsed = json.loads(content)
            if not isinstance(parsed, dict):
                raise ValueError(f"Firebase service account file {candidate} must contain a JSON object")
            return parsed
        except json.JSONDecodeError as e:
            raise ValueError(
                f"Invalid JSON in {candidate}: {e}"
            ) from e

    # No credentials configured — fail closed, require explicit env vars
    return None


def init_firebase_admin() -> bool:
    """Initialize Firebase Admin SDK. Returns True if initialized, False otherwise."""
    global _firebase_initialized, _init_attempted
    if _init_attempted:
        return _firebase_initialized
    _init_attempted = True

    if firebase_admin._apps:
        _firebase_initialized = True
        return True

    try:
        cred_source = _resolve_service_account_source()
        if cred_source is None:
            _firebase_initialized = False
            return False

        cred = firebase_admin.credentials.Certificate(cred_source)
        firebase_admin.initialize_app(cred)
        _firebase_initialized = True
        logger.info("Firebase Admin initialized successfully.")
        return True
    except json.JSONDecodeError as e:
        logger.error(
            "Firebase Admin initialization failed: invalid JSON in FIREBASE_SERVICE_ACCOUNT_JSON: %s",
            e,
        )
        _firebase_initialized = False
        return False
    except Exception as e:
        logger.error(
            "Firebase Admin initialization failed: %s. "
            "Provide a valid FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_SERVICE_ACCOUNT_FILE.",
            e,
        )
        _firebase_initialized = False
        return False





# ─────────────────────────────────────────────────────────────────────────
# Credential-less ID-token verification (Google public signing certificates)
# ─────────────────────────────────────────────────────────────────────────
# Firebase ID tokens are RS256 JWTs signed by Google; the public
# certificates are published at the endpoint below (this is the same
# signature-trust chain the Admin SDK uses internally). Verifying against
# them — signature, exp/iat, aud == project, iss == securetoken issuer,
# uid == sub — is real cryptographic verification suitable for production.
# What it cannot do is check token *revocation* (that needs Admin SDK
# credentials); set up FIREBASE_SERVICE_ACCOUNT_* to get that as well.
_GOOGLE_CERTS_URL = (
    "https://www.googleapis.com/robot/v1/metadata/"
    "x509/securetoken@system.gserviceaccount.com"
)
_public_cert_keys: dict[str, Any] = {}   # kid -> cryptography public key
_public_cert_keys_fetched_at: float = 0.0
_PUBLIC_CERT_TTL = 3600  # Google rotates keys infrequently; hourly refresh


def _get_public_cert_keys(force_refresh: bool = False) -> dict[str, Any]:
    """Fetch (and cache) Google's Firebase Auth signing certificates."""
    global _public_cert_keys, _public_cert_keys_fetched_at
    import requests

    now = time.time()
    if (
        _public_cert_keys
        and not force_refresh
        and now - _public_cert_keys_fetched_at < _PUBLIC_CERT_TTL
    ):
        return _public_cert_keys

    try:
        resp = requests.get(_GOOGLE_CERTS_URL, timeout=10)
        resp.raise_for_status()
        certs = resp.json()
    except Exception as e:
        logger.error("Failed to fetch Firebase public signing certs: %s", e)
        if _public_cert_keys:  # serve stale keys rather than failing auth
            return _public_cert_keys
        raise HTTPException(
            status_code=503,
            detail="Authentication backend unavailable.",
        )

    from cryptography.x509 import load_pem_x509_certificate

    keys: dict[str, Any] = {}
    for kid, pem in certs.items():
        try:
            keys[kid] = load_pem_x509_certificate(pem.encode()).public_key()
        except Exception:
            logger.warning("Unparseable cert for kid=%s, skipping", kid)
    _public_cert_keys = keys
    _public_cert_keys_fetched_at = now
    return keys


def _verify_id_token_public_certs(token: str) -> dict[str, Any]:
    """Verify a Firebase ID token against Google's public certificates.

    Mirrors the checks firebase-admin performs (minus revocation). Raises
    HTTPException(401) for invalid/expired tokens, 503 when the server is
    not configured for it (no FIREBASE_PROJECT_ID).
    """
    import jwt as pyjwt

    if not FIREBASE_PROJECT_ID:
        raise HTTPException(
            status_code=503,
            detail=(
                "Authentication backend unavailable. Set FIREBASE_PROJECT_ID "
                "(recommended) or FIREBASE_SERVICE_ACCOUNT_* in the backend "
                "environment to enable Firebase token verification."
            ),
        )

    try:
        header = pyjwt.get_unverified_header(token)
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid authentication token.")

    kid = header.get("kid")
    if not isinstance(kid, str) or not kid:
        raise HTTPException(status_code=401, detail="Invalid authentication token (missing kid in header).")

    key = _get_public_cert_keys().get(kid)
    if key is None:
        # Unknown kid → Google may have rotated certs; refresh once.
        key = _get_public_cert_keys(force_refresh=True).get(kid)
    if key is None:
        raise HTTPException(status_code=401, detail="Invalid token signature key.")

    try:
        claims = pyjwt.decode(
            token,
            key,
            algorithms=["RS256"],
            audience=FIREBASE_PROJECT_ID,
            issuer=f"https://securetoken.google.com/{FIREBASE_PROJECT_ID}",
            options={"require": ["exp", "iat", "aud", "iss", "sub"]},
            leeway=60,  # small tolerance for clock skew
        )
    except pyjwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=401,
            detail="Authentication token has expired. Please sign in again.",
        )
    except pyjwt.InvalidTokenError as e:
        logger.warning("Public-cert token verification failed: %s", e)
        raise HTTPException(
            status_code=401, detail="Invalid or expired authentication token.",
        )

    uid = claims.get("sub")
    if not uid or len(uid) > 128:
        raise HTTPException(status_code=401, detail="Invalid authentication token.")
    # Match the claim shape firebase-admin returns.
    claims["uid"] = uid
    claims["user_id"] = uid
    return claims


def make_dev_token(uid: str, secret: str) -> str:
    """Mint a dev bypass token: ``dev-token-{uid}:{hmac_sha256(secret, uid)}``.

    Only useful in local development. The server validates both that the uid
    matches DEV_AUTH_UID and that the HMAC signature matches DEV_AUTH_SECRET.
    """
    sig = _hmac.new(secret.encode(), uid.encode(), hashlib.sha256).hexdigest()
    return f"dev-token-{uid}:{sig}"


def _verify_dev_token(token: str) -> dict[str, Any] | None:
    """Validate a signed dev bypass token.

    Returns the user dict on success, or None if the token is not a dev token
    or fails validation. Raises HTTPException(503) if attempted in production.
    """
    if not token.startswith("dev-token-"):
        return None

    # SECURITY: Production MUST never accept dev tokens. This is enforced at
    # import time in config.py, plus here as defense-in-depth.
    if IS_PRODUCTION:
        logger.critical(
            "SECURITY VIOLATION: Dev auth bypass attempted in production (APP_ENV=%s). "
            "Refusing to verify dev token.",
            os.getenv("APP_ENV")
        )
        raise HTTPException(
            status_code=503,
            detail="Authentication backend unavailable.",
        )

    raw = token[len("dev-token-"):]
    uid, sep, signature = raw.partition(":")
    if not sep or not uid or not signature:
        logger.warning("Rejected malformed dev token (missing signature).")
        raise HTTPException(
            status_code=401,
            detail="Invalid dev token format.",
        )

    # The bypass is locked to a small allowlist (the primary identity plus any
    # extra identities declared in DEV_AUTH_USERS). Every identity still needs a
    # valid signed HMAC token, so this does not weaken the impersonation guard —
    # it just lets the local demo exercise multi-user flows over live sockets
    # instead of having to fake the second member via direct DB rows.
    meta = DEV_AUTH_USERS.get(uid)
    if uid != DEV_AUTH_UID and not meta:
        logger.warning(
            "Rejected dev token for unconfigured uid %s "
            "(only the configured DEV_AUTH_UID or DEV_AUTH_USERS identities "
            "are allowed).",
            uid,
        )
        raise HTTPException(status_code=401, detail="Invalid dev token.")

    # Validate the HMAC signature with a timing-safe compare so the shared
    # secret cannot be brute-forced via response timing.
    expected_sig = _hmac.new(
        (DEV_AUTH_SECRET or "").encode(), uid.encode(), hashlib.sha256
    ).hexdigest()
    if not DEV_AUTH_SECRET or not _hmac.compare_digest(expected_sig, signature):
        logger.warning("Rejected dev token with invalid signature.")
        raise HTTPException(
            status_code=401,
            detail="Invalid dev token credentials.",
        )

    claims: dict[str, Any] = {"uid": uid, "firebase_uid": uid, "bypass": True}
    if meta:
        claims["name"] = meta.get("name") or DEV_AUTH_NAME or "Demo User"
        claims["email"] = meta.get("email") or DEV_AUTH_EMAIL or ""
    else:
        claims["name"] = DEV_AUTH_NAME or "Demo User"
        claims["email"] = DEV_AUTH_EMAIL or ""
    logger.info(
        "Dev auth bypass authenticated local uid=%s (APP_ENV=%s)",
        uid,
        os.getenv("APP_ENV"),
    )
    return claims


def verify_token_string(token: str) -> dict[str, Any]:
    """Verify a Firebase ID token passed as a raw string.

    Implements token caching (TTL 5 min) to reduce Firebase API calls while
    respecting token expiration and revocation. Always validates token claims
    and extracts UID properly.
    """
    # Dev bypass — locked to the configured UID and signed with DEV_AUTH_SECRET.
    if DEV_AUTH_BYPASS:
        dev_user = _verify_dev_token(token)
        if dev_user is not None:
            return dev_user

    if not _init_attempted:
        init_firebase_admin()

    if not _firebase_initialized:
        # Without Admin credentials we can still verify real Firebase ID
        # tokens cryptographically against Google's public signing
        # certificates — this is production-grade signature verification
        # (revocation checks additionally require the Admin SDK path).
        if FIREBASE_PROJECT_ID:
            return _verify_id_token_public_certs(token)

        # Misconfiguration below this point: no Admin credentials AND no
        # project ID to validate public-cert tokens against.
        if DEV_AUTH_BYPASS:
            dev_user = _verify_dev_token(token)
            if dev_user is not None:
                logger.warning(
                    "Firebase Admin not initialized in development; DEV_AUTH_BYPASS "
                    "authenticated the configured local uid."
                )
                return dev_user
        if IS_PRODUCTION:
            logger.critical(
                "SECURITY: Firebase token verification unavailable in production. "
                "Refusing unsigned access. Set FIREBASE_PROJECT_ID (public-cert "
                "verification) and/or FIREBASE_SERVICE_ACCOUNT_JSON / "
                "FIREBASE_SERVICE_ACCOUNT_FILE (full Admin SDK verification)."
            )
        logger.error(
            "Token verification rejected: no Firebase credential source configured. "
            "Set FIREBASE_PROJECT_ID for public-cert verification, or "
            "FIREBASE_SERVICE_ACCOUNT_JSON / FIREBASE_SERVICE_ACCOUNT_FILE for "
            "the full Admin SDK path."
        )
        raise HTTPException(
            status_code=503,
            detail=(
                "Authentication backend unavailable. Firebase is not "
                "configured: set FIREBASE_PROJECT_ID or service-account "
                "credentials on the server."
            ),
        )

    # Check token cache before calling Firebase API
    token_hash = hashlib.sha256(token.encode()).hexdigest()
    now = time.time()
    if token_hash in _token_cache:
        cached_claims, cache_time = _token_cache[token_hash]
        if now - cache_time < _TOKEN_CACHE_TTL:
            # Cache hit: validate expiration is still in future
            exp = cached_claims.get("exp", 0)
            if exp > now:
                logger.debug("Token verified from cache (uid=%s)", cached_claims.get("uid", "unknown"))
                return cached_claims
            else:
                # Cache expired, remove stale entry
                del _token_cache[token_hash]
    
    # Cache miss or expired: verify with Firebase API
    try:
        decoded = firebase_auth.verify_id_token(token, check_revoked=True)
        
        # Validate required claims
        uid = decoded.get("uid")
        if not uid:
            logger.error(
                "Token verification succeeded but UID claim missing. "
                "Firebase token structure may be invalid."
            )
            raise HTTPException(
                status_code=401,
                detail="Invalid authentication token.",
            )
        
        # Ensure token has not already expired
        exp = decoded.get("exp", 0)
        if exp <= now:
            logger.warning("Token verification succeeded but token is expired (exp=%s, now=%s)", exp, now)
            raise HTTPException(
                status_code=401,
                detail="Authentication token has expired. Please sign in again.",
            )
        
        # Cache the verified token
        if len(_token_cache) > _TOKEN_CACHE_MAX_SIZE:
            # Simple eviction: remove oldest entries
            oldest_key = min(_token_cache.keys(), key=lambda k: _token_cache[k][1])
            del _token_cache[oldest_key]
        _token_cache[token_hash] = (decoded, now)
        
        logger.debug("Token verified successfully (uid=%s)", uid)
        return decoded
    except firebase_auth.InvalidIdTokenError as e:
        logger.warning("Token verification failed (invalid token): %s", e)
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired authentication token.",
        )
    except firebase_auth.ExpiredIdTokenError as e:
        logger.warning("Token verification failed (expired token): %s", e)
        raise HTTPException(
            status_code=401,
            detail="Authentication token has expired. Please sign in again.",
        )
    except firebase_auth.RevokedIdTokenError as e:
        logger.warning("Token verification failed (revoked token): %s", e)
        raise HTTPException(
            status_code=401,
            detail="Authentication token has been revoked. Please sign in again.",
        )
    except Exception as e:
        logger.error(
            "Token verification failed with unexpected error: %s. "
            "This may indicate a Firebase project mismatch between the client "
            "and the service account configured on the server.",
            e,
        )
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired authentication token.",
        )


def get_bearer_token(request: Request) -> str | None:
    """Extract bearer token from Authorization header."""
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        return auth_header[7:]
    return None


def get_current_user(token: str | None = Depends(get_bearer_token)) -> dict[str, Any]:
    if not token:
        raise HTTPException(
            status_code=401,
            detail="Missing authentication token",
        )
    return verify_token_string(token)


# Backward-compatible alias — many route files import this name.
def verify_firebase_token(request: Request) -> dict[str, Any]:
    """Extract and verify the bearer token from a Request object."""
    token = get_bearer_token(request)
    if not token:
        raise HTTPException(
            status_code=401,
            detail="Missing authentication token",
        )
    return verify_token_string(token)


def get_current_user_id(request: Request) -> str:
    """Extract and verify the current authenticated user's UID from the request.
    
    This is a convenience helper that validates the token and returns just the
    UID, raising HTTPException(401) if no valid token is present.
    
    Use this in endpoints that need the user ID:
        @router.get("/")
        def my_endpoint(user_id: str = Depends(get_current_user_id)):
            # user_id is guaranteed to be the authenticated user's Firebase UID
    """
    decoded = verify_firebase_token(request)
    uid = decoded.get("uid") or decoded.get("user_id")
    if not uid or not isinstance(uid, str):
        raise HTTPException(
            status_code=401,
            detail="Unable to extract user ID from authentication token",
        )
    return uid