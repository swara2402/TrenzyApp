"""Health check endpoints for monitoring and load balancers.

Three probes:
  GET /api/health        – comprehensive status (firebase, db, redis, catalog, embeddings)
  GET /api/health/ready  – Kubernetes/Docker readiness (fails if catalog or embeddings are absent)
  GET /api/health/live   – Kubernetes/Docker liveness (process alive, no dep checks)
"""

from __future__ import annotations

import logging

logger = logging.getLogger(__name__)

from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends
from sqlalchemy import text, func
from sqlalchemy.orm import Session

from ..db import engine, get_session
from ..models import Product
from .. import firebase_auth
from ..config import IS_PRODUCTION

router = APIRouter(tags=["health"])

# Minimum catalog size required for the /ready probe to pass in production.
_MIN_CATALOG_SIZE: int = 1          # at least one product with an image
_MIN_EMBEDDINGS: int = 1            # at least one embedding row


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

async def _check_redis_health() -> dict[str, str]:
    """Health check for Redis (if configured)."""
    try:
        from ..socket_server import _redis_client, _redis_available
        if not _redis_available or not _redis_client:
            return {"redis": "unconfigured"}
        await _redis_client.ping()
        return {"redis": "healthy"}
    except Exception as e:
        return {"redis": f"unhealthy: {str(e)[:50]}"}


def _check_catalog(session: Session) -> dict[str, Any]:
    """Return catalog health details: total products, products with images, archived."""
    try:
        total = session.query(func.count(Product.id)).scalar() or 0
        with_image = (
            session.query(func.count(Product.id))
            .filter(Product.image_url.isnot(None), Product.image_url != "")
            .scalar()
            or 0
        )
        active = (
            session.query(func.count(Product.id))
            .filter(Product.is_archived.is_(False))
            .scalar()
            or 0
        )
        return {
            "catalog": "loaded" if with_image >= _MIN_CATALOG_SIZE else "empty",
            "catalog_total": total,
            "catalog_with_image": with_image,
            "catalog_active": active,
        }
    except Exception as exc:
        return {"catalog": f"error: {str(exc)[:80]}"}


def _check_embeddings(session: Session) -> dict[str, Any]:
    """Return embedding health: how many ProductEmbedding rows exist."""
    try:
        from ..ai.models_ai import ProductEmbedding  # type: ignore

        count = (
            session.query(func.count(ProductEmbedding.id))
            .filter(ProductEmbedding.combined_embedding.isnot(None))
            .scalar()
            or 0
        )
        return {
            "embeddings": "ready" if count >= _MIN_EMBEDDINGS else "not_generated",
            "embedding_count": count,
        }
    except Exception as exc:
        return {"embeddings": f"error: {str(exc)[:80]}", "embedding_count": 0}


def _check_migrations() -> dict[str, str]:
    """Verify Alembic migration state (head check)."""
    try:
        from alembic.config import Config as AlembicConfig
        from alembic.runtime.migration import MigrationContext
        from alembic.script import ScriptDirectory
        from pathlib import Path

        backend_dir = Path(__file__).resolve().parent.parent.parent
        ini_path = backend_dir / "alembic.ini"
        if not ini_path.exists():
            return {"migrations": "alembic.ini not found"}

        alembic_cfg = AlembicConfig(str(ini_path))
        scripts = ScriptDirectory.from_config(alembic_cfg)
        head_revisions = {s.revision for s in scripts.get_revisions("heads")}

        with engine.connect() as conn:
            ctx = MigrationContext.configure(conn)
            current = set(ctx.get_current_heads())

        if current == head_revisions:
            return {"migrations": "up_to_date"}
        return {
            "migrations": f"pending (current={sorted(current)}, head={sorted(head_revisions)})"
        }
    except Exception as exc:
        return {"migrations": f"error: {str(exc)[:80]}"}


# ---------------------------------------------------------------------------
# GET /api/health  — comprehensive
# ---------------------------------------------------------------------------

@router.get("/api/health")
async def health_check(session: Session = Depends(get_session)) -> dict[str, Any]:
    """Comprehensive health check for the application."""
    health: dict[str, Any] = {
        "status": "healthy",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "version": "5.1.0-production",
        "checks": {},
    }

    # ── Firebase ────────────────────────────────────────────────────────────
    if firebase_auth._firebase_initialized:
        health["checks"]["firebase"] = "healthy"
    elif firebase_auth.FIREBASE_PROJECT_ID:
        health["checks"]["firebase"] = "healthy (public-cert mode)"
    else:
        health["checks"]["firebase"] = "unhealthy"
        health["status"] = "degraded"

    # ── Database ────────────────────────────────────────────────────────────
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        health["checks"]["database"] = "healthy"
    except Exception as exc:
        health["checks"]["database"] = f"unhealthy: {str(exc)[:50]}"
        health["status"] = "degraded"

    # ── Redis ───────────────────────────────────────────────────────────────
    redis_check = await _check_redis_health()
    health["checks"].update(redis_check)
    if health["checks"].get("redis", "").startswith("unhealthy"):
        health["status"] = "degraded"

    # ── Catalog ─────────────────────────────────────────────────────────────
    catalog_info = _check_catalog(session)
    health["checks"].update(catalog_info)
    if catalog_info.get("catalog") not in ("loaded",):
        health["status"] = "degraded"

    # ── Embeddings ──────────────────────────────────────────────────────────
    emb_info = _check_embeddings(session)
    health["checks"].update(emb_info)
    if emb_info.get("embeddings") not in ("ready",):
        # Degraded (not failed) — search still works via text, just not vector
        if health["status"] == "healthy":
            health["status"] = "degraded"

    # ── Migration state ─────────────────────────────────────────────────────
    migration_info = _check_migrations()
    health["checks"].update(migration_info)
    if migration_info.get("migrations", "") not in ("up_to_date",):
        health["status"] = "degraded"

    return health


# ---------------------------------------------------------------------------
# GET /api/health/ready  — Kubernetes/Docker readiness probe
# ---------------------------------------------------------------------------

@router.get("/api/health/ready")
async def readiness_check(session: Session = Depends(get_session)) -> dict[str, Any]:
    """Readiness probe — checks every hard dependency before accepting traffic.

    Gates:
      1. Database reachable
      2. Redis present (required in production)
      3. Firebase configured (project ID or Admin SDK)
      4. Catalog has ≥ 1 product with an image_url
      5. Embeddings generated (≥ 1 ProductEmbedding row) — production only
      6. Alembic migrations are at HEAD
    """
    timestamp = datetime.now(timezone.utc).isoformat()
    failures: list[str] = []

    # 1. Database
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
    except Exception as exc:
        failures.append(f"database: {str(exc)[:80]}")

    # 2. Redis (required in production)
    from ..socket_server import _redis_available, _redis_url  # type: ignore

    if IS_PRODUCTION and (not _redis_url or not _redis_available):
        failures.append("redis: required in production but unavailable")

    # 3. Firebase
    if not firebase_auth._firebase_initialized and not firebase_auth.FIREBASE_PROJECT_ID:
        failures.append("firebase: not configured (set FIREBASE_PROJECT_ID or service account)")

    # 4. Catalog
    try:
        with_image = (
            session.query(func.count(Product.id))
            .filter(
                Product.image_url.isnot(None),
                Product.image_url != "",
                Product.is_archived.is_(False),
            )
            .scalar()
            or 0
        )
        if with_image < _MIN_CATALOG_SIZE:
            failures.append(
                f"catalog: only {with_image} active products with images "
                f"(need ≥ {_MIN_CATALOG_SIZE})"
            )
    except Exception as exc:
        failures.append(f"catalog: {str(exc)[:80]}")

    # 5. Embeddings (production only — dev can run without ML weights)
    if IS_PRODUCTION:
        try:
            from ..ai.models_ai import ProductEmbedding  # type: ignore

            emb_count = (
                session.query(func.count(ProductEmbedding.id))
                .filter(ProductEmbedding.combined_embedding.isnot(None))
                .scalar()
                or 0
            )
            if emb_count < _MIN_EMBEDDINGS:
                failures.append(
                    f"embeddings: {emb_count} valid embeddings found "
                    f"(need ≥ {_MIN_EMBEDDINGS}). Run the embedding pipeline."
                )
        except Exception as exc:
            failures.append(f"embeddings: {str(exc)[:80]}")

    # 6. Migrations
    migration_info = _check_migrations()
    migration_status = migration_info.get("migrations", "unknown")
    if migration_status not in ("up_to_date", "alembic.ini not found"):
        failures.append(f"migrations: {migration_status}")

    if failures:
        return {
            "status": "not_ready",
            "failures": failures,
            "timestamp": timestamp,
        }

    return {"status": "ready", "timestamp": timestamp}


# ---------------------------------------------------------------------------
# GET /api/health/live  — Kubernetes/Docker liveness probe
# ---------------------------------------------------------------------------

@router.get("/api/health/live")
async def liveness_check() -> dict[str, Any]:
    """Liveness probe — process is alive (no dependency checks)."""
    return {
        "status": "alive",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }