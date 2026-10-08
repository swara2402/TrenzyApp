"""Centralized configuration loaded from environment variables.

All settings are read from ``backend/.env`` (via python-dotenv) at import time.
This module is imported by every other module, so it acts as the single source
of truth for configuration. If a required variable is missing, a clear error
is raised at startup rather than failing silently at runtime.

Why this design:
- Avoids scattering ``os.getenv()`` calls across the codebase
- Makes it easy to see all configuration at a glance
- Fails fast on missing required config (POSTGRES_PASSWORD, FIREBASE_API_KEY)
"""

import logging
import os
import sys
from pathlib import Path

from .launch_flags import BETA_COMMERCE_ENABLED

from dotenv import load_dotenv

logger = logging.getLogger(__name__)

# Load env from the backend/ directory (config-file-relative, not CWD-relative).
_backend_dir = Path(__file__).resolve().parent.parent
_dotenv_path = _backend_dir / ".env"
load_dotenv(_dotenv_path)


# Database connection
# ──────────────────────────────────────────────────────────────
# DB_HOST defaults to 'localhost' for local dev, but docker-compose
# overrides it to 'db' (the PostgreSQL container name).
DB_HOST = os.getenv("DB_HOST") or "localhost"
# Handle empty string case (common when GitHub secrets are missing)
db_port_str = os.getenv("DB_PORT")
try:
    DB_PORT = int(db_port_str) if db_port_str and db_port_str.strip() else 5432
except (ValueError, TypeError):
    DB_PORT = 5432
POSTGRES_DB = os.getenv("POSTGRES_DB") or "trenzy"
POSTGRES_USER = os.getenv("POSTGRES_USER") or "postgres"
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD")
if not POSTGRES_PASSWORD or not POSTGRES_PASSWORD.strip():
    raise RuntimeError("POSTGRES_PASSWORD environment variable is required.")

# Firebase Admin SDK
# ──────────────────────────────────────────────────────────────
# A service account enables the full Admin SDK path (token revocation
# checks, user management). Without one, ID tokens are still verified
# for real against Google's public signing certificates — see
# FIREBASE_PROJECT_ID and firebase_auth.verify_token_string.
FIREBASE_SERVICE_ACCOUNT_FILE = os.getenv("FIREBASE_SERVICE_ACCOUNT_FILE")
FIREBASE_SERVICE_ACCOUNT_JSON = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")

# Firebase project ID (e.g. "trenzy2400"). Required for credential-less
# ID-token verification against Google's public certificates; the token's
# aud/iss claims are checked against it.
FIREBASE_PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID")

# Firebase Web Auth (Identity Toolkit)
# ──────────────────────────────────────────────────────────────
# Flutter's email/password auth uses Identity Toolkit endpoints.
# FIREBASE_API_KEY is required to build the Identity Toolkit URL.
FIREBASE_API_KEY = os.getenv("FIREBASE_API_KEY")

# Identity Toolkit base URL (rarely needs changing)
FIREBASE_AUTH_BASE_URL = os.getenv(
    "FIREBASE_AUTH_BASE_URL",
    "https://identitytoolkit.googleapis.com/v1",
)

# Application environment
# ──────────────────────────────────────────────────────────────
# One of: "development" (default), "staging", "production". Anything that is
# not explicitly a local/development value is treated as production and causes
# the auth bypass to be refused. Set APP_ENV=production explicitly in
# staging/prod deployments.
# Fail closed: default to production so a bare deployment can never silently
# start in development mode. Local environments MUST explicitly set
# APP_ENV=development (run_dev.py, .env, and docker-compose all do this).
APP_ENV = os.getenv("APP_ENV", "production").strip().lower()
LOCAL_ENVS = {"development", "dev", "local", "test"}
IS_PRODUCTION = APP_ENV not in LOCAL_ENVS

# Trust X-Forwarded-For only when the service sits behind a known reverse
# proxy (nginx, ALB, etc.). When disabled, the direct peer address from the
# TCP connection is used for rate limiting and IP attribution so that clients
# cannot spoof their origin by sending their own X-Forwarded-For header.
TRUST_X_FORWARDED_FOR = os.getenv("TRUST_X_FORWARDED_FOR", "").lower() in ("true", "1", "yes")

# Development auth bypass
# ──────────────────────────────────────────────────────────────
# When enabled, accepts "Authorization: Bearer dev-token-{uid}:{HMAC}" where
# HMAC = HMAC-SHA256(DEV_AUTH_SECRET, uid). DEV_AUTH_UID is the primary
# identity that must always be configured; DEV_AUTH_USERS extends it with a
# small comma-separated allowlist of extra demo identities of the form
# "uid:Display Name:email" (useful for exercising multi-user flows like blend
# chat/swipes locally — each identity still requires a valid per-uid HMAC, and
# the whole feature is refused outright in production). Signatures are
# verified with a timing-safe compare so the shared secret cannot be guessed.
# NEVER enable in production.
DEV_AUTH_BYPASS = os.getenv("DEV_AUTH_BYPASS", "").lower() in ("true", "1", "yes")
DEV_AUTH_UID = os.getenv("DEV_AUTH_UID", "")
DEV_AUTH_SECRET = os.getenv("DEV_AUTH_SECRET", "")
# Optional default display name/email for the primary DEV_AUTH_UID (used when
# the uid is not listed in DEV_AUTH_USERS).
DEV_AUTH_NAME = os.getenv("DEV_AUTH_NAME", "")
DEV_AUTH_EMAIL = os.getenv("DEV_AUTH_EMAIL", "")


def _parse_dev_users(raw: str) -> dict[str, dict[str, str]]:
    """Parse DEV_AUTH_USERS="uid:Name:email,uid2:Name2:email2" into a map."""
    parsed: dict[str, dict[str, str]] = {}
    if not raw:
        return parsed
    for entry in raw.split(","):
        entry = entry.strip()
        if not entry:
            continue
        parts = entry.split(":")
        uid = (parts[0] or "").strip()
        if not uid:
            continue
        name = (parts[1] or "").strip() if len(parts) > 1 else ""
        email = (parts[2] or "").strip() if len(parts) > 2 else ""
        parsed[uid] = {"name": name, "email": email}
    return parsed


DEV_AUTH_USERS = _parse_dev_users(os.getenv("DEV_AUTH_USERS", ""))

# Fail closed: the auth bypass must never be active outside a local environment.
# Refuse to start rather than silently serving unverified requests.
if DEV_AUTH_BYPASS and IS_PRODUCTION:
    raise RuntimeError(
        "Refusing to start: DEV_AUTH_BYPASS is enabled but APP_ENV=%r. "
        "Set APP_ENV=development (local dev only) or disable DEV_AUTH_BYPASS. "
        "This MUST be disabled in every non-local environment." % APP_ENV
    )

# The bypass is only safe when locked to a single UID AND protected by a
# shared secret. Without a secret, anyone could forge "dev-token-{uid}".
if DEV_AUTH_BYPASS and (not DEV_AUTH_UID or not DEV_AUTH_SECRET):
    raise RuntimeError(
        "Refusing to start: DEV_AUTH_BYPASS=true requires both DEV_AUTH_UID "
        "(the single allowed local uid) and DEV_AUTH_SECRET (used to sign "
        "dev tokens). Set them in backend/.env or disable DEV_AUTH_BYPASS."
    )

# Upload directory for local file storage (avatars, post attachments, etc.)
UPLOAD_DIR = os.getenv("UPLOAD_DIR", str(_backend_dir / "uploads"))
# Public base URL for served uploads (e.g. http://localhost:8000/uploads)
UPLOAD_BASE_URL = os.getenv("UPLOAD_BASE_URL", "http://localhost:8000/uploads")

# Payment processing mode
# ──────────────────────────────────────────────────────────────
# PAYMENTS_MODE determines whether to use real payment processing or simulation:
#
# "simulation" (default in development):
#   - Returns fake successful payments
#   - No real payment processing
#   - No credentials required
#   - Development/testing only
#
# "razorpay" (production mode):
#   - Requires RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET
#   - Processes real payments
#   - Validates webhook signatures
#   - Fails startup if credentials missing
#
PAYMENTS_MODE = os.getenv("PAYMENTS_MODE", "simulation").strip().lower()

# Validate PAYMENTS_MODE
if PAYMENTS_MODE not in ("simulation", "razorpay"):
    raise RuntimeError(
        f"Invalid PAYMENTS_MODE: {PAYMENTS_MODE!r}. "
        "Must be 'simulation' or 'razorpay'."
    )

# Production mode must use Razorpay, not simulation
if IS_PRODUCTION and BETA_COMMERCE_ENABLED and PAYMENTS_MODE == "simulation":
    raise RuntimeError(
        "Refusing to start: PAYMENTS_MODE=simulation in production (APP_ENV=%r). "
        "Set PAYMENTS_MODE=razorpay and provide Razorpay credentials." % APP_ENV
    )

# Razorpay credentials (required in production)
RAZORPAY_KEY_ID = os.getenv("RAZORPAY_KEY_ID", "")
RAZORPAY_KEY_SECRET = os.getenv("RAZORPAY_KEY_SECRET", "")
RAZORPAY_WEBHOOK_SECRET = os.getenv("RAZORPAY_WEBHOOK_SECRET", "")

# Secret used to sign hosted checkout URLs. Optional: falls back to
# RAZORPAY_WEBHOOK_SECRET, and in development to a fixed dev-only value.
PAYMENT_CHECKOUT_SECRET = os.getenv("PAYMENT_CHECKOUT_SECRET", "")

if PAYMENTS_MODE == "razorpay":
    if not RAZORPAY_KEY_ID or not RAZORPAY_KEY_SECRET:
        raise RuntimeError(
            "Refusing to start: PAYMENTS_MODE=razorpay but Razorpay credentials missing. "
            "Set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET environment variables."
        )
    if IS_PRODUCTION and not RAZORPAY_WEBHOOK_SECRET:
        raise RuntimeError(
            "Refusing to start: PAYMENTS_MODE=razorpay in production but "
            "RAZORPAY_WEBHOOK_SECRET is missing. Payment verification would be "
            "forgeable without it. Set RAZORPAY_WEBHOOK_SECRET."
        )
    if not RAZORPAY_WEBHOOK_SECRET:
        logger = __import__("logging").getLogger(__name__)
        logger.warning(
            "RAZORPAY_WEBHOOK_SECRET not set (non-production). Signature "
            "verification will FAIL CLOSED: /api/payments/verify will reject "
            "all payments until the secret is configured."
        )


def validate_startup_config() -> list[str]:
    """Validate required configuration for the current environment.

    Returns a list of warning/error messages. In production, missing required
    config causes a fatal error. In development, it returns warnings.
    """
    errors: list[str] = []
    warnings: list[str] = []

    if not FIREBASE_API_KEY:
        msg = "FIREBASE_API_KEY is not set — email/password auth will fail."
        if IS_PRODUCTION:
            errors.append(msg)
        else:
            warnings.append(msg)

    if not FIREBASE_SERVICE_ACCOUNT_FILE and not FIREBASE_SERVICE_ACCOUNT_JSON:
        msg = (
            "No Firebase Admin SDK credentials configured. "
            "Set FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_SERVICE_ACCOUNT_FILE."
        )
        if IS_PRODUCTION:
            errors.append(msg)
        else:
            warnings.append(msg)

    if IS_PRODUCTION:
        # Check Redis configuration
        redis_url = os.getenv("REDIS_URL", "")
        if not redis_url.strip():
            errors.append("REDIS_URL is required in production for rate limiting and clustering.")

        # Direct commerce is post-launch. Require Razorpay only when enabled.
        if BETA_COMMERCE_ENABLED:
            if PAYMENTS_MODE != "razorpay":
                errors.append("PAYMENTS_MODE must be 'razorpay' when direct commerce is enabled in production.")
            if not RAZORPAY_KEY_ID or "placeholder" in RAZORPAY_KEY_ID.lower():
                errors.append("RAZORPAY_KEY_ID is missing or placeholder in production.")
            if RAZORPAY_KEY_ID.lower().startswith("rzp_test_"):
                errors.append("RAZORPAY_KEY_ID is a TEST key in production — use a live rzp_live_ key.")
            if not RAZORPAY_KEY_SECRET or "placeholder" in RAZORPAY_KEY_SECRET.lower():
                errors.append("RAZORPAY_KEY_SECRET is missing or placeholder in production.")
            if not RAZORPAY_WEBHOOK_SECRET or "placeholder" in RAZORPAY_WEBHOOK_SECRET.lower():
                errors.append("RAZORPAY_WEBHOOK_SECRET is missing or placeholder in production.")
            if not PAYMENT_CHECKOUT_SECRET and not RAZORPAY_WEBHOOK_SECRET:
                errors.append("PAYMENT_CHECKOUT_SECRET (or RAZORPAY_WEBHOOK_SECRET) is required in production to sign hosted checkout URLs.")

        # Check dev auth bypass is off
        if DEV_AUTH_BYPASS:
            errors.append("DEV_AUTH_BYPASS must be false in production.")

        # Check mock social is disabled
        if os.getenv("ENABLE_MOCK_SOCIAL", "").lower() in ("true", "1", "yes"):
            errors.append("ENABLE_MOCK_SOCIAL must be false in production.")

        # Validate CORS is not wildcard
        cors_raw = os.getenv("CORS_ALLOWED_ORIGINS", "")
        if not cors_raw.strip() or "*" in cors_raw:
            errors.append(
                "CORS_ALLOWED_ORIGINS must be set to specific origins without wildcards in production."
            )
        socket_raw = os.getenv("SOCKET_ALLOWED_ORIGINS", "")
        if not socket_raw.strip() or "*" in socket_raw:
            errors.append(
                "SOCKET_ALLOWED_ORIGINS must be set to specific origins without wildcards in production."
            )

    for w in warnings:
        logging.getLogger(__name__).warning("Config warning: %s", w)

    if errors:
        for e in errors:
            logging.getLogger(__name__).critical("Config error: %s", e)
        if IS_PRODUCTION:
            sys.exit("FATAL: Required production configuration is missing. Exiting.")

    return errors + warnings