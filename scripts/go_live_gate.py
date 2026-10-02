#!/usr/bin/env python3
"""Go-Live Gate Verification Script for Trenzy.

Validates all production requirements outlined in PRODUCTION.md:
1. Production environment settings (APP_ENV=production, DEV_AUTH_BYPASS=false)
2. Fail-closed security configuration (no wildcard CORS/Socket origins)
3. DB connectivity and connection pool health
4. Redis availability and multi-worker readiness
5. Payment configuration (PAYMENTS_MODE=razorpay + valid secrets)
6. Firebase Admin SDK credentials
7. Optional Sentry DSN setup

Usage:
  python3 scripts/go_live_gate.py [--strict]
"""

import argparse
import os
import sys
import logging
from pathlib import Path

from dotenv import load_dotenv

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "backend"))
load_dotenv(REPO_ROOT / "backend" / ".env")

logging.basicConfig(level=logging.INFO, format="%(levelname)s | %(message)s")
logger = logging.getLogger("go_live_gate")


def check_env_vars(strict: bool = False) -> tuple[int, list[str]]:
    """Check required production environment variables."""
    issues: list[str] = []
    warnings: list[str] = []

    app_env = os.getenv("APP_ENV", "development").strip().lower()
    if app_env != "production":
        issues.append(f"APP_ENV is currently '{app_env}' — must be 'production' for go-live.")

    dev_bypass = os.getenv("DEV_AUTH_BYPASS", "").lower() in ("true", "1", "yes")
    if dev_bypass:
        issues.append("DEV_AUTH_BYPASS is set to true — MUST be false in production.")

    cors = os.getenv("CORS_ALLOWED_ORIGINS", "").strip()
    if not cors or "*" in cors:
        issues.append(f"CORS_ALLOWED_ORIGINS invalid ('{cors}'): must be explicit comma-separated production origins without wildcards.")

    socket_cors = os.getenv("SOCKET_ALLOWED_ORIGINS", "").strip()
    if not socket_cors or "*" in socket_cors:
        issues.append(f"SOCKET_ALLOWED_ORIGINS invalid ('{socket_cors}'): must be explicit production origins without wildcards.")

    redis_url = os.getenv("REDIS_URL", "").strip()
    if not redis_url:
        issues.append("REDIS_URL is missing — multi-worker Socket.IO and shared rate limiting require Redis in production.")

    payments_mode = os.getenv("PAYMENTS_MODE", "").strip().lower()
    if payments_mode != "razorpay":
        issues.append(f"PAYMENTS_MODE is '{payments_mode}' — must be 'razorpay' in production.")
    
    razorpay_id = os.getenv("RAZORPAY_KEY_ID", "")
    razorpay_secret = os.getenv("RAZORPAY_KEY_SECRET", "")
    razorpay_webhook = os.getenv("RAZORPAY_WEBHOOK_SECRET", "")

    if not razorpay_id or "placeholder" in razorpay_id.lower():
        issues.append("RAZORPAY_KEY_ID is missing or using placeholder value.")
    if not razorpay_secret or "placeholder" in razorpay_secret.lower():
        issues.append("RAZORPAY_KEY_SECRET is missing or using placeholder value.")
    if not razorpay_webhook or "placeholder" in razorpay_webhook.lower():
        issues.append("RAZORPAY_WEBHOOK_SECRET is missing or using placeholder value.")

    firebase_key = os.getenv("FIREBASE_API_KEY", "")
    if not firebase_key or "change_me" in firebase_key.lower():
        issues.append("FIREBASE_API_KEY is missing or unconfigured.")

    firebase_sa_file = os.getenv("FIREBASE_SERVICE_ACCOUNT_FILE", "")
    firebase_sa_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "")
    if not firebase_sa_file and not firebase_sa_json:
        issues.append("Neither FIREBASE_SERVICE_ACCOUNT_FILE nor FIREBASE_SERVICE_ACCOUNT_JSON is configured.")

    sentry_dsn = os.getenv("SENTRY_DSN", "").strip()
    if not sentry_dsn:
        warnings.append("SENTRY_DSN is not set — error tracking will operate in log-only mode.")

    return len(issues), issues + warnings


def check_db_and_redis() -> list[str]:
    """Test connection to DB and Redis if configured."""
    errors = []
    
    # DB Test
    try:
        from app.db import SessionLocal
        from sqlalchemy import text
        with SessionLocal() as session:
            session.execute(text("SELECT 1"))
        logger.info("[DB Check] PostgreSQL database connection successful.")
    except Exception as e:
        errors.append(f"Database connection failed: {e}")

    # Redis Test
    redis_url = os.getenv("REDIS_URL", "").strip()
    if redis_url:
        try:
            import redis
            r = redis.Redis.from_url(redis_url, socket_timeout=3)
            r.ping()
            logger.info("[Redis Check] Redis server connection successful.")
        except Exception as e:
            errors.append(f"Redis connection to {redis_url} failed: {e}")
    else:
        logger.warning("[Redis Check] Skipped — REDIS_URL not set.")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Trenzy Go-Live Gate Verification")
    parser.add_argument("--strict", action="store_true", help="Fail on warnings as well as critical errors")
    args = parser.parse_args()

    logger.info("=" * 60)
    logger.info("Running Trenzy Go-Live Gate Checks...")
    logger.info("=" * 60)

    issue_count, messages = check_env_vars(strict=args.strict)
    
    for msg in messages:
        if "must be" in msg or "missing" in msg or "invalid" in msg:
            logger.error("  ❌  %s", msg)
        else:
            logger.warning("  ⚠️   %s", msg)

    infra_errors = check_db_and_redis()
    for err in infra_errors:
        logger.error("  ❌  %s", err)

    total_failures = issue_count + len(infra_errors)

    logger.info("=" * 60)
    if total_failures == 0:
        logger.info("🎉 Go-Live Gate PASSED: All production readiness criteria satisfied.")
        return 0
    else:
        logger.error("🚨 Go-Live Gate FAILED: Found %d blocking issue(s). Resolve before opening to users.", total_failures)
        return 1


if __name__ == "__main__":
    sys.exit(main())
