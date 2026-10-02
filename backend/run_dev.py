"""Development Server Launcher for Trenzy Backend.

Allows running the backend seamlessly in local development with SQLite fallback
if PostgreSQL is not active, and automatically loads seed product data.
"""

import os
import sys
from pathlib import Path

# Add backend directory to sys.path
backend_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(backend_dir))

# Enable Dev Auth and Test DB mode for frictionless local execution
os.environ.setdefault("DEV_AUTH_BYPASS", "true")
os.environ.setdefault("DEV_AUTH_UID", "dev-user-123")
os.environ.setdefault("DEV_AUTH_SECRET", "test-dev-secret")
# Multi-identity demo allowlist: lets two real clients (e.g. kiosk + a second
# tab opened with ?devUid=...) exercise blend chat/swipes with live sockets
# instead of faking the second member. Names match the seeded demo users.
os.environ.setdefault(
    "DEV_AUTH_USERS",
    "dev-user-123:Dev User:dev@trenzy.local,"
    "demo-user-1:Aarav Kapoor:aarav@demo.trenzy.app,"
    "demo-user-2:Meera Iyer:meera@demo.trenzy.app,"
    "demo-user-3:Zara Sheikh:zara@demo.trenzy.app,"
    "demo-user-4:Rohan Mehta:rohan@demo.trenzy.app,"
    "demo-user-5:Avni Sharma:avni@demo.trenzy.app",
)
os.environ.setdefault("DEV_AUTH_NAME", "Dev User")
os.environ.setdefault("DEV_AUTH_EMAIL", "dev@trenzy.local")
os.environ.setdefault("APP_ENV", "development")
# Wire a Firebase service account for the dev server IF the operator provided
# one, so the REAL token path (non-bypass) also works locally:
# 1) FIREBASE_SERVICE_ACCOUNT_FILE if already set, or
# 2) a repo-local backend/firebase_service_account.json (never committed).
# Without it the backend runs dev-bypass-only (real Firebase tokens would be
# rejected with 503). Leave unset in production; firebase_auth resolves the
# file explicitly and never auto-discovers arbitrary paths.
_SA_FILE = "firebase_service_account.json"
_sa_candidate = backend_dir / _SA_FILE
if not os.environ.get("FIREBASE_SERVICE_ACCOUNT_FILE") and _sa_candidate.exists():
    os.environ["FIREBASE_SERVICE_ACCOUNT_FILE"] = str(_sa_candidate)
    print(f"[*] Using Firebase service account: {_sa_candidate.name} (real token path enabled)")
# Socket.IO origin allowlist for the local demo kiosk (serve.py on :8090) and
# the classic dev/Flutter-run origin. Without this the socket server rejects
# every connection from the kiosk, silently killing blend chat + live swipes.
os.environ.setdefault(
    "SOCKET_ALLOWED_ORIGINS",
    "http://localhost:8090,http://127.0.0.1:8090,http://[::1]:8090,"
    "http://localhost:3000,http://127.0.0.1:3000,http://localhost:5173,"
    "http://localhost:5174",
)

# Patch PostgreSQL TSVECTOR type for SQLite compatibility before importing models
import sqlalchemy.dialects.postgresql as _pg_dialect
from sqlalchemy import Text as _Text
_pg_dialect.TSVECTOR = _Text
sys.modules.setdefault("sqlalchemy.dialects.postgresql.types", _pg_dialect)

# Set up SQLite database
sqlite_path = backend_dir / "trenzy_dev.db"
os.environ["TRENZY_TEST_DB"] = "1"

import uvicorn
from app.db import Base, engine, SessionLocal
from app.scripts.load_products import main as load_products_data

def seed_demo_trends():
    """Seed a few days of trend metrics so the dev demo shows real Trending
    sections (views + clicks weighted). Deterministic per-product pattern so
    results are reproducible; dev-only."""
    try:
        from datetime import datetime, timedelta, timezone
        from app.models import Product, TrendMetric
        from app.db import SessionLocal

        session = SessionLocal()
        try:
            product_ids = [p.id for p in session.query(Product.id).all()]
            session.query(TrendMetric).delete()
            session.commit()

            seed = {
                "prod_005": {"views": 150, "clicks": 11, "cat": "Footwear"},
                "prod_002": {"views": 120, "clicks": 9, "cat": "Bottom"},
                "prod_001": {"views": 100, "clicks": 7, "cat": "Upper"},
                "prod_004": {"views": 70, "clicks": 4, "cat": "Accessories"},
                "prod_003": {"views": 60, "clicks": 3, "cat": "Accessories"},
            }
            now = datetime.now(timezone.utc)
            rows = 0
            for pid in product_ids:
                cfg = seed.get(pid, {"views": 50, "clicks": 2, "cat": "other"})
                # score = view_count*1.0 + click_count*3.0; one daily row per
                # product so rankings rise toward today and stay duplicate-free.
                for days_ago in range(9, -1, -1):
                    day = now - timedelta(days=days_ago)
                    growth = 0.6 + (10 - days_ago) * 0.04
                    v = max(1, int(cfg["views"] * growth / 10))
                    c = max(0, int(cfg["clicks"] * growth / 10))
                    row = TrendMetric(
                        product_id=pid,
                        timeframe="daily",
                        window_start=day.replace(hour=0, minute=0, second=0, microsecond=0),
                        view_count=v,
                        click_count=c,
                        trending_score=v + 3 * c,
                        momentum=round(0.03 * (10 - days_ago), 3),
                        category=cfg["cat"],
                    )
                    session.add(row)
                    rows += 1
            session.commit()
            print(f"[*] Seeded {rows} dev trend metric rows.")
        finally:
            session.close()
    except Exception as e:
        print(f"[!] Note on seeding trends: {e}")


def _ensure_blends_deck_column():
    """Add the blends.deck_json column to existing dev DBs (idempotent)."""
    from sqlalchemy import text
    try:
        with engine.connect() as conn:
            cols = [row[1] for row in conn.execute(text("PRAGMA table_info(blends)"))]
            if "deck_json" not in cols:
                conn.execute(text("ALTER TABLE blends ADD COLUMN deck_json TEXT"))
                conn.commit()
                print("[*] Added blends.deck_json column.")
    except Exception as e:
        print(f"[!] Note on blends.deck_json: {e}")


def seed_demo_social():
    """Seed a small connected demo graph so the social/feed/friends sections
    render real content instead of empty states. Idempotent: only seeds when
    the dev user has no friend suggestions yet. Dev-only."""
    try:
        from app.models import (
            User,
            Post,
            Like,
            FriendSuggestion,
            StylePersona,
        )
        from app.models_notifications import Notification
        from app.db import SessionLocal

        session = SessionLocal()
        try:
            dev_uid = "dev-user-123"
            existing_sugs = (
                session.query(FriendSuggestion.id)
                .filter(FriendSuggestion.suggester_firebase_uid == dev_uid)
                .first()
            )
            if existing_sugs:
                print("[*] Demo social already seeded — skipping.")
                return

            demo_users = [
                ("demo-user-1", "Aarav Kapoor", "aarav@demo.trenzy.app"),
                ("demo-user-2", "Meera Iyer", "meera@demo.trenzy.app"),
                ("demo-user-3", "Zara Sheikh", "zara@demo.trenzy.app"),
                ("demo-user-4", "Rohan Mehta", "rohan@demo.trenzy.app"),
                ("demo-user-5", "Avni Sharma", "avni@demo.trenzy.app"),
            ]
            uid_by_idx = {}
            for idx, (uid, name, email) in enumerate(demo_users, start=1):
                if not session.query(User.id).filter(User.firebase_uid == uid).first():
                    session.add(
                        User(
                            firebase_uid=uid,
                            name=name,
                            email=email,
                            bio=f"Trenzy demo {name.split()[-1]} — browsing the latest drops.",
                        )
                    )
                uid_by_idx[idx] = uid
                if not session.query(StylePersona.id).filter(
                    StylePersona.user_firebase_uid == uid
                ).first():
                    session.add(
                        StylePersona(
                            user_firebase_uid=uid,
                            name="Urban Minimalist",
                            description="Clean lines, neutral tones, quality basics.",
                            keywords=["minimal", "neutral", "tailored"],
                        )
                    )
            session.commit()

            reasons = [
                "Shares your taste in minimal outfits",
                "Active in the same blend groups",
                "Also follows minimalist streetwear",
                "Likes the brands you heart",
                "Style friends",
            ]
            for i, (uid, _, _) in enumerate(demo_users):
                session.add(
                    FriendSuggestion(
                        suggester_firebase_uid=dev_uid,
                        suggested_firebase_uid=uid,
                        score=round(0.9 - i * 0.12, 2),
                        reason=reasons[i % len(reasons)],
                    )
                )
            session.commit()

            posts = [
                (1, "Finally found the perfect linen shirt for the summer. Cleaning up my wishlist tonight!", "prod_001"),
                (2, "Saturday fit check — opted for straight-leg over slim. Thoughts?", "prod_002"),
                (3, "Adding these to the blend board 🎨 our group loved this palette", "prod_004"),
                (4, "Cozy + clean = this knit. Swipe it if you agree.", None),
                (5, "Rate this capsule wardrobe I'm building for the season.", "prod_003"),
            ]
            post_ids = []
            for idx, (author_idx, content, attachment) in enumerate(posts):
                uid = uid_by_idx[author_idx]
                name = demo_users[author_idx - 1][1]
                p = Post(
                    user_firebase_uid=uid,
                    user_name=name,
                    content=content,
                    attachment=attachment,
                )
                session.add(p)
                session.flush()
                post_ids.append(p.id)
            session.commit()

            like_authors = [uid_by_idx[(i % 5) + 1] for i in range(len(post_ids))]
            for post_id, liker in zip(post_ids, like_authors):
                if not session.query(Like.id).filter(
                    Like.post_id == post_id, Like.user_firebase_uid == liker
                ).first():
                    session.add(Like(post_id=post_id, user_firebase_uid=liker))
            session.commit()

            notifs = [
                (dev_uid, "like", "Aarav Kapoor liked your post", "Your fit check is getting attention."),
                (dev_uid, "blend", "Meera accepted your blend invite", "Start swiping together on your new blend."),
                (dev_uid, "recommendation", "New recommendations ready", "Your blend winners are in. Tap to review."),
            ]
            for idx, (uid, kind, title, body) in enumerate(notifs):
                if session.query(Notification.id).filter(Notification.id == f"notif-demo-{idx+1}").first():
                    continue
                session.add(
                    Notification(
                        id=f"notif-demo-{idx+1}",
                        user_firebase_uid=uid,
                        kind=kind,
                        title=title,
                        body=body,
                    )
                )
            session.commit()
            print("[*] Seeded demo social graph (5 users, suggestions, posts, likes, notifications).")
        finally:
            session.close()
    except Exception as e:
        print(f"[!] Note on seeding social: {e}")


def _refresh_dev_member_names():
    """Refresh blend member display names for dev-bypass identities.

    The dev token used to carry no display name, so members created while it
    was active were snapshotted as the generic fallback ("Guest"/"You"). Once
    DEV_AUTH_USERS supplies real names, re-derive the stored user_name for
    those rows so the roster/chat don't keep showing the fallback. Idempotent;
    called on every dev-server boot (the social seeder early-returns once the
    graph exists, so this must live outside it).
    """
    try:
        from app.config import DEV_AUTH_USERS, DEV_AUTH_NAME
        from app.db import SessionLocal
        from app.models import BlendMember

        session = SessionLocal()
        try:
            name_for = {
                uid: meta.get("name") or DEV_AUTH_NAME or "Demo User"
                for uid, meta in DEV_AUTH_USERS.items()
            }
            fallbacks = {"Guest", "You", ""}
            for member in session.query(BlendMember).all():
                real_name = name_for.get(member.user_firebase_uid)
                if real_name and (member.user_name or "") in fallbacks:
                    member.user_name = real_name
            session.commit()
        finally:
            session.close()
        print("[*] Refreshed dev member display names.")
    except Exception as e:
        print(f"[!] Note on refreshing member names: {e}")


def setup_database():
    print(f"[*] Initializing development database at: {sqlite_path}")
    Base.metadata.create_all(bind=engine)
    _ensure_blends_deck_column()
    try:
        load_products_data()
    except Exception as e:
        print(f"[!] Note on loading products: {e}")
    seed_demo_trends()
    seed_demo_social()
    _refresh_dev_member_names()
    print("[+] Database ready.")

if __name__ == "__main__":
    setup_database()
    print("[*] Starting Trenzy Backend on http://localhost:8000 ...")
    uvicorn.run(
        "app.main:api",
        host="::",
        port=8000,
        reload=False,
        log_level="info",
    )
