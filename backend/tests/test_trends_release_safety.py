from datetime import datetime, timedelta, timezone

import pytest

from app import auth_helpers
from app.models import AffiliateClick, Product, TrendMetric
from app.routes import trends


@pytest.mark.parametrize(
    "path",
    [
        "/api/trends?timeframe=monthly",
        "/api/trends/hot?limit=0",
        "/api/trends/creators?limit=101",
        "/api/recommendations/discover/swipe?limit=0",
        "/api/recommend/people?limit=101",
        "/api/recommend/outfits?limit=0",
        "/api/recommend/products?limit=101",
    ],
)
def test_discovery_and_trend_queries_reject_unsupported_limits(client, auth_headers, path):
    response = client.get(path, headers=auth_headers)
    assert response.status_code == 422


@pytest.mark.parametrize(
    "path,payload",
    [
        ("/api/trends/aggregate", {"timeframe": "monthly"}),
        ("/api/persona/preferences", {"budget_max": -1}),
    ],
)
def test_trend_and_persona_writes_reject_invalid_values(
    client, auth_headers, path, payload
):
    response = client.post(path, json=payload, headers=auth_headers)
    assert response.status_code == 422


def test_trending_category_filter_uses_product_category_case_insensitively(
    client, db_session, auth_headers
):
    product = Product(id="trend-category-test", name="Test Top", category="Tops")
    db_session.add(product)
    db_session.add(
        TrendMetric(
            product_id=product.id,
            timeframe="daily",
            window_start=datetime.now(timezone.utc) - timedelta(minutes=10),
            view_count=4,
            click_count=0,
            trending_score=4,
            momentum=0,
            category="stale-category",
        )
    )
    db_session.commit()

    response = client.get("/api/trends?category=TOPS", headers=auth_headers)

    assert response.status_code == 200
    assert [item["productId"] for item in response.json()["trends"]] == [product.id]


def test_trend_aggregation_includes_click_only_products(
    client, db_session, auth_headers, monkeypatch
):
    product = Product(id="trend-click-only-test", name="Clicked Product", category="Tops")
    db_session.add(product)
    window_end = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    db_session.add(
        AffiliateClick(
            product_id=product.id,
            clicked_by_firebase_uid="test-user-1",
            created_at=window_end - timedelta(hours=1),
        )
    )
    db_session.commit()

    monkeypatch.setattr(
        trends, "verify_firebase_token", lambda _: {"uid": "test-user-1"}
    )
    monkeypatch.setattr(auth_helpers, "user_is_admin", lambda *_: True)

    response = client.post(
        "/api/trends/aggregate",
        json={"timeframe": "daily"},
        headers=auth_headers,
    )

    assert response.status_code == 200
    metric = (
        db_session.query(TrendMetric)
        .filter(
            TrendMetric.product_id == product.id,
            TrendMetric.timeframe == "daily",
        )
        .one()
    )
    assert metric.view_count == 0
    assert metric.click_count == 1
    assert metric.trending_score == 3
