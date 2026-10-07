"""Product listing, search, and detail endpoints.


Provides the core product discovery experience:

- **Listing** (``GET /api/products``): Filterable, sortable, paginated product catalog.
- **Search** (``GET /api/products/search``): Full-text search using PostgreSQL tsvector
  with GIN index. Falls back to ILIKE for special-character queries.
- **Batch** (``GET /api/products/batch``): Fetch multiple products by ID in one query.
- **Detail** (``GET /api/products/{id}``): Product page with gallery, variants,
  similar products, and wishlist status.
- **Unified search** (``GET /api/search``): Search across products, users, and blends.

**Authentication policy**: Product discovery (list, search, batch, detail) is **public**
(no authentication required). Users can browse the catalog before logging in. This is
intentional for discoverability and crawling. User-specific actions (wishlist, saves)
require authentication.

Search implementation detail: The ``search_vector`` column is a PostgreSQL tsvector
maintained by a trigger (``products_search_vector_update``). It concatenates
weighted fields: name (A), category/subcategory/article_type (B), color/season/gender (C).
The GIN index enables sub-millisecond lookups. ``ts_rank_cd`` provides relevance scoring.
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
import re

from sqlalchemy import func, literal_column, or_, select
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..models import Brand, Product, ProductImage, ProductVariant, Wishlist
from ..launch_flags import BETA_COMMERCE_ENABLED

router = APIRouter(prefix="/api", tags=["products"])


def _escape_like(value: str) -> str:
    """Escape LIKE wildcards so user input can't inject % or _ patterns."""
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def _product_payload(product):
    return {
        "id": product.id,
        "name": product.name,
        "category": product.category,
        "subcategory": product.subcategory,
        "article_type": product.article_type,
        "gender": product.gender or "Unisex",
        "color": product.color,
        "season": product.season,
        "usage": product.usage,
        "price": product.price,
        "currency": product.currency,
        "brand": product.brand,
        "rating": product.rating,
        "image_url": product.image_url,
        "tags": product.tags,
        "affiliate_links": product.affiliate_links if BETA_COMMERCE_ENABLED else None,
        "outfit_role": getattr(product, "outfit_role", None),
        "style": getattr(product, "style", None),
        "occasion": getattr(product, "occasion", None),
        "material": getattr(product, "material", None),
        "fit": getattr(product, "fit", None),
        # Enriched display fields from enrichment pipeline
        "display_brand": product.display_brand,
        "display_color": product.display_color,
        "display_category": product.display_category,
        "display_price": product.display_price,
    }


class ProductQuery(BaseModel):
    query: str


@router.get("/products")
def list_products(
    request: Request,
    category: Optional[str] = None,
    subcategory: Optional[str] = None,
    gender: Optional[str] = None,
    color: Optional[str] = None,
    season: Optional[str] = None,
    min_price: Optional[float] = None,
    max_price: Optional[float] = None,
    brand: Optional[str] = None,
    sort: str = "newest",
    offset: int = 0,
    limit: int = 24,
    session: Session = Depends(get_session),
):
    """List products with filtering, sorting, and pagination."""

    limit = max(1, min(limit, 100))
    offset = max(0, offset)

    base_stmt = select(Product).where(Product.is_archived.is_(False))
    if category:
        base_stmt = base_stmt.where(
            Product.category.ilike(f"%{_escape_like(category)}%", escape="\\")
        )
    if subcategory:
        base_stmt = base_stmt.where(
            Product.subcategory.ilike(f"%{_escape_like(subcategory)}%", escape="\\")
        )
    if gender:
        base_stmt = base_stmt.where(Product.gender.ilike(gender, escape="\\"))
    if color:
        base_stmt = base_stmt.where(Product.color.ilike(f"%{_escape_like(color)}%", escape="\\"))
    if season:
        base_stmt = base_stmt.where(Product.season.ilike(season, escape="\\"))
    if min_price is not None:
        base_stmt = base_stmt.where(Product.price >= min_price)
    if max_price is not None:
        base_stmt = base_stmt.where(Product.price <= max_price)
    if brand:
        base_stmt = base_stmt.outerjoin(Brand, Product.brand_id == Brand.id).where(
            Brand.name.ilike(f"%{_escape_like(brand)}%", escape="\\")
        )

    subq = base_stmt.subquery()
    total = session.query(func.count()).select_from(subq).scalar() or 0

    # Sorting
    if sort == "price_asc":
        base_stmt = base_stmt.order_by(Product.price.asc().nullslast())
    elif sort == "price_desc":
        base_stmt = base_stmt.order_by(Product.price.desc().nullslast())
    elif sort == "rating":
        base_stmt = base_stmt.order_by(Product.rating.desc().nullslast())
    elif sort == "popular":
        base_stmt = base_stmt.order_by(Product.rating.desc().nullslast())
    else:  # newest (default)
        base_stmt = base_stmt.order_by(Product.created_at.desc().nullslast())

    stmt = base_stmt.offset(offset).limit(limit)
    products = list(session.execute(stmt).scalars().all())

    return {
        "products": [_product_payload(p) for p in products],
        "pagination": {
            "offset": offset,
            "limit": limit,
            "total": total,
            "hasMore": (offset + limit) < total,
        },
    }


def _sanitize_tsquery(raw: str) -> str:
    """Convert user input into a safe PostgreSQL tsquery string.

    Tokenizes the input, strips non-alphanumeric characters, and joins
    tokens with ``&`` (AND) for precise matching.  Returns an empty
    string when no valid tokens remain.
    """
    tokens = [
        re.sub(r"[^a-zA-Z0-9]", "", t)
        for t in raw.split()
    ]
    tokens = [t for t in tokens if t]
    return " & ".join(tokens)


@router.get("/products/search")
def search_products(
    request: Request,
    q: str = "",
    category: Optional[str] = None,
    subcategory: Optional[str] = None,
    gender: Optional[str] = None,
    color: Optional[str] = None,
    season: Optional[str] = None,
    brand: Optional[str] = None,
    min_price: Optional[float] = None,
    max_price: Optional[float] = None,
    sort: str = "relevance",
    limit: int = 24,
    session: Session = Depends(get_session),
):
    """Search products using PostgreSQL full-text search (tsvector/tsquery).

    Uses the GIN-indexed ``products.search_vector`` column for fast,
    ranked full-text matching.  Falls back to ILIKE when the query
    cannot produce a valid tsquery (e.g. pure punctuation).
    """
    limit = max(1, min(limit, 100))
    normalized_query = q.strip()[:200]  # Cap search query to prevent abuse

    if not normalized_query:
        return {"products": []}

    # Full-text search requires PostgreSQL's ``search_vector`` tsvector. On
    # other dialects (e.g. the SQLite development fallback) the column exists
    # but is never populated and ``match()``/tsquery functions are unsupported,
    # so fall back to portable ILIKE matching there.
    is_postgres = session.get_bind().dialect.name == "postgresql"

    # Build a safe tsquery string from user input (PostgreSQL only)
    tsquery_str = _sanitize_tsquery(normalized_query) if is_postgres else ""

    # Reference the tsvector column via literal SQL (not mapped on the ORM)
    sv = literal_column("products.search_vector")

    if tsquery_str:
        # Full-text path: tsvector match + ts_rank_cd scoring
        rank_col = func.ts_rank_cd(
            sv, func.to_tsquery("english", tsquery_str)
        ).label("rank")

        stmt = (
            select(Product, rank_col)
            .where(sv.match(tsquery_str, postgresql_regconfig="english"))
            .where(Product.is_archived.is_(False))
        )
    else:
        # No valid tsquery — use ILIKE fallback
        rank_col = None
        stmt = select(Product).where(Product.is_archived.is_(False))

    if category:
        stmt = stmt.where(
            Product.category.ilike(f"%{_escape_like(category)}%", escape="\\")
        )
    if subcategory:
        stmt = stmt.where(
            Product.subcategory.ilike(f"%{_escape_like(subcategory)}%", escape="\\")
        )
    if gender:
        stmt = stmt.where(Product.gender.ilike(gender, escape="\\"))
    if color:
        stmt = stmt.where(Product.color.ilike(f"%{_escape_like(color)}%", escape="\\"))
    if season:
        stmt = stmt.where(Product.season.ilike(season, escape="\\"))
    if brand:
        stmt = stmt.outerjoin(Brand, Product.brand_id == Brand.id).where(
            Brand.name.ilike(f"%{_escape_like(brand)}%", escape="\\")
        )

    if not tsquery_str and normalized_query:
        # ILIKE fallback when tsquery is empty (special-char-only input)
        pattern = f"%{_escape_like(normalized_query)}%"
        stmt = stmt.outerjoin(Brand, Product.brand_id == Brand.id).where(
            or_(
                Product.name.ilike(pattern, escape="\\"),
                Brand.name.ilike(pattern, escape="\\"),
                Product.category.ilike(pattern, escape="\\"),
                Product.subcategory.ilike(pattern, escape="\\"),
                Product.article_type.ilike(pattern, escape="\\"),
            )
        )

    if min_price is not None:
        stmt = stmt.where(Product.price >= min_price)
    if max_price is not None:
        stmt = stmt.where(Product.price <= max_price)

    # Sorting
    if sort == "price_asc":
        stmt = stmt.order_by(Product.price.asc().nullslast())
    elif sort == "price_desc":
        stmt = stmt.order_by(Product.price.desc().nullslast())
    elif sort == "rating_desc":
        stmt = stmt.order_by(Product.rating.desc().nullslast())
    elif sort == "newest":
        stmt = stmt.order_by(Product.id.desc())
    elif rank_col is not None:
        # Relevance sort: ts_rank_cd desc, then rating desc
        stmt = stmt.order_by(
            literal_column("rank").desc(),
            Product.rating.desc().nullslast(),
        )
    elif normalized_query:
        # ILIKE fallback: use LIMIT to bound memory, then re-rank in Python
        query_lower = normalized_query.lower()
        stmt = stmt.order_by(Product.rating.desc().nullslast()).limit(limit * 10)
        products = list(session.execute(stmt).scalars().all())
        products.sort(
            key=lambda p: (
                0 if query_lower in (p.name or "").lower() else 1,
                -(p.rating or 0),
            )
        )
        return {"products": [_product_payload(p) for p in products[:limit]]}
    else:
        stmt = stmt.order_by(Product.id.desc())

    stmt = stmt.limit(limit)
    rows = session.execute(stmt).all()
    products = [row[0] for row in rows]
    return {"products": [_product_payload(p) for p in products]}


@router.get("/products/batch")
def batch_products(
    request: Request,
    ids: str = "",
    session: Session = Depends(get_session),
):
    """Get multiple products by comma-separated IDs (single query, no N+1)."""
    if not ids.strip():
        return {"products": []}

    product_ids = [i.strip() for i in ids.split(",") if i.strip()]
    if not product_ids:
        return {"products": []}

    product_ids = product_ids[:100]  # Cap at 100 to prevent abuse
    products = session.query(Product).filter(Product.id.in_(product_ids)).all()
    return {"products": [_product_payload(p) for p in products]}


@router.get("/products/{product_id}")
def get_product(request: Request, product_id: str, session: Session = Depends(get_session)):
    """Fetch a single product by its string identifier."""

    p = session.query(Product).filter(Product.id == product_id).first()
    if not p:
        raise HTTPException(status_code=404, detail="Product not found")

    payload = _product_payload(p)

    # Gallery images
    images = (
        session.query(ProductImage)
        .filter(ProductImage.product_id == product_id)
        .order_by(ProductImage.sort_order)
        .all()
    )
    payload["gallery"] = [
        {"id": img.id, "url": img.url, "altText": img.alt_text}
        for img in images
    ]

    # Variants
    variants = session.query(ProductVariant).filter(
        ProductVariant.product_id == product_id
    ).all()
    payload["variants"] = [
        {
            "id": v.id,
            "size": v.size,
            "color": v.color,
            "stock": v.stock,
            "priceModifier": v.price_modifier,
        }
        for v in variants
    ]

    # Similar products (same category, excluding self)
    similar = (
        session.query(Product)
        .filter(
            Product.category == p.category,
            Product.id != product_id,
            Product.is_archived.is_(False),
        )
        .limit(8)
        .all()
    )
    payload["similarProducts"] = [_product_payload(s) for s in similar]

    # isInWishlist (if user authenticated)
    try:
        decoded = verify_firebase_token(request)
        uid = decoded.get("uid")
        if uid:
            wish = session.query(Wishlist).filter(
                Wishlist.user_firebase_uid == uid,
                Wishlist.product_id == product_id,
            ).first()
            payload["isInWishlist"] = wish is not None
        else:
            payload["isInWishlist"] = False
    except HTTPException:
        # Auth failed; treat as unauthenticated
        payload["isInWishlist"] = False

    return payload


@router.post("/products/{product_id}/archive")
def archive_product(
    request: Request,
    product_id: str,
    user: dict = Depends(verify_firebase_token),
    session: Session = Depends(get_session),
):
    """Archive a product so it's hidden from most views. Admin only."""
    p = session.query(Product).filter(Product.id == product_id).first()
    if not p:
        raise HTTPException(status_code=404, detail="Product not found")

    from ..auth_helpers import user_is_admin
    if not user_is_admin(user, session):
        raise HTTPException(status_code=403, detail="Only admins can archive products")

    p.is_archived = True
    session.commit()

    return {"status": "success", "message": "Product archived successfully"}


class UnifiedSearchResult(BaseModel):
    products: list[dict] = []
    users: list[dict] = []
    blends: list[dict] = []


@router.get("/search")
def unified_search(
    request: Request,
    q: str = "",
    limit: int = 10,
    session: Session = Depends(get_session),
):
    """Unified search across products, users, and blends."""
    if not q.strip():
        return UnifiedSearchResult()

    limit = max(1, min(limit, 25))
    pattern = f"%{_escape_like(q.strip())}%"

    # Products
    products = (
        session.query(Product)
        .filter(
            Product.is_archived.is_(False),
            Product.name.ilike(pattern, escape="\\"),
        )
        .limit(limit)
        .all()
    )

    # Users
    from ..models import User
    users = (
        session.query(User)
        .filter(User.name.ilike(pattern, escape="\\"))
        .limit(limit)
        .all()
    )

    # Blends (public ones only — private blends must never leak via search)
    from ..models import Blend
    blends = (
        session.query(Blend)
        .filter(
            Blend.name.ilike(pattern, escape="\\"),
            Blend.is_private.is_(False),
        )
        .limit(limit)
        .all()
    )

    return {
        "products": [_product_payload(p) for p in products],
        "users": [
            {
                "id": u.id,
                "name": u.name,
                "avatarUrl": u.avatar_url or "",
            }
            for u in users
        ],
        "blends": [
            {
                "id": b.id,
                "name": b.name,
            }
            for b in blends
        ],
    }