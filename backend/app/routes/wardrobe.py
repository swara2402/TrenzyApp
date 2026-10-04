"""Personal wardrobe and outfit management endpoints.

Lets users manage their personal clothing collection and create outfits:

- **Wardrobe items**: CRUD for clothing items the user owns (name, image,
  category, color, season, brand, favorite flag).
- **Outfits**: Named collections of wardrobe items, optionally tagged with
  an occasion. Outfit items reference wardrobe items via OutfitItem join table.
- **Wardrobe recommendations**: Gap analysis, AI outfit ideas from owned items,
  and catalog suggestions to fill wardrobe gaps.

The wardrobe is separate from the product catalog — it represents what the
user actually owns, not what's available to buy.
"""

import logging
from typing import Optional
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import select, delete, func
from sqlalchemy.orm import Session

from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..models import WardrobeItem, Outfit, OutfitItem, UserPreference
from .recommendations import _build_personalized_query, _product_reason


class AddWardrobeItemRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    image_url: Optional[str] = Field(None, max_length=2048)
    category: Optional[str] = Field(None, max_length=50)
    color: Optional[str] = Field(None, max_length=50)
    season: Optional[str] = Field(None, max_length=50)
    brand: Optional[str] = Field(None, max_length=100)

    @field_validator("name", mode="before")
    @classmethod
    def validate_name(cls, v):
        if not v or not str(v).strip():
            raise ValueError("Name cannot be empty or whitespace only")
        return str(v).strip()

    @field_validator("image_url", mode="before")
    @classmethod
    def validate_image_url(cls, v):
        if v is not None and str(v).strip():
            url_str = str(v).strip()
            if not (url_str.startswith("http://") or url_str.startswith("https://")):
                raise ValueError("Image URL must start with http:// or https://")
            if len(url_str) > 2048:
                raise ValueError("Image URL exceeds max length of 2048 characters")
            return url_str
        return None

    @field_validator("category", "color", "season", "brand", mode="before")
    @classmethod
    def validate_strings(cls, v):
        if v is not None:
            stripped = str(v).strip()
            return stripped if stripped else None
        return None


class UpdateWardrobeItemRequest(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    image_url: Optional[str] = Field(None, max_length=2048)
    category: Optional[str] = Field(None, max_length=50)
    color: Optional[str] = Field(None, max_length=50)
    season: Optional[str] = Field(None, max_length=50)
    brand: Optional[str] = Field(None, max_length=100)
    is_favorite: Optional[bool] = None

    @field_validator("name", mode="before")
    @classmethod
    def validate_name(cls, v):
        if v is not None:
            if not str(v).strip():
                raise ValueError("Name cannot be whitespace only")
            return str(v).strip()
        return None

    @field_validator("image_url", mode="before")
    @classmethod
    def validate_image_url(cls, v):
        if v is not None and str(v).strip():
            url_str = str(v).strip()
            if not (url_str.startswith("http://") or url_str.startswith("https://")):
                raise ValueError("Image URL must start with http:// or https://")
            if len(url_str) > 2048:
                raise ValueError("Image URL exceeds max length of 2048 characters")
            return url_str
        return None


class CreateOutfitRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    wardrobe_item_ids: list[int]
    occasion: Optional[str] = Field(None, max_length=50)

    @field_validator("name", mode="before")
    @classmethod
    def validate_name(cls, v):
        if not v or not str(v).strip():
            raise ValueError("Name cannot be empty or whitespace only")
        return str(v).strip()

    @field_validator("wardrobe_item_ids", mode="before")
    @classmethod
    def validate_wardrobe_item_ids(cls, v):
        if not v:
            raise ValueError("wardrobe_item_ids cannot be empty")
        # Deduplicate while preserving list structure
        seen: set = set()
        deduped: list = []
        for item in v:
            if item not in seen:
                seen.add(item)
                deduped.append(item)
        return deduped


class UpdateOutfitRequest(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    occasion: Optional[str] = Field(None, max_length=50)
    wardrobe_item_ids: Optional[list[int]] = None

    @field_validator("name", mode="before")
    @classmethod
    def validate_name(cls, v):
        if v is not None:
            if not str(v).strip():
                raise ValueError("Name cannot be whitespace only")
            return str(v).strip()
        return None

    @field_validator("wardrobe_item_ids", mode="before")
    @classmethod
    def validate_wardrobe_item_ids(cls, v):
        if v is not None:
            if not v:
                raise ValueError("wardrobe_item_ids cannot be empty")
            seen: set = set()
            deduped: list = []
            for item in v:
                if item not in seen:
                    seen.add(item)
                    deduped.append(item)
            return deduped
        return None


logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/wardrobe", tags=["wardrobe"])


def _uid(token: dict) -> str:
    return token.get("uid") or token.get("user_id") or ""


def _validate_wardrobe_item_ids(session: Session, auth_uid: str, item_ids: list[int]) -> None:
    owned_ids = {
        row[0]
        for row in session.execute(
            select(WardrobeItem.id).where(
                WardrobeItem.id.in_(item_ids),
                WardrobeItem.user_firebase_uid == auth_uid,
            )
        ).all()
    }
    missing = [item_id for item_id in item_ids if item_id not in owned_ids]
    if missing:
        raise HTTPException(status_code=400, detail=f"Wardrobe items not found or not owned: {missing}")


# ── ROUTE ORDERING: Static routes MUST be registered before /{item_id} ───────

@router.get("")
async def get_wardrobe(
    category: Optional[str] = None,
    color: Optional[str] = None,
    season: Optional[str] = None,
    brand: Optional[str] = None,
    favorite_only: bool = False,
    search: Optional[str] = None,
    offset: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    token: dict = Depends(verify_firebase_token),
    session: Session = Depends(get_session),
):
    auth_uid = _uid(token)
    query = select(WardrobeItem).where(
        WardrobeItem.user_firebase_uid == auth_uid
    )
    if category:
        query = query.where(WardrobeItem.category == category)
    if color:
        query = query.where(WardrobeItem.color == color)
    if season:
        query = query.where(WardrobeItem.season == season)
    if brand:
        query = query.where(WardrobeItem.brand == brand)
    if favorite_only:
        query = query.where(WardrobeItem.is_favorite.is_(True))
    if search:
        safe_search = "%" + search.replace("%", "\\%").replace("_", "\\_") + "%"
        query = query.where(WardrobeItem.name.ilike(safe_search, escape="\\"))
    query = query.order_by(WardrobeItem.created_at.desc())

    total = session.execute(
        select(func.count()).select_from(query.subquery())
    ).scalar() or 0

    items = session.execute(query.offset(offset).limit(limit)).scalars().all()
    return {
        "wardrobe": [
            {
                "id": i.id,
                "name": i.name,
                "image_url": i.image_url,
                "category": i.category,
                "color": i.color,
                "season": i.season,
                "brand": i.brand,
                "is_favorite": bool(i.is_favorite),
                "created_at": (
                    i.created_at.isoformat() if isinstance(i.created_at, datetime) else None
                ),
            }
            for i in items
        ],
        "pagination": {
            "offset": offset,
            "limit": limit,
            "total": total,
            "hasMore": (offset + limit) < total,
        },
    }


@router.post("")
async def add_wardrobe_item(
    payload: AddWardrobeItemRequest,
    token: dict = Depends(verify_firebase_token),
    session: Session = Depends(get_session),
):
    auth_uid = _uid(token)
    item = WardrobeItem(
        user_firebase_uid=auth_uid,
        name=payload.name,
        image_url=payload.image_url,
        category=payload.category,
        color=payload.color,
        season=payload.season,
        brand=payload.brand,
    )
    session.add(item)
    session.commit()
    session.refresh(item)
    return {
        "id": item.id,
        "name": item.name,
        "image_url": item.image_url,
        "category": item.category,
        "color": item.color,
        "season": item.season,
        "brand": item.brand,
        "is_favorite": False,
    }


# ── AI RECOMMENDATIONS ROUTE (Registered BEFORE /{item_id}) ─────────────────

def _map_category_to_role(category: Optional[str]) -> str:
    if not category:
        return "other"
    cat = category.lower().strip()
    if any(k in cat for k in ["top", "shirt", "blouse", "sweater", "hoodie", "tee", "polo"]):
        return "upper"
    if any(k in cat for k in ["pant", "jean", "bottom", "short", "skirt", "trouser", "legging"]):
        return "bottom"
    if any(k in cat for k in ["shoe", "sneaker", "boot", "sandal", "footwear", "flat", "heel"]):
        return "footwear"
    if any(k in cat for k in ["jacket", "coat", "cardigan", "blazer", "outerwear"]):
        return "outerwear"
    if any(k in cat for k in ["dress", "one-piece", "gown"]):
        return "dress"
    if any(k in cat for k in ["bag", "jewel", "accessory", "hat", "belt", "watch"]):
        return "accessory"
    return "other"


@router.get("/recommendations")
async def get_wardrobe_recommendations(
    limit: int = Query(5, ge=1, le=20),
    token: dict = Depends(verify_firebase_token),
    session: Session = Depends(get_session),
):
    auth_uid = _uid(token)

    wardrobe_items = session.execute(
        select(WardrobeItem).where(WardrobeItem.user_firebase_uid == auth_uid)
    ).scalars().all()

    total_items = len(wardrobe_items)
    categories_count: dict[str, int] = {}
    colors_count: dict[str, int] = {}
    seasons_count: dict[str, int] = {}
    by_role_count: dict[str, int] = {}

    for item in wardrobe_items:
        if item.category:
            categories_count[item.category] = categories_count.get(item.category, 0) + 1
        if item.color:
            colors_count[item.color] = colors_count.get(item.color, 0) + 1
        if item.season:
            seasons_count[item.season] = seasons_count.get(item.season, 0) + 1
        role = _map_category_to_role(item.category)
        by_role_count[role] = by_role_count.get(role, 0) + 1

    top_colors = sorted(colors_count.keys(), key=lambda c: colors_count[c], reverse=True)[:5]

    # Gap Analysis
    gaps = []
    if by_role_count.get("upper", 0) == 0:
        gaps.append({"role": "upper", "reason": "Your closet lacks tops or shirts for layering."})
    if by_role_count.get("bottom", 0) == 0:
        gaps.append({"role": "bottom", "reason": "You have no pants or skirts to complete your outfits."})
    if by_role_count.get("footwear", 0) == 0:
        gaps.append({"role": "footwear", "reason": "Add footwear options to match your wardrobe."})

    # Catalog Product Suggestions
    catalog_products = _build_personalized_query(session, auth_uid, limit=limit)
    prefs = session.query(UserPreference).filter(
        UserPreference.user_firebase_uid == auth_uid
    ).first()

    product_suggestions = []
    for p in catalog_products:
        product_suggestions.append({
            "id": p.id,
            "name": p.name,
            "image_url": p.image_url,
            "brand": p.brand,
            "price": p.price,
            "rating": p.rating,
            "reason": _product_reason(prefs, p),
            "score": round((p.rating or 4.5) * 20.0, 1),
        })

    # Outfit Ideas from OWNED Items
    ideas = []
    uppers = [i for i in wardrobe_items if _map_category_to_role(i.category) == "upper"]
    bottoms = [i for i in wardrobe_items if _map_category_to_role(i.category) == "bottom"]
    footwear = [i for i in wardrobe_items if _map_category_to_role(i.category) == "footwear"]
    dresses = [i for i in wardrobe_items if _map_category_to_role(i.category) == "dress"]

    if uppers and bottoms and footwear:
        u, b, f = uppers[0], bottoms[0], footwear[0]
        ideas.append({
            "title": f"Classic {u.name} & {b.name}",
            "wardrobeItemIds": [u.id, b.id, f.id],
            "wardrobe_item_ids": [u.id, b.id, f.id],
            "pieces": [
                {"id": u.id, "name": u.name, "image_url": u.image_url, "category": u.category},
                {"id": b.id, "name": b.name, "image_url": b.image_url, "category": b.category},
                {"id": f.id, "name": f.name, "image_url": f.image_url, "category": f.category},
            ],
            "reason": f"Combines your {u.name} with {b.name} and {f.name} for a balanced daily style.",
        })

    if dresses and footwear:
        d, f = dresses[0], footwear[0]
        ideas.append({
            "title": f"Effortless {d.name}",
            "wardrobeItemIds": [d.id, f.id],
            "wardrobe_item_ids": [d.id, f.id],
            "pieces": [
                {"id": d.id, "name": d.name, "image_url": d.image_url, "category": d.category},
                {"id": f.id, "name": f.name, "image_url": f.image_url, "category": f.category},
            ],
            "reason": f"Pairs your {d.name} with {f.name} for an easy, stylish ensemble.",
        })

    if len(uppers) > 1 and len(bottoms) > 1 and len(footwear) > 1:
        u2, b2, f2 = uppers[1], bottoms[1], footwear[1]
        ideas.append({
            "title": f"Smart Casual {u2.name}",
            "wardrobeItemIds": [u2.id, b2.id, f2.id],
            "wardrobe_item_ids": [u2.id, b2.id, f2.id],
            "pieces": [
                {"id": u2.id, "name": u2.name, "image_url": u2.image_url, "category": u2.category},
                {"id": b2.id, "name": b2.name, "image_url": b2.image_url, "category": b2.category},
                {"id": f2.id, "name": f2.name, "image_url": f2.image_url, "category": f2.category},
            ],
            "reason": f"A refined look bringing together {u2.name} and {b2.name}.",
        })

    return {
        "summary": {
            "itemCount": total_items,
            "item_count": total_items,
            "byRole": by_role_count,
            "by_role": by_role_count,
            "byCategory": categories_count,
            "by_category": categories_count,
            "topColors": top_colors,
            "top_colors": top_colors,
            "total_items": total_items,
            "categories": categories_count,
            "colors": colors_count,
            "seasons": seasons_count,
        },
        "gaps": gaps,
        "productSuggestions": product_suggestions,
        "product_suggestions": product_suggestions,
        "outfitIdeas": ideas,
        "outfit_ideas": ideas,
    }


# ── OUTFITS ROUTES (Registered BEFORE /{item_id}) ─────────────────────────────

@router.get("/outfits")
async def get_outfits(
    offset: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    token: dict = Depends(verify_firebase_token),
    session: Session = Depends(get_session),
):
    auth_uid = _uid(token)
    outfits = session.execute(
        select(Outfit).where(Outfit.user_firebase_uid == auth_uid)
        .order_by(Outfit.created_at.desc())
        .offset(offset).limit(limit)
    ).scalars().all()

    if not outfits:
        return {"outfits": [], "pagination": {"offset": offset, "limit": limit, "total": 0, "hasMore": False}}

    outfit_ids = [o.id for o in outfits]

    all_oi_rows = session.execute(
        select(OutfitItem).where(OutfitItem.outfit_id.in_(outfit_ids))
    ).scalars().all()

    wardrobe_ids = {oi.wardrobe_item_id for oi in all_oi_rows}
    wardrobe_items = session.execute(
        select(WardrobeItem).where(WardrobeItem.id.in_(wardrobe_ids))
    ).scalars().all()
    wardrobe_map = {wi.id: wi for wi in wardrobe_items}

    outfit_items_map: dict[int, list[dict]] = {}
    for oi in all_oi_rows:
        wi = wardrobe_map.get(oi.wardrobe_item_id)
        if wi:
            outfit_items_map.setdefault(oi.outfit_id, []).append(
                {"id": wi.id, "name": wi.name, "image_url": wi.image_url, "category": wi.category}
            )

    result = []
    for outfit in outfits:
        result.append({
            "id": outfit.id,
            "name": outfit.name,
            "occasion": outfit.occasion,
            "is_favorite": bool(outfit.is_favorite),
            "items": outfit_items_map.get(outfit.id, []),
            "wardrobe_item_ids": [item["id"] for item in outfit_items_map.get(outfit.id, [])],
            "created_at": (
                outfit.created_at.isoformat() if isinstance(outfit.created_at, datetime) else None
            ),
        })

    total = session.execute(
        select(func.count(Outfit.id)).where(Outfit.user_firebase_uid == auth_uid)
    ).scalar() or 0

    return {
        "outfits": result,
        "pagination": {
            "offset": offset,
            "limit": limit,
            "total": total,
            "hasMore": (offset + limit) < total,
        },
    }


@router.post("/outfits")
async def create_outfit(
    payload: CreateOutfitRequest,
    token: dict = Depends(verify_firebase_token),
    session: Session = Depends(get_session),
):
    auth_uid = _uid(token)
    _validate_wardrobe_item_ids(session, auth_uid, payload.wardrobe_item_ids)

    outfit = Outfit(
        user_firebase_uid=auth_uid,
        name=payload.name,
        occasion=payload.occasion,
    )
    session.add(outfit)
    session.flush()
    for item_id in payload.wardrobe_item_ids:
        session.add(OutfitItem(outfit_id=outfit.id, wardrobe_item_id=item_id))
    session.commit()
    session.refresh(outfit)
    return {
        "id": outfit.id,
        "name": outfit.name,
        "occasion": outfit.occasion,
        "is_favorite": False,
        "wardrobe_item_ids": payload.wardrobe_item_ids,
    }


@router.delete("/outfits/{outfit_id}")
async def delete_outfit(
    outfit_id: int,
    token: dict = Depends(verify_firebase_token),
    session: Session = Depends(get_session),
):
    auth_uid = _uid(token)
    result = session.execute(
        delete(Outfit).where(
            Outfit.id == outfit_id,
            Outfit.user_firebase_uid == auth_uid,
        )
    )
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Outfit not found")
    session.commit()
    return {"ok": True}

# When a WardrobeItem is deleted, any associated OutfitItem entries
# that reference this WardrobeItem will also be automatically deleted
# due to the CASCADE ON DELETE constraint defined in the database schema.



@router.patch("/outfits/{outfit_id}")
async def update_outfit(
    outfit_id: int,
    payload: UpdateOutfitRequest,
    token: dict = Depends(verify_firebase_token),
    session: Session = Depends(get_session),
):
    auth_uid = _uid(token)
    outfit = session.execute(
        select(Outfit).where(
            Outfit.id == outfit_id,
            Outfit.user_firebase_uid == auth_uid,
        )
    ).scalar_one_or_none()
    if not outfit:
        raise HTTPException(status_code=404, detail="Outfit not found")
    if payload.name is not None:
        outfit.name = payload.name
    if payload.occasion is not None:
        outfit.occasion = payload.occasion
    if payload.wardrobe_item_ids is not None:
        _validate_wardrobe_item_ids(session, auth_uid, payload.wardrobe_item_ids)
        session.execute(
            delete(OutfitItem).where(OutfitItem.outfit_id == outfit_id)
        )
        for item_id in payload.wardrobe_item_ids:
            session.add(OutfitItem(outfit_id=outfit_id, wardrobe_item_id=item_id))
    session.commit()
    session.refresh(outfit)
    return {
        "id": outfit.id,
        "name": outfit.name,
        "occasion": outfit.occasion,
        "is_favorite": bool(outfit.is_favorite),
    }


# ── ITEM PARAMETERIZED ROUTES (Registered AFTER static sub-paths) ─────────────

@router.patch("/{item_id}")
async def update_wardrobe_item(
    item_id: int,
    payload: UpdateWardrobeItemRequest,
    token: dict = Depends(verify_firebase_token),
    session: Session = Depends(get_session),
):
    auth_uid = _uid(token)
    item = session.execute(
        select(WardrobeItem).where(
            WardrobeItem.id == item_id,
            WardrobeItem.user_firebase_uid == auth_uid,
        )
    ).scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Wardrobe item not found")
    if payload.name is not None:
        item.name = payload.name
    if payload.image_url is not None:
        item.image_url = payload.image_url
    if payload.category is not None:
        item.category = payload.category
    if payload.color is not None:
        item.color = payload.color
    if payload.season is not None:
        item.season = payload.season
    if payload.brand is not None:
        item.brand = payload.brand
    if payload.is_favorite is not None:
        item.is_favorite = payload.is_favorite
    session.commit()
    session.refresh(item)
    return {
        "id": item.id,
        "name": item.name,
        "image_url": item.image_url,
        "category": item.category,
        "color": item.color,
        "season": item.season,
        "brand": item.brand,
        "is_favorite": bool(item.is_favorite),
    }


@router.delete("/{item_id}")
async def delete_wardrobe_item(
    item_id: int,
    token: dict = Depends(verify_firebase_token),
    session: Session = Depends(get_session),
):
    # Note on deleting an item used in outfits:
    # Foreign key `OutfitItem.wardrobe_item_id` is configured with `ondelete="CASCADE"`.
    # Deleting a WardrobeItem automatically CASCADE deletes corresponding OutfitItem rows.
    auth_uid = _uid(token)
    result = session.execute(
        delete(WardrobeItem).where(
            WardrobeItem.id == item_id,
            WardrobeItem.user_firebase_uid == auth_uid,
        )
    )
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Wardrobe item not found")
    session.commit()
    return {"ok": True}