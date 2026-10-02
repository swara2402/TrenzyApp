"""Backend unit tests for the wardrobe / outfit / recommendations endpoints.

Auth is handled by the DEV_AUTH_BYPASS — all API calls authenticate as
``test-user-1`` (DEV_AUTH_UID).  Cross-user isolation is tested by directly
seeding the database with items owned by a different UID and asserting the
API never returns or mutates them.
"""

import pytest
from app.models import WardrobeItem, Outfit, OutfitItem


# ────────────────────────────────────────────────────────────
# Helpers
# ────────────────────────────────────────────────────────────

def _seed_item(db_session, *, uid: str, name: str, category: str = "Tops") -> int:
    """Insert a WardrobeItem directly into the DB and return its id."""
    item = WardrobeItem(
        user_firebase_uid=uid,
        name=name,
        category=category,
    )
    db_session.add(item)
    db_session.commit()
    db_session.refresh(item)
    return item.id


# ────────────────────────────────────────────────────────────
# Auth guard tests
# ────────────────────────────────────────────────────────────

def test_unauthenticated_wardrobe_access(client):
    res = client.get("/api/wardrobe")
    assert res.status_code == 401

    res_rec = client.get("/api/wardrobe/recommendations")
    assert res_rec.status_code == 401


# ────────────────────────────────────────────────────────────
# Ownership / isolation tests (DB-seeded second user)
# ────────────────────────────────────────────────────────────

def test_user_isolation_and_ownership(client, db_session, auth_headers):
    """Items belonging to another UID must not be visible/mutable by the caller."""
    OTHER_UID = "other-user-99"

    # Seed an item owned by OTHER_UID directly (bypasses auth entirely)
    other_item_id = _seed_item(db_session, uid=OTHER_UID, name="Other User Jacket")

    # Caller's list should NOT contain the other user's item
    res_list = client.get("/api/wardrobe", headers=auth_headers)
    assert res_list.status_code == 200
    items = res_list.json()["wardrobe"]
    assert not any(i["id"] == other_item_id for i in items), (
        "Cross-user item must not appear in caller's wardrobe list"
    )

    # PATCH on other user's item → 404 (not 403, to avoid UID enumeration)
    res_patch = client.patch(
        f"/api/wardrobe/{other_item_id}",
        json={"name": "Hacked Name"},
        headers=auth_headers,
    )
    assert res_patch.status_code == 404

    # DELETE on other user's item → 404
    res_delete = client.delete(f"/api/wardrobe/{other_item_id}", headers=auth_headers)
    assert res_delete.status_code == 404


# ────────────────────────────────────────────────────────────
# Outfit create validation
# ────────────────────────────────────────────────────────────

def test_outfit_create_rejects_unowned_items(client, db_session, auth_headers):
    """Creating an outfit with another user's item IDs must fail with 400."""
    OTHER_UID = "other-user-99"

    # Seed an item owned by OTHER_UID
    other_item_id = _seed_item(db_session, uid=OTHER_UID, name="Other Shirt")

    # Caller tries to create outfit referencing another user's item → 400
    res = client.post(
        "/api/wardrobe/outfits",
        json={"name": "Invalid Outfit", "wardrobe_item_ids": [other_item_id]},
        headers=auth_headers,
    )
    assert res.status_code == 400
    body = res.json()
    # The app uses a custom error handler: {status, error_code, message}
    error_msg = body.get("detail") or body.get("message") or ""
    assert "not found or not owned" in error_msg


# ────────────────────────────────────────────────────────────
# Filtering & pagination
# ────────────────────────────────────────────────────────────

def test_wardrobe_filtering_and_pagination(client, auth_headers):
    # Seed items via API
    client.post(
        "/api/wardrobe",
        json={"name": "White Summer Tee", "category": "Tops", "color": "White", "season": "SUMMER"},
        headers=auth_headers,
    )
    client.post(
        "/api/wardrobe",
        json={"name": "Blue Denim Pants", "category": "Bottoms", "color": "Blue", "season": "FALL"},
        headers=auth_headers,
    )

    # Filter by category
    res_tops = client.get("/api/wardrobe?category=Tops", headers=auth_headers)
    assert res_tops.status_code == 200
    wardrobe = res_tops.json()["wardrobe"]
    assert all(i["category"] == "Tops" for i in wardrobe)

    # Search filter
    res_search = client.get("/api/wardrobe?search=Denim", headers=auth_headers)
    assert res_search.status_code == 200
    search_results = res_search.json()["wardrobe"]
    assert len(search_results) >= 1
    assert "Denim" in search_results[0]["name"]

    # Pagination: total / hasMore / offset must survive round-trips
    import uuid as _uuid

    suffix = _uuid.uuid4().hex[:8]
    for i in range(3):
        res_add = client.post(
            "/api/wardrobe",
            json={"name": f"Paging Item {i} {suffix}", "category": "Tops"},
            headers=auth_headers,
        )
        assert res_add.status_code == 200

    page1 = client.get("/api/wardrobe?limit=2&offset=0", headers=auth_headers).json()
    assert len(page1["wardrobe"]) == 2
    assert page1["pagination"]["total"] >= 3
    assert page1["pagination"]["hasMore"] is True

    last_page = client.get("/api/wardrobe?limit=50&offset=50", headers=auth_headers).json()
    assert last_page["wardrobe"] == []
    assert last_page["pagination"]["hasMore"] is False


# ────────────────────────────────────────────────────────────
# Recommendations endpoint
# ────────────────────────────────────────────────────────────

def test_wardrobe_recommendations_endpoint(client, auth_headers):
    # Seed items for a reasonably complete wardrobe
    client.post(
        "/api/wardrobe",
        json={"name": "Graphic Cotton Tee", "category": "Tops", "color": "Black"},
        headers=auth_headers,
    )
    client.post(
        "/api/wardrobe",
        json={"name": "Slim Jeans", "category": "Bottoms", "color": "Blue"},
        headers=auth_headers,
    )
    client.post(
        "/api/wardrobe",
        json={"name": "White Canvas Sneakers", "category": "Shoes", "color": "White"},
        headers=auth_headers,
    )

    res = client.get("/api/wardrobe/recommendations?limit=5", headers=auth_headers)
    assert res.status_code == 200
    data = res.json()

    assert "summary" in data
    assert "gaps" in data
    assert "productSuggestions" in data
    assert "outfitIdeas" in data

    summary = data["summary"]
    assert "itemCount" in summary
    assert "byRole" in summary
    assert "byCategory" in summary

    outfit_ideas = data["outfitIdeas"]
    assert isinstance(outfit_ideas, list)
    if len(outfit_ideas) > 0:
        idea = outfit_ideas[0]
        assert "title" in idea
        assert "wardrobeItemIds" in idea
        assert "pieces" in idea
        assert "reason" in idea
