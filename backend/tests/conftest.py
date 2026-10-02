"""Test configuration.

Runs against app.db's own in-memory SQLite engine (enabled via TRENZY_TEST_DB=1)
so every code path — FastAPI dependency-injected sessions, direct SessionLocal()
calls inside socket handlers, and health checks — shares ONE database.
TSVECTOR is patched to Text before any app modules are imported.
"""

import os
import sys
import pytest

# Add the backend directory to the Python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

# ── Must be set before app modules are imported ────────────────────────────────
# APP_ENV is explicitly pinned to "test" (some code reads it directly without
# going through .env / config.py).
os.environ["APP_ENV"] = "test"
os.environ["DEV_AUTH_BYPASS"] = "true"
os.environ["DEV_AUTH_UID"] = "test-user-1"
os.environ["DEV_AUTH_SECRET"] = "test-dev-secret"
os.environ["FIREBASE_SERVICE_ACCOUNT_FILE"] = "/dev/null"
os.environ["TRENZY_TEST_DB"] = "1"  # app.db builds a shared in-memory SQLite engine

# ── Patch TSVECTOR → Text BEFORE any app module imports ───────────────────────
# This must happen before `from app.models import ...` resolves TSVECTOR.
import sqlalchemy.dialects.postgresql as _pg_dialect  # noqa: E402
from sqlalchemy import Text as _Text  # noqa: E402
from sqlalchemy import event  # noqa: E402

_pg_dialect.TSVECTOR = _Text  # type: ignore[attr-defined]
# Also patch the module-level reference that models.py imports directly
sys.modules.setdefault("sqlalchemy.dialects.postgresql.types", _pg_dialect)

# ── Import app AFTER patching; reuse ITS engine/session factory ───────────────
from app.main import app  # noqa: E402
from app.db import Base, get_session  # noqa: E402
from app.db import engine as _TEST_ENGINE  # noqa: E402
from app.db import SessionLocal as _TestingSessionLocal  # noqa: E402


@event.listens_for(_TEST_ENGINE, "connect")
def _set_sqlite_pragma(dbapi_conn, rec):
    """Enable FK enforcement in SQLite (disabled by default).

    The engine-level 'connect' event hands us the raw sqlite3 DBAPI
    connection, so execute via cursor (no SQLAlchemy text() wrapper).
    """
    cursor = dbapi_conn.cursor()
    try:
        cursor.execute("PRAGMA foreign_keys=ON")
    finally:
        cursor.close()


# Drop any pooled connection created before the pragma listener existed.
_TEST_ENGINE.dispose()


def _override_get_session():
    db = _TestingSessionLocal()
    try:
        yield db
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


app.dependency_overrides[get_session] = _override_get_session


@pytest.fixture(autouse=True)
def _reset_rate_limiter():
    """Isolate tests from the process-wide rate limiters.

    Without this, earlier tests exhaust the per-IP request budget and later
    tests fail with spurious 429s. The limiter may run an in-memory backend
    directly or a Redis wrapper with an in-memory fallback, so both the
    backend itself and its ``_fallback`` must be cleared, plus the module-level
    auth attempt bucket.
    """
    from app.rate_limit import rate_limiter

    def _clear():
        backend = getattr(rate_limiter, "_backend", None)
        for target in (backend, getattr(backend, "_fallback", None)):
            if target is None:
                continue
            for attr in ("_store", "_connection_store"):
                store = getattr(target, attr, None)
                if store is not None:
                    store.clear()

        from app.routes import auth as _auth_route
        for store_attr in ("_auth_rate",):
            store = getattr(_auth_route, store_attr, None)
            if store is not None:
                store.clear()

    _clear()
    yield
    _clear()


@pytest.fixture(autouse=True, scope="session")
def _create_tables():
    """Create all tables once for the test session."""
    Base.metadata.create_all(bind=_TEST_ENGINE)
    yield
    Base.metadata.drop_all(bind=_TEST_ENGINE)


@pytest.fixture(autouse=True)
def _clear_tables():
    """Wipe every table between tests for full isolation.

    Commits made during a test are durable (sessions are plain, not wrapped
    in an outer transaction), so each test starts from a clean slate.
    Deletes run children-first to respect FK constraints.
    """
    yield
    db = _TestingSessionLocal()
    try:
        for table in reversed(Base.metadata.sorted_tables):
            db.execute(table.delete())
        db.commit()
    finally:
        db.close()


@pytest.fixture
def client():
    from fastapi.testclient import TestClient
    return TestClient(app)


@pytest.fixture
def auth_headers():
    from app.firebase_auth import make_dev_token

    token = make_dev_token(DEV_UID, os.environ["DEV_AUTH_SECRET"])
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def make_auth_headers():
    """Factory for signed dev tokens (e.g. negative tests with bad secrets)."""
    def _make(uid: str = None, secret: str = None) -> dict:
        uid = uid or DEV_UID
        secret = secret if secret is not None else os.environ["DEV_AUTH_SECRET"]
        from app.firebase_auth import make_dev_token

        return {"Authorization": f"Bearer {make_dev_token(uid, secret)}"}
    return _make


@pytest.fixture
def db_session():
    """Plain session bound to the shared test engine.

    Deliberately NOT wrapped in an outer transaction: commits made here must
    be visible to (and survive alongside) API-request sessions sharing the
    same StaticPool connection.
    """
    db = _TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


DEV_UID = "test-user-1"
