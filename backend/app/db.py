"""Database engine, session factory, and dependency injection.

Creates the SQLAlchemy engine connected to PostgreSQL and provides
``get_session`` as a FastAPI dependency for request-scoped database sessions.

Connection pool settings:
- ``pool_size=10``: Base number of persistent connections
- ``max_overflow=20``: Additional connections allowed under burst load
- ``pool_pre_ping=True``: Validates connections before use (handles stale connections)
- ``pool_recycle=1800``: Recycles connections after 30 minutes (prevents idle timeouts)

Why ``get_session`` is a generator: FastAPI's ``Depends()`` requires a callable
that yields a session, ensuring the session is properly closed after each request.
"""

import os
from sqlalchemy import create_engine, URL
from sqlalchemy.ext.compiler import compiles
from sqlalchemy.orm import sessionmaker
from sqlalchemy.sql.functions import now as sa_now

from .config import (
    DB_HOST,
    DB_PORT,
    POSTGRES_DB,
    POSTGRES_PASSWORD,
    POSTGRES_USER,
)
from sqlalchemy.orm import declarative_base

from sqlalchemy.pool import NullPool

Base = declarative_base()

IS_TEST_MODE = (
    os.getenv("PYTEST_CURRENT_TEST") is not None
    or os.getenv("TRENZY_TEST_DB") == "1"
    or os.getenv("APP_ENV") == "test"
)

# Never let SQLite be the database in a production environment. A mis-set
# APP_ENV or stray TRENZY_TEST_DB=1 would otherwise silently run the app on
# SQLite (single-writer, no pgvector, no full-text search) in production.
from .config import APP_ENV as _APP_ENV, IS_PRODUCTION as _IS_PRODUCTION

if IS_TEST_MODE and _IS_PRODUCTION:
    raise RuntimeError(
        "Refusing to start: test-mode SQLite selected but APP_ENV=%r is "
        "production. Unset TRENZY_TEST_DB / PYTEST_CURRENT_TEST." % _APP_ENV
    )

if IS_TEST_MODE:
    # SQLite has no now() function: server_default=func.now() would be stored as
    # the literal string 'now()'. Compile it to CURRENT_TIMESTAMP so DEFAULT
    # clauses (and INSERT..RETURNING of created_at) yield a real timestamp.
    @compiles(sa_now, "sqlite")
    def _compile_sqlite_now(element, compiler, **kw):  # type: ignore[no-untyped-def]
        return "CURRENT_TIMESTAMP"

    # Use a file‑based SQLite DB for development/testing if DEV_SQLITE_DB is set,
    # otherwise fall back to an in‑memory database.
    # Dev/test mode runs the server with a threaded request pool, so each
    # request must get its own SQLite connection (NullPool). Sharing one
    # StaticPool connection across threads intermittently raises SQLite's
    # "bad parameter or other API misuse" under parallel requests.
    dev_sqlite_path = os.getenv("DEV_SQLITE_DB")
    sqlite_connect_args = {"check_same_thread": False, "timeout": 30}
    if dev_sqlite_path:
        sqlite_url = f"sqlite:///{dev_sqlite_path}"
        engine = create_engine(
            sqlite_url,
            connect_args=sqlite_connect_args,
            poolclass=NullPool,
        )
    else:
        # Default to a file‑based SQLite DB for test mode so that data persists across separate processes.
        # This enables scripts like the embedding generator to see the tables created during initialization.
        sqlite_url = "sqlite:///./trenzy_dev.db"
        engine = create_engine(
            sqlite_url,
            connect_args=sqlite_connect_args,
            poolclass=NullPool,
        )
else:
    try:
        db_url = URL.create(
            drivername="postgresql+psycopg",
            username=POSTGRES_USER,
            password=POSTGRES_PASSWORD,
            host=DB_HOST,
            port=DB_PORT,
            database=POSTGRES_DB,
        )
        engine = create_engine(
            db_url,
            pool_size=10,
            max_overflow=20,
            pool_timeout=30,
            pool_pre_ping=True,
            pool_recycle=1800,
            echo=False,
        )
    except Exception as e:
        raise RuntimeError("Failed to connect to PostgreSQL database.") from e

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_session():
    """FastAPI dependency that provides a SQLAlchemy session per request.

    Handlers should call session.commit() explicitly for write operations.
    Read-only endpoints (GET) should not commit — the session will be
    rolled back and closed automatically.
    """
    db = SessionLocal()
    try:
        yield db
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()