"""Boot the real backend against PostgreSQL and verify production-critical paths.

Run:  pice  python  backend  POSTGRES env vars UNSET .env overrides...
Simplest:  python3 scripts/verify_postgres.py
Expects a running Postgres on DB_HOST/DB_PORT (env or defaults 127.0.0.1:5433)
with user/pw/db from POSTGRES_* env vars.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

os.environ.setdefault("POSTGRES_USER", "trenzy")
os.environ.setdefault("POSTGRES_PASSWORD", "trenzy-dev-pw")
os.environ.setdefault("POSTGRES_DB", "trenzy")
os.environ.setdefault("DB_HOST", "127.0.0.1")
os.environ.setdefault("DB_PORT", "5433")
os.environ.setdefault("REDIS_URL", "")
os.environ.setdefault("PAYMENTS_MODE", "simulation")
os.environ.setdefault("DEV_AUTH_BYPASS", "true")
os.environ.setdefault("DEV_AUTH_UID", "test-user-1")
os.environ.setdefault("DEV_AUTH_SECRET", "test-dev-secret")
os.environ.pop("TRENZY_TEST_DB", None)
os.environ.pop("PYTEST_CURRENT_TEST", None)

from fastapi.testclient import TestClient

from app.main import app
from app.db import SessionLocal, engine
from app.models import Cart, CartItem, Product
from app.firebase_auth import make_dev_token
from app.routes.payments import _sign_checkout_token

HDRS = {"Authorization": f"Bearer {make_dev_token('test-user-1', os.environ['DEV_AUTH_SECRET'])}"}

results = []


def check(name, ok, detail=""):
    results.append((name, ok, detail))
    print(("PASS  " if ok else "FAIL  ") + name + (("  -> " + detail) if detail else ""))


with TestClient(app) as client:
    # 1. Health
    r = client.get("/api/health")
    check("health 200", r.status_code == 200, str(r.status_code))

    # 2. Raw DB dialect must be postgresql (not sqlite)
    with engine.begin() as conn:
        dialect = conn.dialect.name
    check("connected to postgresql", dialect == "postgresql", dialect)

    # 3. Products auto-seeded
    r = client.get("/api/products", params={"limit": 50})
    n = len(r.json().get("products", [])) if r.status_code == 200 else -1
    check("products listed", r.status_code == 200 and n > 0, f"n={n}")

    # 4. Full-text search (tsvector / to_tsquery / GIN)
    names = [p.get("name", "") for p in r.json().get("products", [])]
    q = (names[0].split()[0] if names else "shirt").strip("\"'")
    r2 = client.get("/api/products/search", params={"q": q, "limit": 10})
    n2 = len(r2.json().get("products", [])) if r2.status_code == 200 else -1
    check("products/search fulltext returns results",
          r2.status_code == 200 and n2 > 0, f"status={r2.status_code} q={q!r} n={n2}")

    # 5. Unified search
    r3 = client.get("/api/search", params={"q": q, "limit": 5})
    check("api/search 200", r3.status_code == 200, str(r3.status_code))

    # 6. Payment roundtrip (exercises with_for_update row locks on PG)
    with SessionLocal() as s:
        p = s.query(Product).first()
        uid = "test-user-1"
        cart = Cart(user_firebase_uid=uid)
        s.add(cart)
        s.commit()
        s.add(CartItem(cart_id=cart.id, user_firebase_uid=uid,
                       product_id=p.id, quantity=2))
        s.commit()

    ro = client.post("/api/payments/order", json={}, headers=HDRS)
    check("payments/order 200", ro.status_code == 200, str(ro.status_code))
    if ro.status_code == 200:
        data = ro.json()
        oid = data["razorpay_order_id"]
        rv = client.post("/api/payments/verify", headers=HDRS, json={
            "razorpay_order_id": oid,
            "razorpay_payment_id": "pay_pg_1",
            "razorpay_signature": "sig_pg_1",
        })
        check("payments/verify completed", rv.status_code == 200 and rv.json().get("status") == "completed", str(rv.status_code))
        rs = client.get(f"/api/payments/order/{oid}", headers=HDRS)
        check("payments/status completed", rs.status_code == 200 and rs.json().get("status") == "completed", str(rs.status_code))
        rc = client.get("/api/payments/checkout", params={"order": oid, "token": _sign_checkout_token(oid)})
        check("checkout page 200", rc.status_code == 200 and "text/html" in rc.headers.get("content-type", ""), str(rc.status_code))

print()
failed = [r for r in results if not r[1]]
print(f"RESULT: {len(results)-len(failed)}/{len(results)} passed")
sys.exit(1 if failed else 0)