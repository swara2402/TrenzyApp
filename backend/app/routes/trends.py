"""Trend prediction engine API endpoints.

Tracks product views and affiliate clicks to compute trending scores and
predict which products are gaining popularity. The scoring formula:

``trending_score = (view_count * 1.0) + (click_count * 3.0)``

Clicks are weighted 3x because they indicate higher purchase intent than
passive views. Momentum measures day-over-day growth rate:

``momentum = (today_views - yesterday_views) / yesterday_views``

Endpoints:
- ``GET /api/trends/``: Trending products for a timeframe
- ``GET /api/trends/predictions``: Products with highest momentum (rising fast)
- ``POST /api/trends/track-view``: Record a product view
- ``GET /api/trends/aggregate``: Run the aggregation job (compute scores)
- ``GET /api/trends/hot``: Pre-computed hot products
- ``GET /api/trends/creators``: Trending content creators
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..db import get_session
from ..auth_deps import get_current_user
from ..models import TrendingCreator, TrendingProduct, AffiliateClick, Product, View, TrendMetric

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/trends", tags=["trends"])


def _get_uid(decoded: dict[str, Any]) -> str:
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")
    return str(uid)


class TrendResponse(BaseModel):
    productId: str
    productName: str
    category: Optional[str]
    imageUrl: Optional[str]
    viewCount: int
    clickCount: int
    trendingScore: float
    momentum: float
    timeframe: str


class PredictionResponse(BaseModel):
    productId: str
    productName: str
    category: Optional[str]
    imageUrl: Optional[str]
    predictedTrendScore: float
    confidence: float
    reasoning: str


class ProductTrendUpdate(BaseModel):
    product_id: str


@router.get("")
def get_trending_products(
    request: Request,
    category: Optional[str] = Query(None, description="Filter by single category"),
    categories: Optional[str] = Query(None, description="Comma-separated category list"),
    timeframe: str = Query("daily", description="Time window: hourly, daily, weekly"),
    limit: int = Query(20, ge=1, le=100, description="Max results to return"),
    user: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    """GET trending products ordered by trending score."""

    now = datetime.now(timezone.utc)
    if timeframe == "hourly":
        window_start = now - timedelta(hours=1)
    elif timeframe == "weekly":
        window_start = now - timedelta(days=7)
    else:  # daily
        window_start = now - timedelta(days=1)

    stmt = (
        select(TrendMetric, Product)
        .join(Product, Product.id == TrendMetric.product_id)
        .where(TrendMetric.window_start >= window_start)
        .where(TrendMetric.timeframe == timeframe)
    )
    # Filter on the product's category (not TrendMetric.category): seeded
    # metrics carry a stale bucket value, and the client sends display labels
    # ("Tops") while products store lowercase values ("tops").
    if categories:
        cat_list = [c.strip().lower() for c in categories.split(",") if c.strip()]
        if cat_list:
            stmt = stmt.where(func.lower(Product.category).in_(cat_list))
    elif category:
        stmt = stmt.where(func.lower(Product.category) == category.strip().lower())

    stmt = stmt.order_by(TrendMetric.trending_score.desc()).limit(limit)
    results = session.execute(stmt).all()

    trends = []
    for metric, product in results:
        trends.append(
            {
                "productId": metric.product_id,
                "productName": product.name,
                "category": product.category,
                "imageUrl": product.image_url,
                "brand": product.brand,
                "price": product.price,
                "rating": product.rating,
                "viewCount": metric.view_count,
                "clickCount": metric.click_count,
                "trendingScore": metric.trending_score,
                "momentum": metric.momentum,
                "timeframe": metric.timeframe,
            }
        )

    return {"trends": trends, "timeframe": timeframe, "count": len(trends)}


@router.get("/predictions")
def get_trend_predictions(
    request: Request,
    category: Optional[str] = Query(None, description="Filter by category"),
    limit: int = Query(10, ge=1, le=50, description="Max predictions to return"),
    user: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    """GET predicted trending products based on momentum analysis."""

    now = datetime.now(timezone.utc)
    window_start = now - timedelta(days=1)

    stmt = (
        select(TrendMetric, Product)
        .join(Product, Product.id == TrendMetric.product_id)
        .where(TrendMetric.window_start >= window_start)
        .where(TrendMetric.timeframe == "daily")
    )
    if category:
        stmt = stmt.where(TrendMetric.category == category)

    stmt = stmt.order_by(TrendMetric.momentum.desc()).limit(limit)
    results = session.execute(stmt).all()

    predictions = []
    for metric, product in results:
        confidence = (
            min(95, 30 + (metric.view_count * 0.5) + (metric.momentum * 20))
            if metric.view_count > 0
            else 30
        )
        if metric.momentum > 0.5:
            reasoning = f"Rising fast! {metric.view_count} views with {metric.momentum:.1%} momentum"
        elif metric.momentum > 0.2:
            reasoning = f"Steady growth: {metric.view_count} views today"
        else:
            reasoning = f"Popular pick: {metric.view_count} views"

        predictions.append(
            {
                "productId": metric.product_id,
                "productName": product.name,
                "category": product.category,
                "imageUrl": product.image_url,
                "predictedTrendScore": metric.trending_score + metric.momentum * 50,
                "confidence": confidence,
                "reasoning": reasoning,
            }
        )

    return {"predictions": predictions, "count": len(predictions)}


@router.post("/track-view")
def track_product_view(
    data: ProductTrendUpdate,
    request: Request,
    user: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    """POST to record a product view for trend analytics."""
    uid = _get_uid(user)

    product = session.query(Product).filter(Product.id == data.product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    today_start = datetime.now(timezone.utc).replace(
        hour=0, minute=0, second=0, microsecond=0
    )

    if uid:
        existing = (
            session.query(View)
            .filter(
                View.product_id == data.product_id,
                View.viewed_by_firebase_uid == uid,
                View.created_at >= today_start,
            )
            .first()
        )
        if existing:
            return {"status": "already_recorded", "product_id": data.product_id}

    view = View(
        product_id=data.product_id,
        viewed_by_firebase_uid=uid,
    )
    session.add(view)

    metric = (
        session.query(TrendMetric)
        .filter(
            TrendMetric.product_id == data.product_id,
            TrendMetric.timeframe == "daily",
            TrendMetric.window_start == today_start,
        )
        .first()
    )

    if metric:
        metric.view_count += 1
    else:
        metric = TrendMetric(
            product_id=data.product_id,
            timeframe="daily",
            window_start=today_start,
            view_count=1,
            click_count=0,
            category=product.category,
        )
        session.add(metric)

    session.commit()
    return {"status": "recorded", "product_id": data.product_id}


@router.post("/affiliate-click")
def track_affiliate_click(
    data: ProductTrendUpdate,
    request: Request,
    user: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    """POST to record an affiliate ("Shop on Partner") click.

    Feeds trend scoring (clicks are weighted 3x vs views) and powers the
    affiliate attribution pipeline. Returns the clean affiliate URL when the
    product has one so the client can open the partner site directly.
    """
    uid = _get_uid(user)

    product = session.query(Product).filter(Product.id == data.product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    click = AffiliateClick(
        product_id=data.product_id,
        clicked_by_firebase_uid=uid,
    )
    session.add(click)

    today_start = datetime.now(timezone.utc).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    metric = (
        session.query(TrendMetric)
        .filter(
            TrendMetric.product_id == data.product_id,
            TrendMetric.timeframe == "daily",
            TrendMetric.window_start == today_start,
        )
        .first()
    )
    if metric:
        metric.click_count += 1
    else:
        metric = TrendMetric(
            product_id=data.product_id,
            timeframe="daily",
            window_start=today_start,
            view_count=0,
            click_count=1,
            category=product.category,
        )
        session.add(metric)

    session.commit()

    affiliate_link = None
    raw_links = product.affiliate_links
    if isinstance(raw_links, dict):
        for key, value in raw_links.items():
            if value and str(value).startswith(("http://", "https://")):
                affiliate_link = str(value)
                break
    elif isinstance(raw_links, str) and raw_links.strip().startswith("http"):
        affiliate_link = raw_links.strip()

    return {
        "status": "recorded",
        "product_id": data.product_id,
        "affiliate_link": affiliate_link,
    }


class _TrendAggregationRequest(BaseModel):
    timeframe: str = "daily"


@router.post("/aggregate")
def aggregate_trends(
    request: Request,
    payload: Optional[_TrendAggregationRequest] = None,
    timeframe: str = Query("daily", description="Time window to aggregate"),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    """POST to run aggregation job (compute trending scores).

    Requires admin privileges. Move to a background task/cron for production.

    `timeframe` is read from the JSON body (e.g. `{"timeframe": "weekly"}`);
    a query-string `?timeframe=` is still accepted for backward compatibility.
    """
    if payload is not None:
        timeframe = payload.timeframe
    decoded = verify_firebase_token(request)
    from ..auth_helpers import user_is_admin
    if not user_is_admin(decoded, session):
        raise HTTPException(status_code=403, detail="Only admins can run aggregation")

    # ── Trend Aggregation Algorithm ──────────────────────────────────────
    #
    # This endpoint computes trending scores for all products that received
    # views in the given time window. The algorithm:
    #
    # 1. Count views per product in the window (from View table)
    # 2. Count affiliate clicks per product in the window (from AffiliateClick)
    # 3. Compute trending_score = views * 1.0 + clicks * 3.0
    #    (Clicks weighted 3x because they indicate purchase intent)
    # 4. Compute momentum = (current_views - previous_views) / previous_views
    #    (Positive = growing, negative = declining, 0 = stable)
    # 5. Upsert TrendMetric rows (create new or update existing)
    #
    # The previous window is determined by timeframe:
    # - hourly: previous 1-hour window
    # - daily: previous day
    # - weekly: previous 7 days
    #
    # Why upsert instead of delete+insert: Preserves historical TrendMetric
    # rows for trend analysis. The "hot" and "predictions" endpoints read
    # these rows to show trending products over different timeframes.

    now = datetime.now(timezone.utc)
    if timeframe == "hourly":
        window_start = now - timedelta(hours=1)
    elif timeframe == "weekly":
        window_start = now - timedelta(days=7)
    else:
        window_start = now - timedelta(days=1)

    # Aggregate view counts per product in the time window
    stmt = (
        select(
            View.product_id,
            func.count(View.id).label("view_count"),
        )
        .where(View.created_at >= window_start)
        .group_by(View.product_id)
    )
    view_counts = session.execute(stmt).all()

    # Aggregate click counts per product in the time window
    click_stmt = (
        select(
            AffiliateClick.product_id,
            func.count(AffiliateClick.id).label("click_count"),
        )
        .where(AffiliateClick.created_at >= window_start)
        .group_by(AffiliateClick.product_id)
    )
    click_counts = session.execute(click_stmt).all()
    click_map = {c.product_id: c.click_count for c in click_counts}

    vc_product_ids = [vc.product_id for vc in view_counts]
    products = {
        p.id: p
        for p in session.query(Product).filter(Product.id.in_(vc_product_ids)).all()
    } if vc_product_ids else {}

    prev_start = (
        window_start - timedelta(days=1)
        if timeframe == "daily"
        else window_start - timedelta(hours=1)
    )
    prev_metrics = {
        m.product_id: m
        for m in session.query(TrendMetric).filter(
            TrendMetric.product_id.in_(vc_product_ids),
            TrendMetric.timeframe == timeframe,
            TrendMetric.window_start == prev_start,
        ).all()
    } if vc_product_ids else {}

    existing_metrics = {
        m.product_id: m
        for m in session.query(TrendMetric).filter(
            TrendMetric.product_id.in_(vc_product_ids),
            TrendMetric.timeframe == timeframe,
            TrendMetric.window_start >= window_start,
        ).all()
    } if vc_product_ids else {}

    updated = 0
    for vc in view_counts:
        product = products.get(vc.product_id)
        if not product:
            continue

        click_count = click_map.get(vc.product_id, 0)
        trending_score = (vc.view_count * 1.0) + (click_count * 3.0)

        prev_metric = prev_metrics.get(vc.product_id)
        if prev_metric and prev_metric.view_count > 0:
            momentum = (
                vc.view_count - prev_metric.view_count
            ) / prev_metric.view_count
        else:
            momentum = 0.0

        metric = existing_metrics.get(vc.product_id)
        if metric:
            metric.view_count = vc.view_count
            metric.click_count = click_count
            metric.trending_score = trending_score
            metric.momentum = momentum
            # Keep the denormalized category in sync with the product so
            # category-filtered trend queries stop returning nothing.
            metric.category = product.category
        else:
            metric = TrendMetric(
                product_id=vc.product_id,
                timeframe=timeframe,
                window_start=window_start,
                view_count=vc.view_count,
                click_count=click_count,
                trending_score=trending_score,
                momentum=momentum,
                category=product.category if product else None,
            )
            session.add(metric)
        updated += 1

    session.commit()
    return {
        "status": "aggregated",
        "products_updated": updated,
        "timeframe": timeframe,
    }


@router.get("/hot")
def get_trending_hot_products(
    request: Request,
    timeframe: str = Query("daily", description="daily or weekly"),
    limit: int = Query(20, le=100),
    user: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    rows = (
        session.query(TrendingProduct)
        .filter(TrendingProduct.timeframe == timeframe)
        .order_by(TrendingProduct.trending_score.desc())
        .limit(limit)
        .all()
    )
    return {
        "trending": [
            {
                "product_id": tp.product_id,
                "score": tp.trending_score,
                "momentum": tp.momentum,
                "timeframe": tp.timeframe,
                "window_start": tp.window_start.isoformat() if tp.window_start else None,
            }
            for tp in rows
        ]
    }


@router.get("/creators")
def get_trending_creators(
    request: Request,
    timeframe: str = Query("daily", description="daily or weekly"),
    limit: int = Query(20, le=100),
    user: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    rows = (
        session.query(TrendingCreator)
        .filter(TrendingCreator.timeframe == timeframe)
        .order_by(TrendingCreator.trending_score.desc())
        .limit(limit)
        .all()
    )
    return {
        "creators": [
            {
                "user_firebase_uid": tc.user_firebase_uid,
                "score": tc.trending_score,
                "timeframe": tc.timeframe,
            }
            for tc in rows
        ]
    }