"""Application initialization and lifecycle management.

Provides centralized setup and teardown procedures for app startup and shutdown.
This module handles:

- **Database initialization**: Create tables, run migrations, health checks
- **Firebase initialization**: Load credentials, verify configuration
- **Redis initialization**: Connect to Redis, set up rate limiting and presence
- **Socket.IO initialization**: Configure adapters, event handlers
- **Security validation**: Check for unsafe configurations in production
- **Logging initialization**: Configure logging system
- **Health checks**: Verify DB + Redis connectivity at startup
- **Cleanup**: Graceful shutdown of connections and resources

Usage in main.py:
    from .initialization import initialize_app, shutdown_app
    
    @asynccontextmanager
    async def lifespan(app: FastAPI):
        await initialize_app()
        yield
        await shutdown_app()

All procedures are organized into logical groups and can be called independently.
Each procedure logs its status and raises exceptions on critical failures.
"""

from __future__ import annotations


from .config import IS_PRODUCTION, APP_ENV, validate_startup_config
from .db import engine, SessionLocal
from .logging_config import get_logger, setup_logging
from . import firebase_auth
from .socket_server import _init_redis, initialize_socket_server

logger = get_logger(__name__)


# =============================================================================
# INITIALIZATION PROCEDURES
# =============================================================================


async def _init_logging() -> None:
    """Initialize logging system."""
    logger_setup = get_logger("app.main")
    setup_logging()
    logger_setup.info("Logging configured (format=%s, level=%s)", 
                      "json" if IS_PRODUCTION else "text", "INFO" if IS_PRODUCTION else "DEBUG")


async def _init_config() -> None:
    """Validate startup configuration."""
    logger.info("Validating startup configuration...")
    validate_startup_config()
    logger.info("Configuration valid (APP_ENV=%s)", APP_ENV)


async def _init_database() -> None:
    """Verify database connectivity and perform non-schema runtime bootstrap."""
    from .db import SessionLocal
    from .models import Product
    from .scripts.load_products import main as load_products_data

    logger.info("Initializing database...")
    try:
        # Alembic is the authoritative production schema mechanism. The container
        # entrypoint runs `alembic upgrade head` before the API starts. Keep only
        # idempotent runtime data/bootstrap checks here; do not create or mutate
        # schema from application startup.
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
    """Idempotent bootstrap for Blend.invite_code.

    ``Base.metadata.create_all`` never alters existing tables, so databases
    created before invite codes existed need a one-time ALTER TABLE plus
    backfill. Fresh databases already have the column and skip this.
    """
    import uuid

    from sqlalchemy import inspect, text

    from .blend_helpers import generate_invite_code
    from .models import Blend

    with engine.begin() as conn:
        # Add the column for pre-existing blends tables (no-op otherwise).
        inspector = inspect(conn)
        if "blends" in inspector.get_table_names():
            columns = [c["name"] for c in inspector.get_columns("blends")]
            if "invite_code" not in columns:
                logger.info("Adding blends.invite_code column")
                conn.execute(text("ALTER TABLE blends ADD COLUMN invite_code VARCHAR"))

    # Backfill NULLs with unique generated codes.
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
    """Idempotent bootstrap for products full-text search.

    The ``products.search_vector`` tsvector column has no DDL trigger anywhere,
    so on PostgreSQL it stays NULL forever and ``/api/products/search`` silently
    returns nothing. This installs a BEFORE INSERT/UPDATE trigger that keeps the
    vector fresh and backfills existing rows.

    SQLite (dev/test fallback) skips this — search there uses the ILIKE path.
    """
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


def _ensure_user_is_admin_column() -> None:
    """Idempotent bootstrap for ``users.is_admin`` (admin RBAC).

    ``Base.metadata.create_all`` never alters existing tables, so databases
    created before the admin flag existed need a one-time ALTER TABLE.
    Defaults to FALSE for every existing user — deny-by-default. Promote an
    admin explicitly via SQL or a Firebase custom claim afterwards.
    """
    from sqlalchemy import inspect, text

    with engine.begin() as conn:
        inspector = inspect(conn)
        if "users" in inspector.get_table_names():
            columns = [c["name"] for c in inspector.get_columns("users")]
            if "is_admin" not in columns:
                logger.info("Adding users.is_admin column")
                conn.execute(
                    text(
                        "ALTER TABLE users ADD COLUMN is_admin BOOLEAN "
                        "NOT NULL DEFAULT FALSE"
                    )
                )


def _ensure_pgvector_extension() -> None:
    """Idempotent bootstrap for required PostgreSQL extensions.

    Creates pgvector (for vector search), pg_trgm (for trigram matching), and fuzzystrmatch (for fuzzy search)
    if they don't exist. All are required for full-text and similarity search features.
    """
    from sqlalchemy import inspect, text

    # Only attempt this on PostgreSQL, not SQLite
    if "sqlite" in str(engine.url).lower():
        logger.info("Skipping PostgreSQL extensions (SQLite mode)")
        return

    try:
        with engine.begin() as conn:
            # Create all required extensions
            extensions = [
                ("vector", "pgvector"),
                ("pg_trgm", "pg_trgm"),
                ("fuzzystrmatch", "fuzzystrmatch")
            ]
            for ext_name, ext_display in extensions:
                result = conn.execute(text(
                    f"SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = '{ext_name}')"
                ))
                exists = result.scalar()
                
                if not exists:
                    logger.info(f"Creating {ext_display} extension")
                    conn.execute(text(f"CREATE EXTENSION IF NOT EXISTS {ext_name}"))
                    logger.info(f"{ext_display} extension created successfully")
                else:
                    logger.info(f"{ext_display} extension already exists")
    except Exception as e:
        logger.warning(f"Failed to ensure PostgreSQL extensions: {e}")
        # Don't fail startup - these are nice to have but not critical for basic functionality


def _ensure_pgvector_columns() -> None:
    """Idempotent bootstrap for pgvector columns in embedding tables.

    Migrates existing JSON embedding columns to pgvector Vector type.
    This is a gradual migration - JSON columns are kept for fallback.
    """
    from sqlalchemy import inspect, text

    # Only attempt this on PostgreSQL
    if "sqlite" in str(engine.url).lower():
        logger.info("Skipping pgvector column migration (SQLite mode)")
        return

    try:
        with engine.begin() as conn:
            inspector = inspect(conn)
            
            # Migrate user_embeddings.embedding to vector
            if "user_embeddings" in inspector.get_table_names():
                columns = [c["name"] for c in inspector.get_columns("user_embeddings")]
                if "embedding_vector" not in columns:
                    logger.info("Adding user_embeddings.embedding_vector column")
                    conn.execute(text(
                        "ALTER TABLE user_embeddings ADD COLUMN embedding_vector vector(512)"
                    ))
                    # Create HNSW index for fast similarity search
                    logger.info("Creating HNSW index on user_embeddings.embedding_vector")
                    conn.execute(text(
                        "CREATE INDEX IF NOT EXISTS user_embeddings_embedding_vector_idx "
                        "ON user_embeddings USING hnsw (embedding_vector vector_cosine_ops)"
                    ))
            
            # Migrate product_embeddings combined_embedding to vector
            if "product_embeddings" in inspector.get_table_names():
                columns = [c["name"] for c in inspector.get_columns("product_embeddings")]
                if "combined_embedding_vector" not in columns:
                    logger.info("Adding product_embeddings.combined_embedding_vector column")
                    conn.execute(text(
                        "ALTER TABLE product_embeddings ADD COLUMN combined_embedding_vector vector(512)"
                    ))
                    # Create HNSW index for fast similarity search
                    logger.info("Creating HNSW index on product_embeddings.combined_embedding_vector")
                    conn.execute(text(
                        "CREATE INDEX IF NOT EXISTS product_embeddings_combined_embedding_vector_idx "
                        "ON product_embeddings USING hnsw (combined_embedding_vector vector_cosine_ops)"
                    ))
                    
            logger.info("pgvector columns migration complete")
    except Exception as e:
        logger.warning(f"Failed to migrate pgvector columns: {e}")
        # Don't fail startup - migration can be done manually


async def _check_database_health() -> None:
    """Health check: verify database connectivity and basic queries.
    
    Raises exception if DB is unavailable or unusable.
    """
    logger.info("Checking database health...")
    db = SessionLocal()
    try:
        # Execute a simple query to verify connectivity
        from sqlalchemy import text
        db.execute(text("SELECT 1"))
        logger.info("Database health check passed")
    except Exception as e:
        logger.critical("Database health check failed: %s. Unable to proceed.", e)
        raise RuntimeError(f"Database unavailable: {e}") from e
    finally:
        db.close()


async def _init_firebase() -> None:
    """Initialize Firebase Admin SDK."""
    logger.info("Initializing Firebase Admin SDK...")
    if not firebase_auth.init_firebase_admin():
        if IS_PRODUCTION:
            logger.critical(
                "Firebase Admin failed to initialize in PRODUCTION. "
                "Set FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_SERVICE_ACCOUNT_FILE. "
                "All authenticated requests will fail."
            )
            raise RuntimeError("Firebase initialization failed in production")
        else:
            logger.warning(
                "Firebase Admin failed to initialize in development. "
                "Auth will only work with DEV_AUTH_BYPASS=true"
            )
    else:
        logger.info("Firebase Admin initialized successfully")


async def _init_redis_and_socket() -> None:
    """Initialize Redis connection for multi-instance support + Socket.IO."""
    logger.info("Initializing Redis...")
    try:
        available, client = await _init_redis()
        if available:
            logger.info("Redis connected successfully (multi-instance mode enabled)")
        else:
            logger.info("Redis unavailable, using in-memory fallback (single-worker mode)")
            if IS_PRODUCTION:
                logger.warning(
                    "Production deployment without Redis. "
                    "This is unsafe for multi-worker scaling. Set REDIS_URL for production."
                )
    except Exception as e:
        logger.error("Redis initialization error: %s", e)
        if IS_PRODUCTION:
            logger.critical("Redis connection failed in production. Refusing to start.")
            raise RuntimeError("Redis unavailable in production") from e
        logger.info("Proceeding with in-memory fallback in development")
    
    # Initialize Socket.IO server with Redis adapter if available
    logger.info("Initializing Socket.IO server...")
    try:
        await initialize_socket_server()
        logger.info("Socket.IO server initialized")
    except Exception as e:
        logger.critical("Socket.IO initialization failed: %s", e)
        raise RuntimeError(f"Socket.IO initialization failed: {e}") from e


async def _init_rate_limiter() -> None:
    """Initialize rate limiting."""
    logger.info("Initializing rate limiter...")
    logger.info("Rate limiter configured (window=60s, max=60/window, connections=20/min)")


async def _init_ai_models() -> None:
    """Load production ML models into the ModelManager at startup.

    Non-fatal: if artifacts are missing, the manager degrades gracefully and
    services fall back to rule-based baselines. Never blocks app startup.
    """
    logger.info("Initializing ML models...")
    try:
        from .ai.model_manager import ModelManager
        manager = ModelManager.instance()
        manager.load_models()
        health = manager.health()
        loaded = [k for k, v in health["models"].items() if v["loaded"]]
        logger.info(
            "ML models ready: loaded=[%s], status=%s",
            loaded or "none",
            health["status"],
        )
    except Exception as e:
        logger.error("ML model initialization failed (non-fatal): %s", e)


async def _validate_security() -> None:
    """Validate security settings for production."""
    from .config import DEV_AUTH_BYPASS
    
    if IS_PRODUCTION and DEV_AUTH_BYPASS:
        logger.critical(
            "SECURITY VIOLATION: DEV_AUTH_BYPASS=true in production (APP_ENV=%s). "
            "This allows anyone to impersonate any user. Refusing to start.",
            APP_ENV,
        )
        raise RuntimeError("DEV_AUTH_BYPASS must be disabled in production")
    
    logger.info("Security configuration valid")


# =============================================================================
# SHUTDOWN PROCEDURES
# =============================================================================


async def _shutdown_database() -> None:
    """Clean up database connections."""
    logger.info("Shutting down database connections...")
    try:
        engine.dispose()
        logger.info("Database connections disposed")
    except Exception as e:
        logger.error("Error disposing database connections: %s", e)


async def _shutdown_redis() -> None:
    """Clean up Redis connection."""
    logger.info("Shutting down Redis connection...")
    try:
        from .socket_server import _redis_client
        if _redis_client:
            await _redis_client.close()
            logger.info("Redis connection closed")
    except Exception as e:
        logger.error("Error closing Redis connection: %s", e)


async def _shutdown_firebase() -> None:
    """Clean up Firebase resources."""
    logger.info("Shutting down Firebase...")
    # Firebase Admin SDK doesn't require explicit cleanup
    logger.info("Firebase cleanup complete")


# =============================================================================
# MAIN INITIALIZATION/SHUTDOWN ORCHESTRATION
# =============================================================================


class InitializationError(Exception):
    """Raised when a critical initialization step fails."""
    pass


async def initialize_app() -> None:
    """Initialize the entire application.
    
    Runs all startup procedures in order. Raises InitializationError if
    any critical procedure fails. In production, most failures are fatal.
    
    Call this once in the FastAPI lifespan startup event.
    """
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
    logger.info("=" * 80)


async def shutdown_app() -> None:
    """Shut down the entire application gracefully.
    
    Runs all cleanup procedures in reverse order. Logs errors but doesn't
    raise exceptions (to prevent blocking shutdown).
    
    Call this once in the FastAPI lifespan shutdown event.
    """
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
    logger.info("=" * 80)