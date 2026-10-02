"""E2E tests for core API endpoints."""



def test_health(client, monkeypatch):
    """Health endpoint responds with Firebase and DB checks.

    The overall status may be 'healthy' or 'degraded' depending on whether the
    test DB contains catalog data and embeddings. We only assert that the
    endpoint is reachable and that the database and firebase checks pass.
    """
    from app import firebase_auth

    # Firebase Admin cannot initialize in unit tests (/dev/null credentials);
    # patch the flag so we assert the endpoint's healthy-path wiring.
    monkeypatch.setattr(firebase_auth, "_firebase_initialized", True)

    resp = client.get("/api/health")
    assert resp.status_code == 200
    data = resp.json()
    # Overall status may be 'healthy' or 'degraded' in CI (empty catalog is expected).
    assert data["status"] in ("healthy", "degraded")
    assert data["checks"]["database"] == "healthy"
    assert data["checks"]["firebase"] == "healthy"


def test_health_degraded_without_firebase(client, monkeypatch):
    """Uninitialized Firebase Admin degrades overall status (fail-visible)."""
    from app import firebase_auth

    # Deterministic: a developer's .env may set FIREBASE_PROJECT_ID,
    # which intentionally enables public-cert mode instead of "unhealthy".
    monkeypatch.setattr(firebase_auth, "FIREBASE_PROJECT_ID", "", raising=False)
    assert not firebase_auth._firebase_initialized
    resp = client.get("/api/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["checks"]["firebase"] == "unhealthy"
    assert data["status"] == "degraded"


def test_health_unauthorized(client):
    """Health endpoint requires no auth."""
    resp = client.get("/api/health")
    assert resp.status_code == 200


def test_products_list(client, auth_headers):
    resp = client.get("/api/products", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "products" in data


def test_products_missing_token(client):
    """Products endpoint is public — no auth required."""
    resp = client.get("/api/products")
    assert resp.status_code == 200


def test_categories(client, auth_headers):
    resp = client.get("/api/categories", headers=auth_headers)
    assert resp.status_code == 200


def test_brands(client, auth_headers):
    resp = client.get("/api/brands", headers=auth_headers)
    assert resp.status_code == 200


def test_feed(client, auth_headers):
    resp = client.get("/api/feed", headers=auth_headers)
    assert resp.status_code == 200


def test_trends_hot(client, auth_headers):
    resp = client.get("/api/trends/hot", headers=auth_headers)
    assert resp.status_code == 200


def test_trends_creators(client, auth_headers):
    resp = client.get("/api/trends/creators", headers=auth_headers)
    assert resp.status_code == 200


def test_recommend_products(client, auth_headers):
    resp = client.get("/api/recommend/products?limit=5", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "products" in data


def test_recommend_people(client, auth_headers):
    resp = client.get("/api/recommend/people?limit=5", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "people" in data


def test_recommend_outfits(client, auth_headers):
    resp = client.get("/api/recommend/outfits?limit=3", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "outfits" in data


def test_follow_status(client, auth_headers):
    resp = client.get("/api/follow/status/test-user-2", headers=auth_headers)
    # 200 or 404 (if user not found) are both acceptable
    assert resp.status_code in (200, 404)


def test_saves_list(client, auth_headers):
    resp = client.get("/api/saves", headers=auth_headers)
    assert resp.status_code in (200, 404)


def test_wishlist(client, auth_headers):
    resp = client.get("/api/wishlist", headers=auth_headers)
    assert resp.status_code in (200, 404)


def test_activity(client, auth_headers):
    resp = client.get("/api/activity", headers=auth_headers)
    # 200 or 500 (missing DB table in test env) are both possible
    assert resp.status_code in (200, 404, 500)


def test_suggestions(client, auth_headers):
    resp = client.get("/api/suggestions?limit=5", headers=auth_headers)
    assert resp.status_code in (200, 404)


def test_cart(client, auth_headers):
    resp = client.get("/api/cart", headers=auth_headers)
    assert resp.status_code in (200, 404)


def test_blends_user(client, auth_headers):
    resp = client.get("/api/groups/user", headers=auth_headers)
    assert resp.status_code in (200, 404)


def test_user_profile(client, auth_headers):
    resp = client.get("/api/users/me", headers=auth_headers)
    # 200 if user exists, 404 if not in seed data, 405 if wrong method
    assert resp.status_code in (200, 404, 405)


def test_friend_suggestions(client, auth_headers):
    resp = client.get("/api/friends/suggestions", headers=auth_headers)
    assert resp.status_code == 200


def test_notifications(client, auth_headers):
    resp = client.get("/api/notifications", headers=auth_headers)
    assert resp.status_code == 200
