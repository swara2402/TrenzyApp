"""Trend Prediction Engine API endpoints."""
from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any, Optional

from fastapi import APIRouter, HTTPException, Query, Request
from pydantic import BaseModel
from sqlalchemy import func, select

from ..db import SessionLocal
from ..firebase_auth import verify_firebase_token
from ..models import AffiliateClick, Product, ProductView, TrendMetric

router = APIRouter(prefix="/api/trends", tags=["trends"])


def _get_uid(decoded: dict[str, Any]) -> str:
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")
    return str(uid)


# Request/Response models
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


@router.get("/")
def get_trending_products(
    request: Request,
    category: Optional[str] = Query(None, description="Filter by category"),
    timeframe: str = Query("daily", description="Time window: hourly, daily, weekly"),
    limit: int = Query(20, ge=1, le=100, description="Max results to return"),
) -> dict[str, Any]:
    """GET trending products ordered by trending score."""
    verify_firebase_token(request)

    db = SessionLocal()
    try:
        # Get the latest trend metrics
        now = datetime.utcnow()
        if timeframe == "hourly":
            window_start = now - timedelta(hours=1)
        elif timeframe == "weekly":
            window_start = now - timedelta(days=7)
        else:  # daily
            window_start = now - timedelta(days=1)

        # Query trend metrics
        stmt = (
            select(TrendMetric, Product)
            .join(Product, Product.id == TrendMetric.product_id)
            .where(TrendMetric.window_start >= window_start)
            .where(TrendMetric.timeframe == timeframe)
        )
        if category:
            stmt = stmt.where(TrendMetric.category == category)

        stmt = stmt.order_by(TrendMetric.trending_score.desc()).limit(limit)
        results = db.execute(stmt).all()

        trends = []
        for metric, product in results:
            trends.append(
                {
                    "productId": metric.product_id,
                    "productName": product.name,
                    "category": product.category,
                    "imageUrl": product.image_url,
                    "viewCount": metric.view_count,
                    "clickCount": metric.click_count,
                    "trendingScore": metric.trending_score,
                    "momentum": metric.momentum,
                    "timeframe": metric.timeframe,
                }
            )

        return {"trends": trends, "timeframe": timeframe, "count": len(trends)}
    finally:
        db.close()


@router.get("/predictions")
def get_trend_predictions(
    request: Request,
    category: Optional[str] = Query(None, description="Filter by category"),
    limit: int = Query(10, ge=1, le=50, description="Max predictions to return"),
) -> dict[str, Any]:
    """GET predicted trending products based on momentum analysis."""
    verify_firebase_token(request)

    db = SessionLocal()
    try:
        # Get trend metrics with highest momentum (rising stars)
        now = datetime.utcnow()
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
        results = db.execute(stmt).all()

        predictions = []
        for metric, product in results:
            # Calculate confidence based on view count and momentum
            confidence = min(100, (metric.view_count / 100) * 100) if metric.view_count > 0 else 50
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
    finally:
        db.close()


@router.post("/track-view")
def track_product_view(data: ProductTrendUpdate, request: Request) -> dict[str, Any]:
    """POST to record a product view for trend analytics."""
    decoded = verify_firebase_token(request)
    uid = _get_uid(decoded) if decoded.get("uid") else None

    db = SessionLocal()
    try:
        # Check product exists
        product = db.query(Product).filter(Product.id == data.product_id).first()
        if not product:
            raise HTTPException(status_code=404, detail="Product not found")

        # Record the view
        view = ProductView(
            product_id=data.product_id,
            viewed_by_firebase_uid=uid,
        )
        db.add(view)


        # Update today's daily metric
        today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
        metric = (
            db.query(TrendMetric)
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
            db.add(metric)

        db.commit()
        return {"status": "recorded", "product_id": data.product_id}
    finally:
        db.close()


@router.get("/aggregate")
def aggregate_trends(
    request: Request,
    timeframe: str = Query("daily", description="Time window to aggregate"),
) -> dict[str, Any]:
    """POST to run aggregation job (compute trending scores)."""
    verify_firebase_token(request)

    db = SessionLocal()
    try:
        now = datetime.utcnow()
        if timeframe == "hourly":
            window_start = now - timedelta(hours=1)
        elif timeframe == "weekly":
            window_start = now - timedelta(days=7)
        else:
            window_start = now - timedelta(days=1)

        # Get all product views in the window
        stmt = (
            select(
                ProductView.product_id,
                func.count(ProductView.id).label("view_count"),
            )
            .where(ProductView.created_at >= window_start)
            .group_by(ProductView.product_id)
        )
        view_counts = db.execute(stmt).all()

        # Get click counts
        click_stmt = (
            select(
                AffiliateClick.product_id,
                func.count(AffiliateClick.id).label("click_count"),
            )
            .where(AffiliateClick.created_at >= window_start)
            .group_by(AffiliateClick.product_id)
        )
        click_counts = db.execute(click_stmt).all()
        click_map = {c.product_id: c.click_count for c in click_counts}

        # Get product for category
        products = {p.id: p for p in db.query(Product).all()}

        # Update or create metrics
        updated = 0
        for vc in view_counts:
            product = products.get(vc.product_id)
            if not product:
                continue

            click_count = click_map.get(vc.product_id, 0)
            # Calculate trending score: weighted combination
            trending_score = (vc.view_count * 1.0) + (click_count * 3.0)
            # Calculate momentum (compare to previous window)
            prev_start = window_start - timedelta(days=1) if timeframe == "daily" else window_start - timedelta(hours=1)
            prev_metric = (
                db.query(TrendMetric)
                .filter(
                    TrendMetric.product_id == vc.product_id,
                    TrendMetric.timeframe == timeframe,
                    TrendMetric.window_start == prev_start,
                )
                .first()
            )
            if prev_metric and prev_metric.view_count > 0:
                momentum = (vc.view_count - prev_metric.view_count) / prev_metric.view_count
            else:
                momentum = 0.0

            # Upsert metric
            metric = (
                db.query(TrendMetric)
                .filter(
                    TrendMetric.product_id == vc.product_id,
                    TrendMetric.timeframe == timeframe,
                    TrendMetric.window_start >= window_start,
                )
                .first()
            )
            if metric:
                metric.view_count = vc.view_count
                metric.click_count = click_count
                metric.trending_score = trending_score
                metric.momentum = momentum
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
                db.add(metric)
            updated += 1

        db.commit()
        return {"status": "aggregated", "products_updated": updated, "timeframe": timeframe}
    finally:
        db.close()
