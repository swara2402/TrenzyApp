from __future__ import annotations

import logging
from collections import Counter
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy import desc, func
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

from ..auth_helpers import require_blend_member_sync, require_blend_owner_sync, raise_forbidden, raise_not_found
from ..blend_helpers import compute_blend_results
from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..models import (
    ActivityEvent,
    Blend,
    BlendMember,
    BlendSwipe,
    Product,
)
from ..models_blend_features import BlendInsight, MoodboardItem, SharedWishlistItem

router = APIRouter(prefix="/api/blends", tags=["blend_features"])

# Only regenerate insights if the most recent batch is older than this.
_INSIGHT_REFRESH_WINDOW = timedelta(minutes=5)


def _get_uid(decoded: dict[str, Any]) -> str:
    firebase_uid = decoded.get("uid")
    if not firebase_uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")
    return firebase_uid


def _verify_member(session: Session, blend_id: str, firebase_uid: str) -> Blend:
    """Verify user is a member of the blend using centralized auth helper."""
    blend = session.query(Blend).filter(Blend.id == blend_id).first()
    if not blend:
        raise_not_found("Blend not found")
    
    # Use centralized auth helper for consistency
    if not require_blend_member_sync(firebase_uid, blend_id, session):
        raise_forbidden("You must be a member of this blend")
    
    return blend


# ──────────────────────────────────────────────
#  COMPREHENSIVE BLEND DASHBOARD
# ──────────────────────────────────────────────

@router.get("/{blend_id}/dashboard")
def get_blend_dashboard(
    blend_id: str,
    request: Request,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)
    blend = _verify_member(session, blend_id, firebase_uid)

    members = (
        session.query(BlendMember)
        .filter(BlendMember.blend_id == blend_id)
        .all()
    )

    results = compute_blend_results(session, blend_id)

    wishlist_items = (
        session.query(SharedWishlistItem)
        .filter(SharedWishlistItem.blend_id == blend_id)
        .order_by(desc(SharedWishlistItem.created_at))
        .limit(20)
        .all()
    )

    moodboard_items = (
        session.query(MoodboardItem)
        .filter(MoodboardItem.blend_id == blend_id)
        .order_by(desc(MoodboardItem.created_at))
        .limit(20)
        .all()
    )

    insights = (
        session.query(BlendInsight)
        .filter(BlendInsight.blend_id == blend_id)
        .order_by(desc(BlendInsight.created_at))
        .limit(5)
        .all()
    )

    recent_activity = (
        session.query(ActivityEvent)
        .filter(
            ActivityEvent.target_id == blend_id,
            ActivityEvent.target_type == "blend",
        )
        .order_by(desc(ActivityEvent.created_at))
        .limit(20)
        .all()
    )

    total_swipes = (
        session.query(func.count(BlendSwipe.id))
        .filter(BlendSwipe.blend_id == blend_id)
        .scalar()
        or 0
    )

    total_wishlist = (
        session.query(func.count(SharedWishlistItem.id))
        .filter(SharedWishlistItem.blend_id == blend_id)
        .scalar()
        or 0
    )

    total_moodboard = (
        session.query(func.count(MoodboardItem.id))
        .filter(MoodboardItem.blend_id == blend_id)
        .scalar()
        or 0
    )

    style_dna = _build_style_dna(session, blend_id)

    return {
        "id": blend.id,
        "name": blend.name,
        "description": blend.description,
        "inviteCode": blend.invite_code or "",
        "createdAt": blend.created_at.isoformat() if blend.created_at else None,
        "memberCount": len(members),
        "members": [
            {
                "userId": m.user_firebase_uid,
                "userName": m.user_name,
                "joinedAt": m.joined_at.isoformat() if m.joined_at else None,
            }
            for m in members
        ],
        "fashionScore": results["fashionScore"],
        "compatibilityLevel": results["compatibilityLevel"],
        "sharedBrands": results["sharedBrands"],
        "sharedCategories": results["sharedCategories"],
        "sharedColours": results["sharedColours"],
        "sharedStyles": results["sharedStyles"],
        "wardrobeOverlap": results["wardrobeOverlap"],
        "totalSwipes": total_swipes,
        "totalWishlistItems": total_wishlist,
        "totalMoodboardItems": total_moodboard,
        "styleDNA": style_dna,
        "wishlistItems": [
            {
                "id": item.id,
                "productId": item.product_id,
                "productName": item.product_name,
                "productPrice": item.product_price,
                "productImage": item.product_image,
                "productBrand": item.product_brand,
                "productCategory": item.product_category,
                "productUrl": item.product_url,
                "addedByUid": item.added_by_uid,
                "addedByName": item.added_by_name,
                "notes": item.notes,
                "isFavorite": item.is_favorite,
                "purchaseLink": item.purchase_link,
                "createdAt": item.created_at.isoformat() if item.created_at else None,
            }
            for item in wishlist_items
        ],
        "moodboardItems": [
            {
                "id": item.id,
                "itemType": item.item_type,
                "content": item.content,
                "imageUrl": item.image_url,
                "caption": item.caption,
                "addedByUid": item.added_by_uid,
                "addedByName": item.added_by_name,
                "createdAt": item.created_at.isoformat() if item.created_at else None,
            }
            for item in moodboard_items
        ],
        "insights": [
            {
                "id": ins.id,
                "insightType": ins.insight_type,
                "title": ins.title,
                "description": ins.description,
                "confidence": ins.confidence,
                "category": ins.category,
                "createdAt": ins.created_at.isoformat() if ins.created_at else None,
            }
            for ins in insights
        ],
        "recentActivity": [
            {
                "id": act.id,
                "kind": act.kind,
                "description": act.description,
                "userId": act.user_firebase_uid,
                "createdAt": act.created_at.isoformat() if act.created_at else None,
            }
            for act in recent_activity
        ],
    }


def _build_style_dna(session: Session, blend_id: str) -> dict[str, Any]:
    swipes = (
        session.query(BlendSwipe)
        .filter(BlendSwipe.blend_id == blend_id, BlendSwipe.score >= 1)
        .all()
    )
    if not swipes:
        return {
            "colors": [],
            "brands": [],
            "fits": [],
            "categories": [],
            "aesthetics": [],
            "occasions": [],
        }

    product_ids = list({s.product_id for s in swipes})
    products = (
        session.query(Product)
        .filter(Product.id.in_(product_ids))
        .all()
    )

    color_counter: Counter[str] = Counter()
    brand_counter: Counter[str] = Counter()
    category_counter: Counter[str] = Counter()
    style_counter: Counter[str] = Counter()
    occasion_counter: Counter[str] = Counter()
    fit_counter: Counter[str] = Counter()
    aesthetic_counter: Counter[str] = Counter()
    season_counter: Counter[str] = Counter()

    for p in products:
        if p.color:
            color_counter[p.color] += 1
        if p.brand:
            brand_counter[p.brand] += 1
        if p.category:
            category_counter[p.category] += 1
        if p.style:
            style_counter[p.style] += 1
        if p.occasion:
            occasion_counter[p.occasion] += 1
        if p.fit:
            fit_counter[p.fit] += 1
        if p.usage:
            aesthetic_counter[p.usage] += 1
        if p.season:
            season_counter[p.season] += 1

        tags = p.tags or []
        if isinstance(tags, list):
            for tag in tags:
                tag_str = str(tag).lower()
                if tag_str in {"minimal", "streetwear", "classic", "bohemian", "edgy", "preppy", "athleisure", "vintage", "avant-garde"}:
                    aesthetic_counter[tag_str] += 1

    total = sum(color_counter.values()) or 1

    def _to_pct_list(counter: Counter, limit: int = 8) -> list[dict]:
        items = counter.most_common(limit)
        return [
            {"name": name, "confidence": round(count / total * 100, 1)}
            for name, count in items
        ]

    return {
        "colors": _to_pct_list(color_counter),
        "brands": _to_pct_list(brand_counter),
        "fits": _to_pct_list(fit_counter),
        "categories": _to_pct_list(category_counter),
        "aesthetics": _to_pct_list(aesthetic_counter),
        "occasions": _to_pct_list(occasion_counter),
    }


# ──────────────────────────────────────────────
#  SHARED WISHLIST
# ──────────────────────────────────────────────

class AddWishlistItemRequest(BaseModel):
    productId: str
    productName: str = ""
    productPrice: Optional[float] = None
    productImage: Optional[str] = None
    productBrand: Optional[str] = None
    productCategory: Optional[str] = None
    productUrl: Optional[str] = None
    notes: Optional[str] = None


class UpdateWishlistItemRequest(BaseModel):
    notes: Optional[str] = None
    isFavorite: Optional[bool] = None
    purchaseLink: Optional[str] = None


@router.get("/{blend_id}/wishlist")
def get_shared_wishlist(
    blend_id: str,
    request: Request,
    session: Session = Depends(get_session),
    sort: str = "newest",
    category: Optional[str] = None,
    search: Optional[str] = None,
) -> list[dict[str, Any]]:
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)
    _verify_member(session, blend_id, firebase_uid)

    query = session.query(SharedWishlistItem).filter(
        SharedWishlistItem.blend_id == blend_id
    )

    if category:
        query = query.filter(SharedWishlistItem.product_category == category)
    if search:
        query = query.filter(
            SharedWishlistItem.product_name.ilike(f"%{search}%")
        )

    if sort == "oldest":
        query = query.order_by(SharedWishlistItem.created_at.asc())
    elif sort == "price_high":
        query = query.order_by(desc(SharedWishlistItem.product_price))
    elif sort == "price_low":
        query = query.order_by(SharedWishlistItem.product_price.asc())
    elif sort == "favorites":
        query = query.order_by(
            desc(SharedWishlistItem.is_favorite),
            desc(SharedWishlistItem.created_at),
        )
    else:
        query = query.order_by(desc(SharedWishlistItem.created_at))

    items = query.all()
    return [
        {
            "id": item.id,
            "productId": item.product_id,
            "productName": item.product_name,
            "productPrice": item.product_price,
            "productImage": item.product_image,
            "productBrand": item.product_brand,
            "productCategory": item.product_category,
            "productUrl": item.product_url,
            "addedByUid": item.added_by_uid,
            "addedByName": item.added_by_name,
            "notes": item.notes,
            "isFavorite": item.is_favorite,
            "purchaseLink": item.purchase_link,
            "createdAt": item.created_at.isoformat() if item.created_at else None,
        }
        for item in items
    ]


@router.post("/{blend_id}/wishlist")
def add_to_shared_wishlist(
    blend_id: str,
    payload: AddWishlistItemRequest,
    request: Request,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)
    _verify_member(session, blend_id, firebase_uid)

    existing = session.query(SharedWishlistItem).filter(
        SharedWishlistItem.blend_id == blend_id,
        SharedWishlistItem.product_id == payload.productId,
    ).first()
    if existing:
        return {
            "id": existing.id,
            "status": "already_exists",
            "message": "Item already in shared wishlist",
        }

    decoded_name = decoded.get("name") or decoded.get("email", "").split("@")[0] or "Member"

    item = SharedWishlistItem(
        blend_id=blend_id,
        product_id=payload.productId,
        product_name=payload.productName,
        product_price=payload.productPrice,
        product_image=payload.productImage,
        product_brand=payload.productBrand,
        product_category=payload.productCategory,
        product_url=payload.productUrl,
        added_by_uid=firebase_uid,
        added_by_name=decoded_name,
        notes=payload.notes,
    )
    session.add(item)
    session.commit()
    session.refresh(item)

    _record_activity(
        session, firebase_uid,
        kind="wishlist_added",
        description=f"{decoded_name} added {payload.productName or 'a product'} to the shared wishlist",
        target_id=blend_id,
        target_type="blend",
    )

    return {
        "id": item.id,
        "status": "added",
        "productId": item.product_id,
        "productName": item.product_name,
    }


@router.patch("/{blend_id}/wishlist/{item_id}")
def update_wishlist_item(
    blend_id: str,
    item_id: int,
    payload: UpdateWishlistItemRequest,
    request: Request,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)
    _verify_member(session, blend_id, firebase_uid)

    item = session.query(SharedWishlistItem).filter(
        SharedWishlistItem.id == item_id,
        SharedWishlistItem.blend_id == blend_id,
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Wishlist item not found")

    if payload.notes is not None:
        item.notes = payload.notes
    if payload.isFavorite is not None:
        item.is_favorite = payload.isFavorite
    if payload.purchaseLink is not None:
        item.purchase_link = payload.purchaseLink

    session.commit()
    return {"status": "updated", "id": item.id}


@router.delete("/{blend_id}/wishlist/{item_id}")
def remove_from_shared_wishlist(
    blend_id: str,
    item_id: int,
    request: Request,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)
    _verify_member(session, blend_id, firebase_uid)

    item = session.query(SharedWishlistItem).filter(
        SharedWishlistItem.id == item_id,
        SharedWishlistItem.blend_id == blend_id,
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Wishlist item not found")

    session.delete(item)
    session.commit()
    return {"status": "removed"}


# ──────────────────────────────────────────────
#  MOODBOARD
# ──────────────────────────────────────────────

class AddMoodboardItemRequest(BaseModel):
    itemType: str = "product"
    content: Optional[dict] = None
    imageUrl: Optional[str] = None
    caption: Optional[str] = None


@router.get("/{blend_id}/moodboard")
def get_moodboard(
    blend_id: str,
    request: Request,
    session: Session = Depends(get_session),
    item_type: Optional[str] = None,
) -> list[dict[str, Any]]:
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)
    _verify_member(session, blend_id, firebase_uid)

    query = session.query(MoodboardItem).filter(
        MoodboardItem.blend_id == blend_id
    )
    if item_type:
        query = query.filter(MoodboardItem.item_type == item_type)
    query = query.order_by(MoodboardItem.sort_order.asc(), desc(MoodboardItem.created_at))

    items = query.all()
    return [
        {
            "id": item.id,
            "itemType": item.item_type,
            "content": item.content,
            "imageUrl": item.image_url,
            "caption": item.caption,
            "addedByUid": item.added_by_uid,
            "addedByName": item.added_by_name,
            "createdAt": item.created_at.isoformat() if item.created_at else None,
        }
        for item in items
    ]


@router.post("/{blend_id}/moodboard")
def add_to_moodboard(
    blend_id: str,
    payload: AddMoodboardItemRequest,
    request: Request,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)
    _verify_member(session, blend_id, firebase_uid)

    decoded_name = decoded.get("name") or decoded.get("email", "").split("@")[0] or "Member"

    max_order = (
        session.query(func.max(MoodboardItem.sort_order))
        .filter(MoodboardItem.blend_id == blend_id)
        .scalar()
    ) or 0

    item = MoodboardItem(
        blend_id=blend_id,
        item_type=payload.itemType,
        content=payload.content,
        image_url=payload.imageUrl,
        caption=payload.caption,
        added_by_uid=firebase_uid,
        added_by_name=decoded_name,
        sort_order=max_order + 1,
    )
    session.add(item)
    session.commit()
    session.refresh(item)

    _record_activity(
        session, firebase_uid,
        kind="moodboard_added",
        description=f"{decoded_name} added to the moodboard",
        target_id=blend_id,
        target_type="blend",
    )

    return {
        "id": item.id,
        "status": "added",
    }


@router.delete("/{blend_id}/moodboard/{item_id}")
def remove_from_moodboard(
    blend_id: str,
    item_id: int,
    request: Request,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)
    _verify_member(session, blend_id, firebase_uid)

    item = session.query(MoodboardItem).filter(
        MoodboardItem.id == item_id,
        MoodboardItem.blend_id == blend_id,
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Moodboard item not found")

    session.delete(item)
    session.commit()
    return {"status": "removed"}


# ──────────────────────────────────────────────
#  AI INSIGHTS
# ──────────────────────────────────────────────

@router.get("/{blend_id}/insights")
def get_blend_insights(
    blend_id: str,
    request: Request,
    session: Session = Depends(get_session),
    refresh: bool = False,
) -> list[dict[str, Any]]:
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)
    _verify_member(session, blend_id, firebase_uid)

    if refresh:
        _generate_insights(session, blend_id)

    insights = (
        session.query(BlendInsight)
        .filter(BlendInsight.blend_id == blend_id)
        .order_by(desc(BlendInsight.confidence), desc(BlendInsight.created_at))
        .limit(10)
        .all()
    )

    return [
        {
            "id": ins.id,
            "insightType": ins.insight_type,
            "title": ins.title,
            "description": ins.description,
            "confidence": ins.confidence,
            "category": ins.category,
            "metadataJson": ins.metadata_json,
            "createdAt": ins.created_at.isoformat() if ins.created_at else None,
        }
        for ins in insights
    ]


@router.post("/{blend_id}/insights/refresh")
def refresh_insights(
    blend_id: str,
    request: Request,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)
    _verify_member(session, blend_id, firebase_uid)

    generated = _generate_insights(session, blend_id, force=True)
    return {"status": "refreshed", "count": generated}


def _generate_insights(session: Session, blend_id: str, force: bool = False) -> int:
    if not force:
        # Throttle: don't regenerate if insights were created recently.
        recent = session.query(BlendInsight).filter(
            BlendInsight.blend_id == blend_id,
            BlendInsight.created_at > datetime.now(timezone.utc) - _INSIGHT_REFRESH_WINDOW,
        ).first()
        if recent:
            return 0

    session.query(BlendInsight).filter(BlendInsight.blend_id == blend_id).delete()

    swipes = (
        session.query(BlendSwipe)
        .filter(BlendSwipe.blend_id == blend_id)
        .all()
    )
    if not swipes:
        return 0

    liked_product_ids = list({s.product_id for s in swipes if s.score >= 1})

    liked_products = (
        session.query(Product)
        .filter(Product.id.in_(liked_product_ids))
        .all()
    ) if liked_product_ids else []

    members = (
        session.query(BlendMember)
        .filter(BlendMember.blend_id == blend_id)
        .all()
    )
    member_count = len(members)

    insights: list[dict[str, Any]] = []

    color_counter: Counter[str] = Counter()
    brand_counter: Counter[str] = Counter()
    category_counter: Counter[str] = Counter()
    style_counter: Counter[str] = Counter()
    occasion_counter: Counter[str] = Counter()
    fit_counter: Counter[str] = Counter()
    season_counter: Counter[str] = Counter()

    for p in liked_products:
        if p.color:
            color_counter[p.color] += 1
        if p.brand:
            brand_counter[p.brand] += 1
        if p.category:
            category_counter[p.category] += 1
        if p.style:
            style_counter[p.style] += 1
        if p.occasion:
            occasion_counter[p.occasion] += 1
        if p.fit:
            fit_counter[p.fit] += 1
        if p.season:
            season_counter[p.season] += 1

    total_liked = len(liked_products) or 1

    # Color insight
    if color_counter:
        top_color = color_counter.most_common(1)[0]
        top_color_pct = round(top_color[1] / total_liked * 100)
        if top_color_pct >= 40:
            insights.append({
                "insight_type": "color_preference",
                "title": f"You both prefer {top_color[0].lower()} tones",
                "description": f"{top_color_pct}% of your liked products feature {top_color[0].lower()} colors. This is a strong shared aesthetic signal.",
                "confidence": round(top_color_pct / 100, 2),
                "category": "colors",
            })
        if len(color_counter) >= 3:
            top_colors = [c for c, _ in color_counter.most_common(3)]
            insights.append({
                "insight_type": "color_palette",
                "title": "Your shared palette is emerging",
                "description": f"Your group gravitates toward {', '.join(top_colors)}. These colors define your collective style.",
                "confidence": 0.75,
                "category": "colors",
            })

    # Brand insight
    if brand_counter:
        top_brand = brand_counter.most_common(1)[0]
        top_brand_pct = round(top_brand[1] / total_liked * 100)
        if top_brand_pct >= 30:
            insights.append({
                "insight_type": "brand_affinity",
                "title": f"{top_brand[0]} is a group favorite",
                "description": f"{top_brand_pct}% of your liked items are from {top_brand[0]}. Strong brand alignment!",
                "confidence": round(top_brand_pct / 100, 2),
                "category": "brands",
            })

    # Category insight
    if category_counter:
        top_cat = category_counter.most_common(1)[0]
        insights.append({
            "insight_type": "category_preference",
            "title": f"You lean toward {top_cat[0].lower()}",
            "description": f"{top_cat[0]} is the most-liked category in your group. Consider exploring more options in this category.",
            "confidence": 0.7,
            "category": "categories",
        })

        all_categories = set(category_counter.keys())
        formal_cats = {"formal", "blazer", "suit", "tie", "dress_shirt", "heels", "loafers"}
        casual_cats = {"t-shirt", "jeans", "sneakers", "hoodie", "shorts", "casual"}
        formal_overlap = all_categories & formal_cats
        casual_overlap = all_categories & casual_cats

        if not formal_overlap and casual_overlap:
            insights.append({
                "insight_type": "occasion_gap",
                "title": "Try adding more formal options",
                "description": "Your group hasn't liked any formal wear yet. Adding formal pieces could expand your shared wardrobe.",
                "confidence": 0.6,
                "category": "occasions",
            })
        elif formal_overlap and not casual_overlap:
            insights.append({
                "insight_type": "occasion_gap",
                "title": "Consider casual pieces too",
                "description": "Your group focuses on formal wear. Adding casual options would balance your shared style.",
                "confidence": 0.6,
                "category": "occasions",
            })

    # Fit insight
    if fit_counter:
        top_fit = fit_counter.most_common(1)[0]
        insights.append({
            "insight_type": "fit_preference",
            "title": f"Your group prefers {top_fit[0].lower()} fits",
            "description": f"{top_fit[0]} is the most common fit in your liked products. This defines your shared silhouette preference.",
            "confidence": 0.65,
            "category": "fits",
        })

    # Season insight
    if season_counter:
        top_season = season_counter.most_common(1)[0]
        insights.append({
            "insight_type": "seasonal_trend",
            "title": f"Seasonal alignment: {top_season[0]}",
            "description": f"Your group is most engaged with {top_season[0].lower()} styles. Great for planning ahead.",
            "confidence": 0.6,
            "category": "seasons",
        })

    # Diversity insight
    if len(set(s.product_id for s in swipes)) >= 10 and member_count >= 2:
        agree_count = 0
        total_paired = 0
        for pid in set(s.product_id for s in swipes):
            member_scores = {}
            for s in swipes:
                if s.product_id == pid:
                    member_scores[s.user_firebase_uid] = s.score
            if len(member_scores) >= 2:
                total_paired += 1
                scores_list = list(member_scores.values())
                if all(s >= 1 for s in scores_list) or all(s < 0 for s in scores_list):
                    agree_count += 1

        if total_paired > 0:
            agreement = round(agree_count / total_paired * 100)
            insights.append({
                "insight_type": "agreement",
                "title": f"Your group agrees {agreement}% of the time",
                "description": f"Out of {total_paired} products everyone swiped on, you agreed on {agree_count}. {'Excellent taste alignment!' if agreement >= 70 else 'Healthy debate keeps things interesting!' if agreement >= 40 else 'You have very different tastes — try exploring new categories together.'}",
                "confidence": round(agreement / 100, 2),
                "category": "compatibility",
            })

    # Style insight
    if style_counter:
        top_style = style_counter.most_common(1)[0]
        insights.append({
            "insight_type": "style_identity",
            "title": f"Your shared style: {top_style[0]}",
            "description": f"{top_style[0]} is the dominant aesthetic in your blend. This is your collective fashion identity.",
            "confidence": 0.7,
            "category": "styles",
        })

    # Occasion insight
    if occasion_counter:
        top_occasion = occasion_counter.most_common(3)
        occasions_str = ", ".join(o for o, _ in top_occasion)
        insights.append({
            "insight_type": "occasion_focus",
            "title": f"Shopping for {top_occasion[0][0].lower() if top_occasion else 'everyday'} looks",
            "description": f"Your liked products are mostly for {occasions_str}. You're building a wardrobe for these occasions.",
            "confidence": 0.65,
            "category": "occasions",
        })

    # Member insight
    uids_with_swipes = set(s.user_firebase_uid for s in swipes)
    active_count = len(uids_with_swipes)
    if active_count < member_count:
        inactive_names = [
            m.user_name for m in members
            if m.user_firebase_uid not in uids_with_swipes
        ]
        if inactive_names:
            insights.append({
                "insight_type": "engagement",
                "title": f"{len(inactive_names)} member{'s' if len(inactive_names) > 1 else ''} haven't swiped yet",
                "description": f"{', '.join(inactive_names)} {'haven' if len(inactive_names) > 1 else 'hasn'}t voted yet. Remind them to join the fun for better recommendations!",
                "confidence": 1.0,
                "category": "engagement",
            })

    # Diversity insight
    if len(category_counter) >= 4:
        insights.append({
            "insight_type": "diversity",
            "title": "Your tastes are diverse",
            "description": f"Your group likes products across {len(category_counter)} different categories. This broad range makes your blend exciting!",
            "confidence": 0.8,
            "category": "categories",
        })

    # Budget insight
    prices = [p.price for p in liked_products if p.price is not None]
    if prices:
        avg_price = sum(prices) / len(prices)
        if avg_price < 50:
            budget_label = "budget-friendly"
        elif avg_price < 150:
            budget_label = "mid-range"
        elif avg_price < 500:
            budget_label = "premium"
        else:
            budget_label = "luxury"

        insights.append({
            "insight_type": "budget",
            "title": f"Your group shops {budget_label}",
            "description": f"Average liked product price is ₹{avg_price:.0f}. You're in the {budget_label} segment.",
            "confidence": 0.75,
            "category": "budget",
        })

    for ins_data in insights:
        insight = BlendInsight(
            blend_id=blend_id,
            insight_type=ins_data["insight_type"],
            title=ins_data["title"],
            description=ins_data["description"],
            confidence=ins_data["confidence"],
            category=ins_data.get("category"),
        )
        session.add(insight)

    session.commit()
    return len(insights)


# ──────────────────────────────────────────────
#  BLEND SETTINGS
# ──────────────────────────────────────────────

class UpdateBlendSettingsRequest(BaseModel):
    name: Optional[str] = Field(default=None, max_length=80)
    description: Optional[str] = Field(default=None, max_length=500)
    coverImage: Optional[str] = Field(default=None, max_length=500)
    isPrivate: Optional[bool] = None


@router.patch("/{blend_id}/settings")
def update_blend_settings(
    blend_id: str,
    payload: UpdateBlendSettingsRequest,
    request: Request,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)
    
    # P0 AUTHZ: Only the blend owner (creator) can modify settings.
    # This includes name, description, cover image, and privacy status.
    # Non-owners should use the GET endpoint to view settings.
    if not require_blend_owner_sync(firebase_uid, blend_id, session):
        raise_forbidden("Only the blend owner can update settings")
    
    blend = session.query(Blend).filter(Blend.id == blend_id).first()
    if not blend:
        raise_not_found("Blend not found")

    if payload.name is not None:
        blend.name = payload.name.strip()
    if payload.description is not None:
        blend.description = payload.description.strip() if payload.description else None
    if payload.coverImage is not None:
        blend.cover_image = payload.coverImage
    if payload.isPrivate is not None:
        blend.is_private = payload.isPrivate

    session.commit()

    _record_activity(
        session, firebase_uid,
        kind="blend_updated",
        description=f"Blend settings updated by {decoded.get('name', 'owner')}",
        target_id=blend_id,
        target_type="blend",
    )

    return {"status": "updated"}


@router.get("/{blend_id}/settings")
def get_blend_settings(
    blend_id: str,
    request: Request,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)
    _verify_member(session, blend_id, firebase_uid)

    blend = session.query(Blend).filter(Blend.id == blend_id).first()
    if not blend:
        raise HTTPException(status_code=404, detail="Blend not found")

    return {
        "id": blend.id,
        "name": blend.name,
        "description": blend.description,
        "coverImage": getattr(blend, "cover_image", None),
        "isPrivate": getattr(blend, "is_private", False),
        "createdAt": blend.created_at.isoformat() if blend.created_at else None,
    }


# ──────────────────────────────────────────────
#  BLEND ACTIVITY
# ──────────────────────────────────────────────

@router.get("/{blend_id}/activity")
def get_blend_activity(
    blend_id: str,
    request: Request,
    session: Session = Depends(get_session),
    limit: int = 50,
    offset: int = 0,
) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = _get_uid(decoded)
    _verify_member(session, blend_id, firebase_uid)

    query = session.query(ActivityEvent).filter(
        ActivityEvent.target_id == blend_id,
        ActivityEvent.target_type == "blend",
    )

    total = query.count()

    events = (
        query.order_by(desc(ActivityEvent.created_at))
        .offset(offset)
        .limit(limit)
        .all()
    )

    return {
        "total": total,
        "offset": offset,
        "limit": limit,
        "events": [
            {
                "id": event.id,
                "kind": event.kind,
                "description": event.description,
                "userId": event.user_firebase_uid,
                "targetId": event.target_id,
                "targetType": event.target_type,
                "metadataJson": event.metadata_json,
                "createdAt": event.created_at.isoformat() if event.created_at else None,
            }
            for event in events
        ],
    }


# ──────────────────────────────────────────────
#  HELPER
# ──────────────────────────────────────────────

def _record_activity(
    session: Session,
    user_firebase_uid: str,
    kind: str,
    description: str,
    target_id: str | None = None,
    target_type: str | None = None,
    metadata_json: dict | None = None,
) -> None:
    event = ActivityEvent(
        user_firebase_uid=user_firebase_uid,
        kind=kind,
        description=description,
        target_id=target_id,
        target_type=target_type,
        metadata_json=metadata_json,
    )
    session.add(event)
    session.commit()
