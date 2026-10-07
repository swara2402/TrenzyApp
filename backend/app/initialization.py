"""Application initialization and lifecycle management.

Provides centralized setup and teardown procedures for application startup and shutdown.
"""

from __future__ import annotations

import os

from .config import IS_PRODUCTION, APP_ENV, validate_startup_config
from .db import engine, SessionLocal
from .logging_config import get_logger, setup_logging
from . import firebase_auth
from .socket_server import _init_redis, initialize_socket_server

logger = get_logger(__name__)


async def _init_logging() -> None:
    """Initialize logging system."""
    logger_setup = get_logger("app.main")
    setup_logging()
    logger_setup.info(
        "Logging configured (format=%s, level=%s)",
        "json" if IS_PRODUCTION else "text",
        "INFO" if IS_PRODUCTION else "DEBUG",
    )


async def _init_config() -> None:
    """Validate startup configuration."""
    logger.info("Validating startup configuration...")
    validate_startup_config()
    logger.info("Configuration valid (APP_ENV=%s)", APP_ENV)


async def _init_database() -> None:
    """Verify database connectivity and perform non-schema runtime bootstrap."""
    from .scripts.load_products import main as load_products_data
    from .models import Product

    logger.info("Initializing database...")
    try:
        _ensure_search_vector_triggers()
        with SessionLocal() as session:
            count = session.query(Product).count()
            if count == 0:
                load_products_data()
        logger.info("Database schema created/verified")
    except Exception as e:
        logger.error("Database initialization failed: %s", e)
        raise


def _ensure_blend_invite_codes() -> None:
    """Idempotent bootstrap for Blend.invite_code."""
    from sqlalchemy import inspect, text
    from .blend_helpers import generate_invite_code
    from .models import Blend

    with engine.begin() as conn:
        inspector = inspect(conn)
        if "blends" in inspector.get_table_names():
            columns = [c["name"] for c in inspector.get_columns("blends")]
            if "invite_code" not in columns:
                logger.info("Adding blends.invite_code column")
                conn.execute(text("ALTER TABLE blends ADD COLUMN invite_code VARCHAR"))

    with SessionLocal() as session:
        missing = session.query(Blend).filter(Blend.invite_code.is_(None)).all()
        if not missing:
            return
        taken: set[str] = {
            row[0]
            for row in session.query(Blend.invite_code).filter(
                Blend.invite_code.isnot(None)
            )
        }
        for blend in missing:
            code = generate_invite_code()
            while code in taken:
                code = generate_invite_code()
            taken.add(code)
            blend.invite_code = code
        session.commit()
        logger.info("Backfilled invite codes for %d blend(s)", len(missing))


_SEARCH_VECTOR_EXPR = """
    coalesce(name,'') || ' ' ||
    coalesce(brand,'') || ' ' ||
    coalesce(category,'') || ' ' ||
    coalesce(subcategory,'') || ' ' ||
    coalesce(article_type,'') || ' ' ||
    coalesce(gender,'') || ' ' ||
    coalesce(color,'') || ' ' ||
    coalesce(season,'') || ' ' ||
    coalesce(usage,'') || ' ' ||
    coalesce(description,'') || ' ' ||
    coalesce(outfit_role,'') || ' ' ||
    coalesce(style,'') || ' ' ||
    coalesce(occasion,'') || ' ' ||
    coalesce(material,'') || ' ' ||
    coalesce(fit,'') || ' ' ||
    coalesce(display_brand,'') || ' ' ||
    coalesce(display_color,'') || ' ' ||
    coalesce(display_category,'') || ' ' ||
    coalesce(trenzy_json_to_search_text(style_tags),'') || ' ' ||
    coalesce(trenzy_json_to_search_text(occasion_tags),'') || ' ' ||
    coalesce(trenzy_json_to_search_text(color_tags),'') || ' ' ||
    coalesce(trenzy_json_to_search_text(brand_tags),'') || ' ' ||
    coalesce(trenzy_json_to_search_text(season_tags),'')
"""

_SEARCH_VECTOR_EXPR_NEW = """
    coalesce(NEW.name,'') || ' ' ||
    coalesce(NEW.brand,'') || ' ' ||
    coalesce(NEW.category,'') || ' ' ||
    coalesce(NEW.subcategory,'') || ' ' ||
    coalesce(NEW.article_type,'') || ' ' ||
    coalesce(NEW.gender,'') || ' ' ||
    coalesce(NEW.color,'') || ' ' ||
    coalesce(NEW.season,'') || ' ' ||
    coalesce(NEW.usage,'') || ' ' ||
    coalesce(NEW.description,'') || ' ' ||
    coalesce(NEW.outfit_role,'') || ' ' ||
    coalesce(NEW.style,'') || ' ' ||
    coalesce(NEW.occasion,'') || ' ' ||
    coalesce(NEW.material,'') || ' ' ||
    coalesce(NEW.fit,'') || ' ' ||
    coalesce(NEW.display_brand,'') || ' ' ||
    coalesce(NEW.display_color,'') || ' ' ||
    coalesce(NEW.display_category,'') || ' ' ||
    coalesce(trenzy_json_to_search_text(NEW.style_tags),'') || ' ' ||
    coalesce(trenzy_json_to_search_text(NEW.occasion_tags),'') || ' ' ||
    coalesce(trenzy_json_to_search_text(NEW.color_tags),'') || ' ' ||
    coalesce(trenzy_json_to_search_text(NEW.brand_tags),'') || ' ' ||
    coalesce(trenzy_json_to_search_text(NEW.season_tags),'')
"""

_TRIGGER_NAME = "trenzy_products_search_vector_trigger"
_FUNCTION_NAME = "trenzy_products_search_vector_update"
_JSON_HELPER_NAME = "trenzy_json_to_search_text"


def _ensure_search_vector_triggers() -> None:
    """Ensure PostgreSQL full-text search triggers and backfill."""
    from sqlalchemy import inspect, text

    if engine.dialect.name != "postgresql":
        return

    with engine.begin() as conn:
        if "products" not in inspect(conn).get_table_names():
            return

        conn.execute(text(f"""
            CREATE OR REPLACE FUNCTION {_JSON_HELPER_NAME}(j json) RETURNS text AS $$
            BEGIN
                IF j IS NULL THEN RETURN '';
                END IF;
                CASE json_typeof(j)
                    WHEN 'array' THEN
                        RETURN (SELECT string_agg(elem, ' ') FROM json_array_elements_text(j) elem);
                    WHEN 'object' THEN
                        RETURN (SELECT string_agg(v, ' ') FROM json_each_text(j));
                    ELSE RETURN j::text;
                END CASE;
            END $$ LANGUAGE plpgsql IMMUTABLE;
        """))

        conn.execute(text(f"""
            CREATE OR REPLACE FUNCTION {_FUNCTION_NAME}() RETURNS trigger AS $$
            BEGIN
                NEW.search_vector := to_tsvector('english',
                    {_SEARCH_VECTOR_EXPR_NEW}
                );
                RETURN NEW;
            END $$ LANGUAGE plpgsql;
        """))

        existing = conn.execute(
            text("SELECT 1 FROM pg_trigger WHERE tgname = :name"),
            {"name": _TRIGGER_NAME},
        ).first()
        if existing is None:
            conn.execute(text(f"""
                CREATE TRIGGER {_TRIGGER_NAME}
                BEFORE INSERT OR UPDATE ON products
                FOR EACH ROW EXECUTE FUNCTION {_FUNCTION_NAME}()
            """))

        backfilled = conn.execute(text(f"""
            UPDATE products
               SET search_vector = to_tsvector('english', {_SEARCH_VECTOR_EXPR})
             WHERE search_vector IS NULL
        """))
        logger.info(
            "Ensured products search_vector trigger (backfilled %d row(s))",
            backfilled.rowcount or 0,
        )


async def _check_database_health() -> None:
    """Health check: verify database connectivity and basic queries."""
    logger.info("Checking database health...")
    db = SessionLocal()
    try:
        from sqlalchemy import text
        db.execute(text("SELECT 1"))
        logger.info("Database health check passed")
    except Exception as e:
        logger.critical("Database health check failed: %s", e)
        raise RuntimeError(f"Database unavailable: {e}") from e
    finally:
        db.close()


async def _init_firebase() -> None:
    """Initialize Firebase Admin SDK."""
    logger.info("Initializing Firebase Admin SDK...")
    if not firebase_auth.init_firebase_admin():
        if IS_PRODUCTION:
            raise RuntimeError("Firebase initialization failed in production")
        logger.warning("Firebase Admin failed to initialize in development")
    else:
        logger.info("Firebase Admin initialized successfully")


async def _init_redis_and_socket() -> None:
    """Initialize Redis connection and Socket.IO."""
    logger.info("Initializing Redis...")
    try:
        available, _client = await _init_redis()
        if available:
            logger.info("Redis connected successfully (multi-instance mode enabled)")
        else:
            logger.info("Redis unavailable, using in-memory fallback")
            if IS_PRODUCTION:
                logger.warning("Production deployment without Redis.")
    except Exception as e:
        logger.error("Redis initialization error: %s", e)
        if IS_PRODUCTION:
            raise RuntimeError("Redis unavailable in production") from e

    logger.info("Initializing Socket.IO server...")
    try:
        await initialize_socket_server()
        logger.info("Socket.IO server initialized")
    except Exception as e:
        logger.critical("Socket.IO initialization failed: %s", e)
        raise RuntimeError(f"Socket.IO initialization failed: {e}") from e


async def _init_rate_limiter() -> None:
    """Initialize rate limiting."""
    logger.info("Rate limiter configured (window=60s, max=60/window, connections=20/min)")


async def _init_ai_models() -> None:
    """Load ML models when explicitly enabled; otherwise use safe fallbacks.

    The beta Render free instance has 512 MB RAM. Loading several pickle models
    at startup can exceed that limit. AI services already support rule-based
    fallbacks, so constrained staging can disable model loading without
    disabling the AI endpoints themselves.
    """
    enabled = os.getenv("TRENZY_LOAD_ML_MODELS", "true").strip().lower() in {
        "1", "true", "yes", "on"
    }
    if not enabled:
        logger.info(
            "ML model loading disabled by TRENZY_LOAD_ML_MODELS=false; "
            "AI services will use configured fallback chains."
        )
        return

    logger.info("Initializing ML models...")
    try:
        from .ai.model_manager import ModelManager
        manager = ModelManager.instance()
        manager.load_models()
        health = manager.health()
        loaded = [k for k, v in health["models"].items() if v["loaded"]]
        logger.info("ML models ready: loaded=[%s], status=%s", loaded or "none", health["status"])
    except Exception as e:
        logger.error("ML model initialization failed (non-fatal): %s", e)


async def _validate_security() -> None:
    """Validate security settings for production."""
    from .config import DEV_AUTH_BYPASS

    if IS_PRODUCTION and DEV_AUTH_BYPASS:
        raise RuntimeError("DEV_AUTH_BYPASS must be disabled in production")

    logger.info("Security configuration valid")


class InitializationError(Exception):
    """Raised when a critical initialization step fails."""


async def initialize_app() -> None:
    """Initialize the entire application."""
    logger.info("=" * 80)
    logger.info("Trenzy Backend Initialization Starting (APP_ENV=%s)", APP_ENV)
    logger.info("=" * 80)

    procedures: list[tuple[str, callable]] = [
        ("Logging", _init_logging),
        ("Configuration", _init_config),
        ("Database", _init_database),
        ("Database Health", _check_database_health),
        ("AI Models", _init_ai_models),
        ("Firebase", _init_firebase),
        ("Redis + Socket.IO", _init_redis_and_socket),
        ("Rate Limiter", _init_rate_limiter),
        ("Security Validation", _validate_security),
    ]

    for name, proc in procedures:
        try:
            await proc()
        except Exception as e:
            logger.critical("INITIALIZATION FAILED at %s: %s", name, e)
            raise InitializationError(f"Initialization failed at {name}: {e}") from e

    logger.info("=" * 80)
    logger.info("Trenzy Backend Initialization Complete")


async def shutdown_app() -> None:
    """Shut down all application resources."""
    logger.info("=" * 80)
    logger.info("Trenzy Backend Shutdown Starting")
    logger.info("=" * 80)

    procedures = [
        ("Firebase", _shutdown_firebase),
        ("Redis", _shutdown_redis),
        ("Database", _shutdown_database),
    ]

    for name, proc in procedures:
        try:
            await proc()
        except Exception as e:
            logger.error("Error during %s shutdown: %s", name, e)

    logger.info("=" * 80)
    logger.info("Trenzy Backend Shutdown Complete")


async def _shutdown_database() -> None:
    engine.dispose()


async def _shutdown_redis() -> None:
    try:
        from .socket_server import _redis_client
        if _redis_client:
            await _redis_client.close()
    except Exception as e:
        logger.error("Error closing Redis connection: %s", e)


async def _shutdown_firebase() -> None:
    logger.info("Firebase cleanup complete")
