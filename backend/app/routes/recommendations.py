"""Personalized recommendation endpoints.

Provides product, outfit, and people recommendations based on user data:

- ``GET /api/recommendations``: Personalized products filtered by user preferences
  (categories, colors) and style persona (keywords, color_palette), ranked by rating.
- ``GET /api/recommendations/discover/swipe``: Products for the swipe-based
  discovery screen, using the same personalization logic.
- ``GET /api/recommend/products``: Simple product list, optionally filtered by category.
- ``GET /api/recommend/people``: Suggested users to follow (newest users).
- ``GET /api/recommend/outfits``: Suggested outfits (newest outfits).

Personalization is progressive: new users with no preferences/persona still get
top-rated products. As users set preferences and their persona is updated, results
become more tailored.
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy import func, or_, case
from sqlalchemy.orm import Session

from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..models import Product, User, Outfit, OutfitItem, WardrobeItem, UserPreference, StylePersona, BlendSwipe, DiscoverySwipe, Wishlist
from ..json_compat import json_array_contains
from ..color_taxonomy import normalize_color, expand_canonical_to_raw
from .priority_scorer import priority_score_expr

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/recommendations", tags=["recommendations"])
recommend_router = APIRouter(prefix="/api/recommend", tags=["recommend"])


def _safe_prefs_rec(session: Session, uid: str) -> tuple:
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


def _expanded_color_filter(session: Session, preferred_colors: list[str]) -> list[str]:
    """Expand canonical preferred colors into all matching raw catalog values."""
    raw_colors = _all_raw_colors(session)
    return expand_canonical_to_raw(preferred_colors, raw_colors)


def _get_swiped_product_ids(session: Session, uid: str) -> set[str]:
    """Return product IDs the user has already swiped on (for feedback loop)."""
    ids: set[str] = set()
    try:
        swipes = session.query(BlendSwipe.product_id).filter(
            BlendSwipe.user_firebase_uid == uid
        ).all()
        ids.update(s[0] for s in swipes)
    except Exception as e:
        logger.warning("Failed to fetch blend swipes for uid %s: %s", uid, e)
    try:
        disc_swipes = session.query(DiscoverySwipe.product_id).filter(
            DiscoverySwipe.user_firebase_uid == uid
        ).all()
        ids.update(s[0] for s in disc_swipes)
    except Exception as e:
        logger.warning("Failed to fetch discovery swipes for uid %s: %s", uid, e)
    return ids


def _signal_vector(session: Session, uid: str) -> dict:
    """Aggregate behavioral feedback into a lightweight preference vector.

    Collects signals from the user's wishlist, discovery swipes and blend
    swipes so future recommendations keep learning after onboarding:

    - ``exclude``: products the user actively disliked (never re-surface).
    - ``styles`` / ``categories`` / ``colors``: attribute counts drawn from
      products the user liked, saved or wishlisted (drives a ranking boost).

    The positive attributes mirror the shape of onboarding preferences so the
    same style/category/color matching logic reuses the proven JSONB patterns.
    """
    exclude: set[str] = set()
    style_counts: dict[str, int] = {}
    category_counts: dict[str, int] = {}
    color_counts: dict[str, int] = {}

    def tally(product: Product) -> None:
        if product is None:
            return
        if product.style:
            style_counts[product.style] = style_counts.get(product.style, 0) + 1
        if product.category:
            category_counts[product.category] = category_counts.get(product.category, 0) + 1
        norm_color = normalize_color(product.color)
        if norm_color:
            color_counts[norm_color] = color_counts.get(norm_color, 0) + 1

    def attrs_for(pid: str) -> Product | None:
        try:
            return session.get(Product, pid)
        except Exception as e:
            logger.warning("Failed to get product attributes for pid %s: %s", pid, e)
            return None

    # Discovery swipes: like/save boost, dislike suppresses.
    try:
        disc = session.query(DiscoverySwipe.product_id, DiscoverySwipe.score).filter(
            DiscoverySwipe.user_firebase_uid == uid
        ).all()
    except Exception as e:
        logger.warning("Failed to query discovery swipes for uid %s: %s", uid, e)
        disc = []
    for pid, score in disc:
        if score < 0:
            exclude.add(pid)
        elif score > 0:
            tally(attrs_for(pid))

    # Blend swipes: like/love boost, dislike suppresses.
    try:
        blends = session.query(BlendSwipe.product_id, BlendSwipe.score).filter(
            BlendSwipe.user_firebase_uid == uid
        ).all()
    except Exception as e:
        logger.warning("Failed to query blend swipes for uid %s: %s", uid, e)
        blends = []
    for pid, score in blends:
        if score < 0:
            exclude.add(pid)
        elif score > 0:
            tally(attrs_for(pid))

    # Wishlist: strongest positive signal.
    try:
        wishlist = session.query(Wishlist.product_id).filter(
            Wishlist.user_firebase_uid == uid
        ).all()
    except Exception as e:
        logger.warning("Failed to query wishlist for uid %s: %s", uid, e)
        wishlist = []
    for (pid,) in wishlist:
        tally(attrs_for(pid))

    def top(counts: dict[str, int], limit: int = 3) -> list[str]:
        return [k for k, _ in sorted(counts.items(), key=lambda kv: kv[1], reverse=True)[:limit]]

    return {
        "exclude": exclude,
        "styles": top(style_counts),
        "categories": top(category_counts),
        "colors": top(color_counts),
    }


def _diversify_results(products: list, limit: int) -> list:
    """Interleave brands and categories so results aren't dominated by one brand."""
    if not products:
        return []

    by_brand: dict[str, list] = {}
    for p in products:
        brand = p.brand or 'Unknown'
        by_brand.setdefault(brand, []).append(p)

    diversified = []
    brand_iters = {k: iter(v) for k, v in by_brand.items()}
    brand_keys = list(brand_iters.keys())
    attempt = 0
    max_rounds = limit * 2

    while len(diversified) < limit and attempt < max_rounds:
        brand = brand_keys[attempt % len(brand_keys)]
        it = brand_iters[brand]
        try:
            diversified.append(next(it))
        except StopIteration:
            attempt += 1
            continue
        attempt += 1

    return diversified[:limit]


def _build_personalized_query(
    session: Session,
    uid: str,
    limit: int = 10,
    include_budget: bool = True,
    diversify: bool = True,
) -> list:
    """Build a personalized product query with filters based on user preferences.

    Uses a progressive fallback strategy: if strict preference filters return
    zero results, progressively relaxes filters to ensure the user always sees
    products. Ranking combines shopping priorities, style-preference match and
    rating.
    """
    prefs, persona = _safe_prefs_rec(session, uid)
    signal = _signal_vector(session, uid)
    swiped_ids = signal["exclude"]

    # Expand canonical color preferences into raw catalog values for SQL matching
    raw_colors = _all_raw_colors(session)
    expanded_pref_colors = (
        expand_canonical_to_raw(prefs.preferred_colors, raw_colors)
        if prefs and prefs.preferred_colors else []
    )
    expanded_signal_colors = (
        expand_canonical_to_raw(signal["colors"], raw_colors)
        if signal["colors"] else []
    )

    def _style_boost_expr():
        styles = (prefs.preferred_styles if prefs and prefs.preferred_styles else [])
        styles = [s for s in styles if s]
        if not styles:
            return None
        style_tag_conditions = [
            json_array_contains(Product.style_tags, s)
            for s in styles
        ]
        return case(
            (
                or_(
                    Product.style.in_(styles),
                    Product.category.in_(styles),
                    *style_tag_conditions,
                ),
                1.0,
            ),
            else_=0.0,
        )

    def _behavior_boost_expr():
        """Boost products that match attributes the user actively liked/saved.

        Continuous learning after onboarding: wishlist, blend likes and
        discovery likes feed a small attribute vector that nudges ranking.
        """
        conds = []
        if signal["categories"]:
            conds.append(Product.category.in_(signal["categories"]))
        if expanded_signal_colors:
            conds.append(Product.color.in_(expanded_signal_colors))
        if signal["styles"]:
            conds.append(Product.style.in_(signal["styles"]))
        if not conds:
            return None
        return case((or_(*conds), 1.0), else_=0.0)

    def _score_and_fetch(q, fetch_limit):
        try:
            priority_expr = priority_score_expr(prefs.shopping_priorities if prefs else [])
        except Exception as e:
            logger.warning("Failed to calculate priority_score_expr: %s", e)
            priority_expr = None
        style_boost = _style_boost_expr()
        behavior_boost = _behavior_boost_expr()

        parts = [func.coalesce(Product.rating, 3.0) / 5.0 * 0.4]
        if priority_expr is not None:
            parts.append(priority_expr * 0.45)
        if style_boost is not None:
            parts.append(style_boost * 0.15)
        if behavior_boost is not None:
            parts.append(behavior_boost * 0.2)
        score = sum(parts)
        return q.order_by(score.desc()).limit(fetch_limit).all()

    def _base_query():
        q = session.query(Product).filter(Product.is_archived.is_(False))
        if swiped_ids:
            q = q.filter(Product.id.notin_(list(swiped_ids)))
        return q

    # Pass 1: all filters (categories + colors + brands + persona keywords)
    query = _base_query()
    if prefs and prefs.preferred_categories:
        query = query.filter(Product.category.in_(prefs.preferred_categories))
    if expanded_pref_colors:
        query = query.filter(Product.color.in_(expanded_pref_colors))
    if prefs and prefs.preferred_brands:
        query = query.filter(Product.brand.in_(prefs.preferred_brands))
    if include_budget and prefs and prefs.budget_max:
        query = query.filter(Product.price <= prefs.budget_max)
    if persona and persona.keywords:
        safe_keywords = [kw for kw in persona.keywords if kw and isinstance(kw, str)]
        if safe_keywords:
            keyword_conditions = [
                json_array_contains(Product.tags, kw)
                for kw in safe_keywords
            ]
            query = query.filter(or_(*keyword_conditions))

    fetch_limit = limit * 3 if diversify else limit
    results = _score_and_fetch(query, fetch_limit)
    if results:
        return _diversify_results(results, limit) if diversify else results[:limit]

    # Pass 2: drop persona keywords, keep category/color/brand
    query = _base_query()
    if prefs and prefs.preferred_categories:
        query = query.filter(Product.category.in_(prefs.preferred_categories))
    if expanded_pref_colors:
        query = query.filter(Product.color.in_(expanded_pref_colors))
    if prefs and prefs.preferred_brands:
        query = query.filter(Product.brand.in_(prefs.preferred_brands))
    if include_budget and prefs and prefs.budget_max:
        query = query.filter(Product.price <= prefs.budget_max)
    results = _score_and_fetch(query, fetch_limit)
    if results:
        return _diversify_results(results, limit) if diversify else results[:limit]

    # Pass 3: drop brands too, keep category + color
    query = _base_query()
    if prefs and prefs.preferred_categories:
        query = query.filter(Product.category.in_(prefs.preferred_categories))
    if expanded_pref_colors:
        query = query.filter(Product.color.in_(expanded_pref_colors))
    results = _score_and_fetch(query, fetch_limit)
    if results:
        return _diversify_results(results, limit) if diversify else results[:limit]

    # Pass 4: category only
    query = _base_query()
    if prefs and prefs.preferred_categories:
        query = query.filter(Product.category.in_(prefs.preferred_categories))
    results = _score_and_fetch(query, fetch_limit)
    if results:
        return _diversify_results(results, limit) if diversify else results[:limit]

    # Pass 5: no preference filters at all — just exclude swiped/archived, order by rating
    query = _base_query()
    if include_budget and prefs and prefs.budget_max:
        query = query.filter(Product.price <= prefs.budget_max)
    results = _score_and_fetch(query, fetch_limit)

    return _diversify_results(results, limit) if diversify else results[:limit]


def _product_reason(prefs, product) -> str:
    """Build a short, human-readable reason explaining why a product was picked.

    Mirrors the plan's example: "Because you like streetwear + neutrals under ₹3000".
    """
    reasons: list[str] = []
    if prefs:
        styles = [s for s in (prefs.preferred_styles or []) if s]
        if styles:
            style_match = next(
                (s for s in styles if s.lower() in ((product.style or '').lower())),
                None,
            )
            if style_match is None and product.style_tags:
                style_match = next(
                    (s for s in styles if s.lower() in [t.lower() for t in (product.style_tags or [])]),
                    None,
                )
            if style_match:
                reasons.append(style_match)
        if prefs.preferred_colors and product.color:
            norm_product_color = normalize_color(product.color)
            color_match = next(
                (c for c in prefs.preferred_colors if norm_product_color and c.lower() == norm_product_color.lower()),
                None,
            )
            if color_match:
                reasons.append(color_match)
        if prefs.budget_max and product.price is not None and product.price <= prefs.budget_max:
            reasons.append(f"under ₹{prefs.budget_max:,}")
    if reasons:
        return "Because you like " + " + ".join(reasons)
    if product.category:
        return f"Because you're browsing {product.category}"
    return "Picked just for you"


def _reason_for_item(prefs, product) -> str:
    try:
        return _product_reason(prefs, product)
    except Exception as e:
        logger.warning("Failed to get product reason: %s", e)
        return "Picked just for you"


@router.get("")
def get_recommendations(
    request: Request, session: Session = Depends(get_session)
) -> dict[str, Any]:
    try:
        decoded = verify_firebase_token(request)
        uid = decoded.get("uid")
        if not uid:
            raise HTTPException(status_code=401, detail="Missing uid claim")
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Recommendations auth error: %s", exc)
        raise HTTPException(status_code=401, detail="Authentication failed")

    products = _build_personalized_query(session, uid, limit=10)
    prefs, _ = _safe_prefs_rec(session, uid)

    items = []
    for product in products:
        try:
            items.append(
                {
                    "type": "product",
                    "reason": _reason_for_item(prefs, product),
                    "data": {
                        "id": product.id,
                        "imageUrl": product.image_url,
                        "brand": product.brand,
                        "name": product.name,
                        "price": product.price,
                        "rating": product.rating,
                        "tags": product.tags,
                    },
                }
            )
        except Exception as exc:
            logger.warning("Recommendations skipping malformed product: %s", exc)
            continue

    return {"items": items}


@router.get("/discover/swipe")
def discover_swipe(
    request: Request,
    limit: int = 20,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    try:
        decoded = verify_firebase_token(request)
        uid = decoded.get("uid")
        if not uid:
            raise HTTPException(status_code=401, detail="Missing uid claim")
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("discover_swipe auth error: %s", exc)
        raise HTTPException(status_code=401, detail="Authentication failed")

    products = _build_personalized_query(session, uid, limit=limit, include_budget=False)

    return {
        "products": [
            {
                "id": p.id,
                "name": p.name,
                "imageUrl": p.image_url,
                "brand": p.brand,
                "price": p.price,
                "rating": p.rating,
                "category": p.category,
                "tags": p.tags,
            }
            for p in products
        ],
    }


# ── /api/recommend/* endpoints (used by Flutter) ─────────────────────────

@recommend_router.get("/people")
def recommend_people(
    request: Request,
    limit: int = 10,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    try:
        decoded = verify_firebase_token(request)
        current_uid = decoded.get("uid")
        if not current_uid:
            raise HTTPException(status_code=401, detail="Missing uid claim")
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("recommend_people auth error: %s", exc)
        raise HTTPException(status_code=401, detail="Authentication failed")

    query = session.query(User).filter(User.firebase_uid != current_uid)

    users = query.order_by(User.id.desc()).limit(limit).all()
    return {
        "people": [
            {
                "id": u.id,
                "firebaseUid": u.firebase_uid,
                "name": u.name,
                "avatarUrl": u.avatar_url or "",
            }
            for u in users
        ]
    }


@recommend_router.get("/outfits")
def recommend_outfits(
    request: Request,
    limit: int = 6,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    try:
        decoded = verify_firebase_token(request)
        current_uid = decoded.get("uid")
        if not current_uid:
            raise HTTPException(status_code=401, detail="Missing uid claim")
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("recommend_outfits auth error: %s", exc)
        raise HTTPException(status_code=401, detail="Authentication failed")

    query = session.query(Outfit).filter(Outfit.user_firebase_uid == current_uid)
    outfits = query.order_by(Outfit.created_at.desc()).limit(limit).all()

    result = []
    for o in outfits:
        outfit_data: dict[str, Any] = {
            "id": o.id,
            "name": o.name,
            "occasion": o.occasion,
        }
        try:
            items = (
                session.query(OutfitItem)
                .filter(OutfitItem.outfit_id == o.id)
                .limit(4)
                .all()
            )
            if items:
                wardrobe_ids = [i.wardrobe_item_id for i in items if i.wardrobe_item_id]
                if wardrobe_ids:
                    wi = session.query(WardrobeItem).filter(
                        WardrobeItem.id.in_(wardrobe_ids)
                    ).first()
                    if wi and wi.image_url:
                        outfit_data["imageUrl"] = wi.image_url
        except Exception as e:
            logger.warning("Failed to fetch outfit items for outfit %s: %s", o.id, e)
        result.append(outfit_data)

    return {"outfits": result}


@recommend_router.get("/products")
def recommend_products(
    request: Request,
    limit: int = 12,
    category: str | None = None,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    verify_firebase_token(request)
    query = session.query(Product).filter(Product.is_archived.is_(False))
    if category:
        query = query.filter(Product.category == category)
    products = query.order_by(Product.rating.desc().nullslast()).limit(limit).all()
    return {
        "products": [
            {
                "id": p.id,
                "name": p.name,
                "imageUrl": p.image_url,
                "brand": p.brand,
                "price": p.price,
                "rating": p.rating,
                "category": p.category,
            }
            for p in products
        ]
    }


# ── Discovery swipe recording ──────────────────────────────────────────────

class _DiscoverSwipeRequest(BaseModel):
    productId: str
    swipeType: str = "like"

@router.post("/discover/swipe")
def record_discover_swipe(
    body: _DiscoverSwipeRequest,
    request: Request,
    session: Session = Depends(get_session),
) -> dict[str, str]:
    """Record a like/dislike/save swipe from the discovery feed."""
    try:
        decoded = verify_firebase_token(request)
        uid = decoded.get("uid")
        if not uid:
            raise HTTPException(status_code=401, detail="Missing uid claim")
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("record_discover_swipe auth error: %s", exc)
        raise HTTPException(status_code=401, detail="Authentication failed")

    score_map = {"like": 1, "dislike": -1, "save": 2}
    score = score_map.get(body.swipeType, 0)

    existing = session.query(DiscoverySwipe).filter(
        DiscoverySwipe.user_firebase_uid == uid,
        DiscoverySwipe.product_id == body.productId,
    ).first()

    if existing:
        existing.score = score
    else:
        session.add(DiscoverySwipe(
            user_firebase_uid=uid,
            product_id=body.productId,
            score=score,
        ))

    session.commit()
    return {"status": "ok"}

@router.get("/evaluation-status")
def recommendation_evaluation_status() -> dict:
    """Ops endpoint for offline ranking evaluation."""
    return {
        "status": "ok",
        "strategy": "preferences + style_persona + priority_scorer + behavior signals",
        "offline_eval_script": "backend/scripts/evaluate_recommendations.py",
        "metrics_supported": ["precision_at_k", "category_coverage", "diversity"],
        "notes": "Run the offline script in CI/nightly for quantitative ranking quality.",
    }

