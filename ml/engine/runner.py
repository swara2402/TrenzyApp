"""Shared runner helpers for training/evaluation CLI scripts."""

from __future__ import annotations

import logging
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
BACKEND_DIR = REPO_ROOT / "backend"

# Make backend importable (``from app import ...``) regardless of cwd.
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

# Default to SQLite demo mode unless the caller explicitly opts into Postgres.
os.environ.setdefault("TRENZY_TEST_DB", "1")

from ml.config import DEFAULT_PRODUCTS_CSV  # noqa: E402
from ml.data.demo_data import build_demo_db, get_session_and_engine  # noqa: E402

__all__ = [
    "REPO_ROOT",
    "BACKEND_DIR",
    "DEFAULT_PRODUCTS_CSV",
    "build_demo_db",
    "get_session_and_engine",
]


def bootstrap_demo_db(max_products: int = 2000, users: int = 30, events_per_user: int = 30) -> tuple:
    """Create (or reuse) the SQLite demo DB and return (session, engine, stats).

    If product/event counts are already present, the DB is reused as-is so
    repeated training runs don't rebuild data.
    """
    db, engine = get_session_and_engine()
    from sqlalchemy import text
    from app.ai.models_ai import InteractionEvent
    from app.models import Product

    n_products = db.query(Product).count()
    n_events = db.query(InteractionEvent).count()
    if n_products < max_products or n_events == 0:
        stats = build_demo_db(
            db, engine, Path(DEFAULT_PRODUCTS_CSV),
            max_products=max_products, users=users, events_per_user=events_per_user,
        )
    else:
        n_users = db.execute(text("SELECT COUNT(DISTINCT user_id) FROM interaction_events")).scalar() or 0
        stats = {"products": n_products, "users": n_users}
        logging.getLogger(__name__).info("Reusing existing demo DB (%d products, %d events)", n_products, n_events)
    return db, engine, stats


def setup_logging(level: int = logging.INFO):
    logging.basicConfig(
        level=level,
        format="%(asctime)s %(levelname)-7s %(name)s | %(message)s",
    )