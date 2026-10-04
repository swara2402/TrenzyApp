"""Demo/local data bootstrap for the ML pipeline.

Loads the real Trenzy product catalog (from the bundled CSV/JSON) into the
SQLite test database and synthesizes a realistic interaction history so the
training pipeline can be run end-to-end without a live production database.

When the production PostgreSQL database is available, ``build_db`` uses real
products and real interaction events instead. Use ``ML_CONTEXT=production``
for that mode.
"""

from __future__ import annotations

import csv
import json
import logging
import random
from datetime import datetime, timedelta
from pathlib import Path

from sqlalchemy.orm import Session

from ..config import BACKEND_DIR as _BACKEND_DIR

logger = logging.getLogger(__name__)

# Canonical event -> label mapping (Phase 4.1). Heavy positive signals weigh more.
EVENT_LABELS = {
    "view_product": 0.1,
    "like_product": 1.0,
    "dislike_product": 0.0,
    "wishlist": 0.9,
    "remove_wishlist": 0.0,
    "cart_add": 1.0,
    "purchase": 1.0,
    "save_outfit": 0.8,
    "swipe": 0.5,  # depends on direction; resolved in synth
}


def load_products_csv(path: Path, limit: int = 5000) -> list[dict]:
    """Load products from the CSV into dicts."""
    if not path.exists():
        raise FileNotFoundError(f"Products CSV not found: {path}")
    products = []
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            products.append(row)
            if len(products) >= limit:
                break
    logger.info("Loaded %d products from %s", len(products), path)
    return products


def load_products_json(path: Path, limit: int = 5000) -> list[dict]:
    """Load products from JSON into dicts."""
    if not path.exists():
        raise FileNotFoundError(f"Products JSON not found: {path}")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, dict):
        data = data.get("products", [])
    logger.info("Loaded %d products from %s", len(data), path)
    return data[:limit]


def load_products(path: Path) -> list[dict]:
    """Load products from CSV or JSON based on extension."""
    ext = path.suffix.lower()
    if ext == ".json":
        return load_products_json(path)
    return load_products_csv(path)


def _parse_float(value, default=0.0) -> float:
    try:
        f = float(value)
        return f if f == f else default
    except (TypeError, ValueError):
        return default


def _parse_tags(value) -> list:
    if isinstance(value, list):
        return value
    if isinstance(value, str):
        try:
            parsed = json.loads(value)
            return parsed if isinstance(parsed, list) else []
        except Exception:
            return [t.strip() for t in value.replace("[", "").replace("]", "").split(",") if t.strip()]
    return []


def populate_products(db: Session, products: list[dict], engine) -> None:
    """Insert products into the catalog if not present."""
    from app.models import Product
    from sqlalchemy.inspection import inspect as sa_inspect

    inspector = sa_inspect(engine)
    existing_ids = set()
    if "products" in inspector.get_table_names():
        try:
            existing_ids = {row[0] for row in db.query(Product.id).all()}
        except Exception as e:
            logger.warning("Failed to read existing product ids: %s", e)

    inserted = 0
    existed = 0
    for p in products:
        pid = str(p.get("id") or p.get("product_id"))
        if not pid or pid in existing_ids:
            existed += 1
            continue
        tags = _parse_tags(p.get("tags"))
        product = Product(
            id=pid,
            name=(p.get("name") or "Unknown Product")[:500],
            description=p.get("description"),
            category=p.get("category"),
            subcategory=p.get("subcategory"),
            article_type=p.get("article_type"),
            gender=p.get("gender"),
            color=p.get("color"),
            season=p.get("season"),
            usage=p.get("usage"),
            price=_parse_float(p.get("price")),
            brand=p.get("brand"),
            rating=_parse_float(p.get("rating"), default=None),
            image_url=p.get("image_url"),
            tags=tags,
            outfit_role=p.get("outfit_role"),
            style=p.get("style"),
            occasion=p.get("occasion"),
            material=p.get("material"),
            fit=p.get("fit"),
        )
        db.add(product)
        inserted += 1

    db.commit()
    logger.info("Products inserted=%d existed=%d", inserted, existed)


def synthesize_users(db: Session, count: int = 50, seed: int = 42) -> list[int]:
    """Create synthetic users with firebase_uid format used by the app."""
    from app.models import User

    rng = random.Random(seed)
    created = []
    for i in range(count):
        uid = f"demo-user-{i}"
        existing = db.query(User).filter(User.firebase_uid == uid).first()
        if existing:
            created.append(existing.id)
            continue
        user = User(firebase_uid=uid, name=f"Demo User {i}", email=f"user{i}@demo.trenzy.app")
        db.add(user)
        db.flush()
        created.append(user.id)
    db.commit()
    logger.info("Synthetic users: %d", len(created))
    return created


def synthesize_interactions(
    db: Session,
    product_ids: list[str],
    user_ids: list[int],
    events_per_user: int = 40,
    seed: int = 42,
) -> None:
    """Create synthetic interaction events across users/products.

    Generates a realistic behavioral signal: each user has preferred styles,
    categories, and colors; positive events skew toward matching products, and
    negatives toward non-matching ones. Timestamps are spread over the past 60
    days so time-based train/validation/test splits are meaningful.
    """
    from app.ai.models_ai import InteractionEvent
    from app.models import Product

    rng = random.Random(seed)
    now = datetime.utcnow()

    # Product attribute index
    products = db.query(Product).filter(Product.id.in_(product_ids)).all()
    attrs: list[dict] = []
    for p in products:
        attrs.append({
            "id": p.id,
            "style": (p.style or "").lower(),
            "category": (p.category or "").lower(),
            "color": (p.color or "").lower(),
            "brand": (p.brand or "").lower(),
            "article_type": (p.article_type or "").lower(),
            "gender": (p.gender or "").lower(),
            "price": p.price or 0.0,
        })
    if not attrs:
        logger.warning("No products available for interaction synthesis")
        return

    all_styles = {a["style"] for a in attrs if a["style"]}
    all_categories = {a["category"] for a in attrs if a["category"]}
    all_colors = {a["color"] for a in attrs if a["color"]}

    existing_count = db.query(InteractionEvent).count()
    if existing_count > 0:
        logger.info("Interaction events already exist (%d); skipping synthesis", existing_count)
        return

    all_articles = {a["article_type"] for a in attrs if a["article_type"]}
    all_brands = {a["brand"] for a in attrs if a["brand"]}
    all_genders = {a["gender"] for a in attrs if a["gender"]}

    def _sample(values, k=2):
        return set(rng.sample(sorted(values), k=min(k, len(values)))) if values else set()

    events = []
    for user_id in user_ids:
        # Sharper preference profile: article + color + brand affinity. These are
        # the attributes that actually discriminate in the catalog (only 3-4
        # coarse styles/categories exist, so they can't carry the signal).
        pref_articles = _sample(all_articles, k=1)
        pref_colors = _sample(all_colors, k=1)
        pref_brands = _sample(all_brands, k=2)
        pref_styles = _sample(all_styles, k=1)
        pref_cats = _sample(all_categories, k=1)
        pref_genders = _sample(all_genders, k=1)

        # Preferred pool = products with (preferred article) OR (preferred brand),
        # then refined by color affinity. Non-preferred = the rest.
        preferred = [
            p for p in attrs
            if (p["article_type"] in pref_articles)
            or (p["brand"] in pref_brands)
            or (p["category"] in pref_cats)
        ]
        preferred = [
            p for p in preferred
            if (p["color"] in pref_colors) or (p["article_type"] in pref_articles) or (p["brand"] in pref_brands)
        ] if rng.random() < 0.8 else preferred
        other = [p for p in attrs if p not in preferred]

        def _pick(pool):
            return rng.choice(pool) if pool else rng.choice(attrs)

        for _ in range(events_per_user):
            if rng.random() < 0.62:
                product = _pick(preferred)
                event_type = rng.choices(
                    ["view_product", "like_product", "wishlist", "cart_add", "purchase", "dislike_product"],
                    weights=[0.12, 0.45, 0.2, 0.15, 0.08, 0.0],
                )[0]
            else:
                product = _pick(other)
                event_type = rng.choices(
                    ["view_product", "dislike_product", "like_product", "wishlist"],
                    weights=[0.45, 0.5, 0.03, 0.02],
                )[0]

            ts = now - timedelta(days=rng.uniform(0, 60), hours=rng.uniform(0, 24))

            events.append(InteractionEvent(
                user_id=user_id,
                event_type=event_type,
                entity_type="product",
                entity_id=product["id"],
                context={"source": "demo", "position": rng.randint(0, 20)},
                session_id=f"demo-sess-{user_id}-{rng.randint(0, 10000)}",
                created_at=ts,
            ))

    db.add_all(events)
    db.commit()
    logger.info("Synthesized %d interaction events", len(events))


def build_demo_db(
    db: Session,
    engine,
    product_csv: Path,
    max_products: int = 5000,
    users: int = 60,
    events_per_user: int = 50,
    seed: int = 42,
) -> dict:
    """Full demo bootstrap: products + users + interactions."""
    products = load_products(product_csv)
    if not products:
        raise RuntimeError("No products loaded")
    populate_products(db, products[:max_products], engine)

    from app.models import Product
    product_ids = [str(r[0]) for r in db.query(Product.id).limit(max_products).all()]

    user_ids = synthesize_users(db, count=users, seed=seed)

    # Ensure a user whose firebase_uid matches DEV_AUTH_UID so authenticated
    # demo/dev requests (get_current_db_user) resolve to a real profile with
    # interaction history for the ML pipeline.
    import os as _os
    primary_uid = _os.getenv("DEV_AUTH_UID", "demo-user")
    from app.models import User as _User
    existing = db.query(_User.id).filter(_User.firebase_uid == primary_uid).first()
    if existing:
        primary_id = existing[0]
    else:
        primary_user = _User(
            firebase_uid=primary_uid,
            name="Demo Primary User",
            email="demo@trenzy.test",
        )
        db.add(primary_user)
        db.flush()
        primary_id = primary_user.id
        db.commit()
    if primary_id not in user_ids:
        user_ids.append(primary_id)

    synthesize_interactions(db, product_ids, user_ids, events_per_user=events_per_user, seed=seed)

    return {
        "products": len(product_ids),
        "users": len(user_ids),
    }


def get_session_and_engine():
    """Bootstrap the app DB session (SQLite demo or Postgres production).

    Returns (session, engine).
    """
    import os
    import sys
    sys.path.insert(0, str(_BACKEND_DIR))

    # Test SQLite mode must patch TSVECTOR before app import (same as conftest).
    if os.getenv("TRENZY_TEST_DB", "1") == "1":
        os.environ["TRENZY_TEST_DB"] = "1"
        os.environ.setdefault("DEV_AUTH_BYPASS", "true")
        os.environ.setdefault("DEV_AUTH_UID", "demo-user")
        os.environ.setdefault("DEV_AUTH_SECRET", "demo-secret")
        import sqlalchemy.dialects.postgresql as _pg
        from sqlalchemy import Text as _Text
        _pg.TSVECTOR = _Text
        import sys as _sys
        _sys.modules.setdefault("sqlalchemy.dialects.postgresql.types", _pg)

    from app.db import engine, SessionLocal, Base
    from app import models  # noqa: F401  register all tables
    from app.ai import models_ai  # noqa: F401

    Base.metadata.create_all(bind=engine)
    return SessionLocal(), engine