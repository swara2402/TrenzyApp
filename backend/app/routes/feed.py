"""Home feed endpoint with multi-section content.

The feed combines four content sources into a single response:

1. **Trending Now**: Highest-rated products (simple popularity signal).
2. **Just Dropped**: Newest products by ID (freshness signal).
3. **For You**: Personalized by user preferences (categories) and style persona
   (keywords, color palette). Falls back to top-rated if no preferences set.
4. **Community Posts**: Social posts ranked by a weighted scoring formula:
   ``score = follows * 0.30 + blend * 0.30 + engagement * 0.30 + freshness * 0.10``

The freshness component uses exponential decay: ``exp(-hours_old / 24)`` so posts
from the last 24 hours get the highest freshness score, decaying to near-zero
after a few days. Engagement is measured as ``likes * 1.0 + comments * 0.7``
(comments weighted lower because they can be negative).

Why 4 sections: Users need a mix of discovery (trending/new), personalization
(for you), and social proof (community) to stay engaged. The section structure
gives the Flutter app flexibility to render each differently.
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy import case, desc, func, select, or_
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..models import BlendMember, Follow, Like, Post, Comment, Product, UserPreference, StylePersona
from ..color_taxonomy import expand_canonical_to_raw
from ..json_compat import json_array_contains
from .products import _product_payload
from .priority_scorer import priority_score_expr
from .recommendations import _reason_for_item

router = APIRouter(prefix="/api/feed", tags=["feed"])


class FeedRequest(BaseModel):
    offset: int = 0
    limit: int = 20


def _uid(decoded: dict[str, Any]) -> str:
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")
    return str(uid)


def _safe_prefs(session: Session, uid: str) -> tuple:
    """Safely fetch UserPreference and StylePersona, returning (None, None) on error."""
    try:
        prefs = session.query(UserPreference).filter(
            UserPreference.user_firebase_uid == uid
        ).first()
    except Exception as e:
        logger.warning("Failed to fetch UserPreference for uid %s: %s", uid, e)
        prefs = None
    try:
        persona = session.query(StylePersona).filter(
            StylePersona.user_firebase_uid == uid
        ).first()
    except Exception as e:
        logger.warning("Failed to fetch StylePersona for uid %s: %s", uid, e)
        persona = None
    return prefs, persona


def _safe_query_all(session, stmt):
    """Safely execute a query and return all results, or empty list on error."""
    try:
        return list(session.execute(stmt).all())
    except Exception as exc:
        logger.warning("Feed query failed (returning empty): %s", exc)
        return []


def _all_raw_colors(session: Session) -> list[str]:
    """Fetch all distinct raw color values from the product catalog."""
    try:
        rows = session.query(Product.color).filter(
            Product.color.isnot(None)
        ).distinct().all()
        return [r[0] for r in rows if r[0]]
    except Exception as e:
        logger.warning("Failed to fetch raw catalog colors: %s", e)
        return []


def _expand_colors(session: Session, canonical: list[str]) -> list[str]:
    """Expand canonical color names into all matching raw catalog values."""
    return expand_canonical_to_raw(canonical, _all_raw_colors(session))


@router.get("")
def get_feed(
    request: Request,
    offset: int = 0,
    limit: int = 20,
    session: Session = Depends(get_session),
):
    try:
        decoded = verify_firebase_token(request)
        uid = decoded.get("uid")
        if not uid:
            raise HTTPException(status_code=401, detail="Missing uid claim")
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Feed auth error: %s", exc)
        raise HTTPException(status_code=401, detail="Authentication failed")

    offset = max(0, min(offset, 500))
    limit = max(1, min(limit, 50))

    sections = []

    # Fetch user preferences early for reuse across sections
    prefs, persona = _safe_prefs(session, uid)
    expanded_colors = (
        _expand_colors(session, prefs.preferred_colors)
        if prefs and prefs.preferred_colors else []
    )

    # Section 1: Trending Now — highest-rated products, filtered by preferences
    try:
        trending_query = session.query(Product).filter(Product.is_archived.is_(False))
        if prefs and prefs.preferred_categories:
            trending_query = trending_query.filter(
                Product.category.in_(prefs.preferred_categories)
            )
        trending = trending_query.order_by(Product.rating.desc().nullslast()).offset(offset).limit(limit).all()
        if not trending:
            trending = (
                session.query(Product)
                .filter(Product.is_archived.is_(False))
                .order_by(Product.rating.desc().nullslast())
                .offset(offset)
                .limit(limit)
                .all()
            )
    except Exception as exc:
        logger.warning("Feed trending query failed: %s", exc)
        trending = []
    sections.append({
        "id": "trending",
        "title": "Trending Now",
        "type": "products",
        "products": [_product_payload(p) for p in trending],
    })

    # Section 2: Just Dropped — newest products, filtered by preferences
    try:
        newest_query = session.query(Product).filter(Product.is_archived.is_(False))
        if prefs and prefs.preferred_categories:
            newest_query = newest_query.filter(
                Product.category.in_(prefs.preferred_categories)
            )
        if expanded_colors:
            newest_query = newest_query.filter(
                Product.color.in_(expanded_colors)
            )
        newest = newest_query.order_by(Product.id.desc()).offset(offset).limit(limit).all()
        if not newest:
            newest = (
                session.query(Product)
                .filter(Product.is_archived.is_(False))
                .order_by(Product.id.desc())
                .offset(offset)
                .limit(limit)
                .all()
            )
    except Exception as exc:
        logger.warning("Feed newest query failed: %s", exc)
        newest = []
    sections.append({
        "id": "just_dropped",
        "title": "Just Dropped",
        "type": "products",
        "products": [_product_payload(p) for p in newest],
    })

    # Section 3: For You — personalized based on preferences/persona

    for_you_query = session.query(Product).filter(Product.is_archived.is_(False))
    if prefs and prefs.preferred_categories:
        for_you_query = for_you_query.filter(
            Product.category.in_(prefs.preferred_categories)
        )
    if expanded_colors:
        for_you_query = for_you_query.filter(
            Product.color.in_(expanded_colors)
        )
    if prefs and prefs.preferred_brands:
        for_you_query = for_you_query.filter(
            Product.brand.in_(prefs.preferred_brands)
        )
    if prefs and prefs.budget_max:
        for_you_query = for_you_query.filter(
            Product.price <= prefs.budget_max
        )
    if persona and persona.keywords:
        keyword_conditions = [
            json_array_contains(Product.tags, kw)
            for kw in persona.keywords
            if kw
        ]
        if keyword_conditions:
            for_you_query = for_you_query.filter(or_(*keyword_conditions))
    if persona and persona.vibe:
        for_you_query = for_you_query.filter(
            Product.style.contains(persona.vibe)
        )
    # Apply shopping priorities for ranking boost
    try:
        priority_expr = priority_score_expr(prefs.shopping_priorities if prefs else [])
    except Exception as e:
        logger.warning("Failed to compute priority_score_expr in feed: %s", e)
        priority_expr = None
    try:
        if priority_expr is not None:
            for_you = for_you_query.order_by(
                (priority_expr * 0.6 + func.coalesce(Product.rating, 3.0) / 5.0 * 0.4).desc()
            ).offset(offset).limit(limit).all()
        else:
            for_you = for_you_query.order_by(Product.rating.desc().nullslast()).offset(offset).limit(limit).all()
    except Exception as exc:
        logger.warning("Feed for_you query failed: %s", exc)
        for_you = []
    sections.append({
        "id": "for_you",
        "title": "For You",
        "type": "products",
        "products": [_product_payload(p) for p in for_you],
        "reasons": {p.id: _reason_for_item(prefs, p) for p in for_you},
    })

    # Section 4: Social Posts (existing algorithm)
    # NOTE: `func.now() - Post.created_at` is only correct on PostgreSQL
    # (timestamptz arithmetic). On SQLite/TEST mode it compiles to a TEXT
    # subtraction whose operands coerce to 0, and STRFTIME('%s', 0) yields a
    # year -4713 epoch — so `exp(-hours_old/24)` overflows to +inf and the
    # response fails JSON serialization with "Out of range float value: inf".
    # Use explicit unix-epoch arithmetic for a dialect-independent result.
    if session.get_bind().dialect.name == "sqlite":
        hours_old = (
            func.strftime("%s", "now") - func.strftime("%s", Post.created_at)
        ) / 3600.0
    else:
        hours_old = func.extract("epoch", (func.now() - Post.created_at)) / 3600.0
    freshness_expr = func.exp(-1.0 * hours_old / 24.0)

    likes_count = (
        select(func.count(Like.id))
        .where(Like.post_id == Post.id)
        .correlate(Post)
        .scalar_subquery()
    )
    comments_count = (
        select(func.count(Comment.id))
        .where(Comment.post_id == Post.id)
        .correlate(Post)
        .scalar_subquery()
    )

    engagement_expr = (likes_count * 1.0 + comments_count * 0.7)

    blend_expr = case(
        (select(BlendMember.blend_id)
            .where(
                BlendMember.user_firebase_uid == uid,
            )
            .where(
                BlendMember.blend_id.in_(
                    select(BlendMember.blend_id)
                    .where(BlendMember.user_firebase_uid == Post.user_firebase_uid)
                )
            )
            .correlate(Post)
            .exists()
        , 1.0),
        else_=0.0,
    )

    follows_expr = case(
        (select(Follow.id)
            .where(
                Follow.follower_firebase_uid == uid,
                Follow.following_firebase_uid == Post.user_firebase_uid,
            )
            .correlate(Post)
            .exists()
        , 1.0),
        else_=0.0,
    )

    score_expr = (
        follows_expr * 0.30
        + blend_expr * 0.30
        + engagement_expr * 0.30
        + freshness_expr * 0.10
    )

    try:
        cutoff = datetime.now(timezone.utc) - timedelta(days=30)
        stmt = (
            select(
                Post,
                score_expr.label("score"),
                follows_expr.label("follows_weight"),
                blend_expr.label("blend_weight"),
                engagement_expr.label("engagement_weight"),
                freshness_expr.label("freshness_weight"),
            )
            .where(Post.created_at >= cutoff)
            .order_by(desc("score"))
            .offset(offset)
            .limit(limit)
        )
        rows = _safe_query_all(session, stmt)
    except Exception as exc:
        logger.warning("Feed social posts query failed: %s", exc)
        rows = []

    posts: list[dict[str, Any]] = []
    for row in rows:
        try:
            p: Post = row[0]
            posts.append(
                {
                    "id": p.id,
                    "userFirebaseUid": p.user_firebase_uid,
                    "userName": p.user_name,
                    "createdAt": p.created_at.isoformat() if p.created_at else "",
                    "content": p.content,
                    "attachment": p.attachment,
                    "score": float(row[1] or 0),
                    "explanation": {
                        "followsWeight": float(row[2] or 0),
                        "blendWeight": float(row[3] or 0),
                        "engagementWeight": float(row[4] or 0),
                        "freshnessWeight": float(row[5] or 0),
                    },
                }
            )
        except Exception as exc:
            logger.warning("Feed skipping malformed post row: %s", exc)
            continue

    sections.append({
        "id": "social",
        "title": "From the Community",
        "type": "posts",
        "posts": posts,
    })

    return {
        "sections": sections,
        "pagination": {
            "offset": offset,
            "limit": limit,
        },
    }
