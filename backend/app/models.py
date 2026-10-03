"""SQLAlchemy ORM models for the Trenzy database.

Defines all database tables used by the Trenzy backend. Models are organized
into domain groups:

- **Products**: Product, ProductImage, ProductVariant, Brand, Category
- **Users**: User, UserPreference, StylePersona, PushDevice
- **Social**: Friend, FriendRequest, Follow, Post, Like, Comment, Save
- **Shopping**: Wishlist, Cart, CartItem, Order, OrderItem, Purchase
- **Wardrobe**: WardrobeItem, Outfit, OutfitItem
- **Blends**: Blend, BlendMember, BlendInvitation, BlendSwipe, BlendMessage
- **Trends**: View, AffiliateClick, TrendMetric, TrendingProduct, TrendingCreator
- **Activity**: ActivityEvent, Campaign, Decision, FriendSuggestion

All models inherit from :class:`Base` (SQLAlchemy declarative base). The
``Product`` model includes outfit styling fields (outfit_role, style, occasion,
material, fit) used by the catalog pipeline for outfit recommendations.
"""

from __future__ import annotations

from typing import Optional

from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    CheckConstraint,
    func,
    Index,
    JSON,
)
from sqlalchemy.types import NullType as _NullType
from sqlalchemy.ext.compiler import compiles
try:
    from sqlalchemy.dialects.postgresql import TSVECTOR
    # Temporarily skip importing pgvector to avoid SQLAlchemy Mapped annotation errors
    # from pgvector.sqlalchemy import Vector
    PGVECTOR_AVAILABLE = False  # Temporarily disabled to prevent server crash from HNSW index errors
    Vector = None  # type: ignore

    @compiles(TSVECTOR, "sqlite")
    def _compile_tsvector_sqlite(element, compiler, **kw):  # type: ignore[no-untyped-def]
        return "TEXT"

    if PGVECTOR_AVAILABLE and Vector is not None:
        @compiles(Vector, "sqlite")
        def _compile_vector_sqlite(element, compiler, **kw):  # type: ignore[no-untyped-def]
            return "TEXT"
except ImportError:
    TSVECTOR = _NullType  # type: ignore
    Vector = None  # type: ignore
    PGVECTOR_AVAILABLE = False
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base

# Import models from separate files so Alembic discovers them.
from . import models_payments  # noqa: F401 — Payment model
from . import models_notifications  # noqa: F401 — Notification model
from . import models_moderation  # noqa: F401
from . import models_blend_features  # noqa: F401 — SharedWishlistItem, MoodboardItem, BlendInsight
from .ai import models_ai  # noqa: F401 — AI models

# Canonical embedding dimension — must match the loaded FashionCLIP model.
# Import here so SQLAlchemy can use it at class-definition time.
try:
    from .ai.ml_config import EMBEDDING_DIM as _EMBEDDING_DIM
except Exception:  # model not installed in current env
    _EMBEDDING_DIM = 512


class User(Base):
    """Registered Trenzy user.

    Stores profile information synced from Firebase Authentication. The
    ``firebase_uid`` is the primary link to Firebase and is used as the
    foreign key in all user-referencing tables (wishlist, blends, etc.).
    """

    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    firebase_uid: Mapped[str] = mapped_column(
        String, unique=True, index=True, nullable=False
    )

    name: Mapped[str] = mapped_column(String, nullable=False, default="")
    email: Mapped[str] = mapped_column(String, nullable=True)
    avatar_url: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    bio: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    # Server-side admin flag. Deny-by-default: only rows explicitly set to
    # True (via migration/SQL by an operator, or Firebase custom claim) grant
    # access to admin-only endpoints. Never settable through the public API.
    is_admin: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="0"
    )
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class Product(Base):
    """Fashion product in the Trenzy catalog.

    Each product has core attributes (name, category, price, brand) plus
    outfit styling fields populated by the catalog pipeline:

    - ``outfit_role``: Which part of an outfit this is (``upper``, ``bottom``,
      ``footwear``) — used for outfit composition rules.
    - ``style``: Fashion style category (Casual, Formal, Sporty, Ethnic).
    - ``occasion``: Intended use case (Casual, Formal, Sports, Party, etc.).
    - ``material``: Primary fabric/material (Cotton, Polyester, Denim, etc.).
    - ``fit``: Garment fit (Regular, Slim, Oversized, Athletic, Straight).

    The ``search_vector`` tsvector column (not mapped here, managed by a DB
    trigger) enables full-text search via GIN index.
    """

    __tablename__ = "products"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False, default="")
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    category: Mapped[Optional[str]] = mapped_column(String, nullable=True, index=True)
    subcategory: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    article_type: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    gender: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    color: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    season: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    usage: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    price: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    brand: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    brand_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("brands.id", ondelete="SET NULL"), nullable=True)
    category_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("categories.id", ondelete="SET NULL"), nullable=True)
    rating: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    image_url: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    tags: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    affiliate_links: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    is_archived: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    outfit_role: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    style: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    occasion: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    material: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    fit: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    primary_color: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    display_brand: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    display_color: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    display_category: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    display_price: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    search_keywords: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    style_tags: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    occasion_tags: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    color_tags: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    brand_tags: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    season_tags: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)

    # Legal and source metadata (per your foundation requirements)
    source: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    source_license: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    source_page: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    license_attribution: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    author: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    image_sha256: Mapped[Optional[str]] = mapped_column(String(64), nullable=True, index=True)
    image_phash: Mapped[Optional[str]] = mapped_column(String(64), nullable=True, index=True)
    currency: Mapped[str] = mapped_column(String(10), nullable=False, default="INR")

    # Embedding metadata for pgvector
    image_embedding_status: Mapped[Optional[str]] = mapped_column(String(50), nullable=True, default="pending")
    image_embedding_model: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    image_embedding_version: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    image_embedding_created_at: Mapped[Optional[DateTime]] = mapped_column(DateTime(timezone=True), nullable=True)
    
    text_embedding_status: Mapped[Optional[str]] = mapped_column(String(50), nullable=True, default="pending")
    text_embedding_model: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    text_embedding_version: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    text_embedding_created_at: Mapped[Optional[DateTime]] = mapped_column(DateTime(timezone=True), nullable=True)

    # pgvector columns for FashionCLIP embeddings — dimension driven by ml_config.
    image_embedding_vector: Mapped[Optional[list]] = mapped_column(
        Vector(_EMBEDDING_DIM) if PGVECTOR_AVAILABLE else JSON,
        nullable=True
    )
    text_embedding_vector: Mapped[Optional[list]] = mapped_column(
        Vector(_EMBEDDING_DIM) if PGVECTOR_AVAILABLE else JSON,
        nullable=True
    )

    # tsvector column for full-text search, populated by DB trigger.
    # Uses NullType fallback when not running on PostgreSQL (e.g. SQLite tests).
    search_vector = mapped_column(TSVECTOR, nullable=True)

    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    __table_args__ = (
        Index('ix_products_search_vector', 'search_vector',
              postgresql_using='gin'),
        # Add HNSW index for pgvector vector search if available
        *(
            (
                Index(
                    'idx_products_image_embedding_vector',
                    'image_embedding_vector',
                    postgresql_using='hnsw',
                    postgresql_with={"m": 16, "ef_construction": 64}
                ),
                Index(
                    'idx_products_text_embedding_vector',
                    'text_embedding_vector',
                    postgresql_using='hnsw',
                    postgresql_with={"m": 16, "ef_construction": 64}
                )
            ) if PGVECTOR_AVAILABLE else ()
        )
    )


class Room(Base):
    __tablename__ = "rooms"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    participant_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    options: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True, default=dict)
    votes: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True, default=dict)
    reactions: Mapped[Optional[list]] = mapped_column(JSON, nullable=True, default=list)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    def to_dict(self):
        created_at_iso = str(self.created_at) if self.created_at else None
        return {
            "id": self.id,
            "participantCount": self.participant_count,
            "options": self.options or [],
            "votes": self.votes or {},
            "reactions": self.reactions or [],
            "createdAt": created_at_iso,
        }


class Wishlist(Base):
    __tablename__ = "wishlist"
    __table_args__ = (
        UniqueConstraint("user_firebase_uid", "product_id", name="uq_wishlist_user_product"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    product_id: Mapped[str] = mapped_column(
        String, ForeignKey("products.id", ondelete="CASCADE"), nullable=False
    )
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class Cart(Base):
    __tablename__ = "carts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class CartItem(Base):
    __tablename__ = "cart_items"
    __table_args__ = (
        UniqueConstraint("cart_id", "product_id", name="uq_cart_items_cart_product"),
        CheckConstraint("quantity >= 1", name="ck_cart_items_quantity_positive"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    cart_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("carts.id", ondelete="CASCADE"), nullable=False
    )
    user_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    product_id: Mapped[str] = mapped_column(
        String, ForeignKey("products.id", ondelete="CASCADE"), nullable=False
    )
    quantity: Mapped[int] = mapped_column(Integer, nullable=False, default=1)


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    status: Mapped[str] = mapped_column(String, nullable=False, default="pending")
    items: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class OrderItem(Base):
    __tablename__ = "order_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    order_id: Mapped[str] = mapped_column(
        String, ForeignKey("orders.id", ondelete="CASCADE"), nullable=False
    )
    product_id: Mapped[str] = mapped_column(String, nullable=False)
    title: Mapped[str] = mapped_column(String, nullable=False)
    price_cents: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    quantity: Mapped[int] = mapped_column(Integer, nullable=False, default=1)


class Brand(Base):
    __tablename__ = "brands"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    description: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    logo_url: Mapped[Optional[str]] = mapped_column(String, nullable=True)


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    parent_category_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("categories.id", ondelete="SET NULL"), nullable=True
    )


class Friend(Base):
    __tablename__ = "friends"
    __table_args__ = (
        UniqueConstraint("user_firebase_uid", "friend_firebase_uid", name="uq_friends_user_friend"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    friend_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    friend_name: Mapped[str] = mapped_column(String, nullable=False, default="")
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class FriendRequest(Base):
    __tablename__ = "friend_requests"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    from_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    from_name: Mapped[str] = mapped_column(String, nullable=False, default="")
    to_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    status: Mapped[str] = mapped_column(String, nullable=False, default="pending")
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class Follow(Base):
    __tablename__ = "follows"
    __table_args__ = (
        UniqueConstraint("follower_firebase_uid", "following_firebase_uid", name="uq_follows_follower_following"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    follower_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    following_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class Post(Base):
    __tablename__ = "posts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    user_name: Mapped[str] = mapped_column(String, nullable=False, default="")
    content: Mapped[str] = mapped_column(String(length=1000), nullable=False)
    attachment: Mapped[Optional[str]] = mapped_column(String(length=500), nullable=True)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class PostProductTag(Base):
    """Product tags attached to an Inspiration post."""

    __tablename__ = "post_product_tags"
    __table_args__ = (
        UniqueConstraint("post_id", "product_id", name="uq_post_product_tag"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    post_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("posts.id", ondelete="CASCADE"), nullable=False, index=True
    )
    product_id: Mapped[str] = mapped_column(
        String, ForeignKey("products.id", ondelete="CASCADE"), nullable=False, index=True
    )
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class ProductReview(Base):
    """Community review of a catalog product."""

    __tablename__ = "product_reviews"
    __table_args__ = (
        UniqueConstraint("product_id", "user_firebase_uid", name="uq_product_review_user"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    product_id: Mapped[str] = mapped_column(
        String, ForeignKey("products.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    rating: Mapped[int] = mapped_column(Integer, nullable=False)
    title: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class Like(Base):
    __tablename__ = "likes"
    __table_args__ = (
        UniqueConstraint("post_id", "user_firebase_uid", name="uq_likes_post_user"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    post_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("posts.id", ondelete="CASCADE"), nullable=False
    )
    user_firebase_uid: Mapped[str] = mapped_column(String, nullable=False)


class Comment(Base):
    __tablename__ = "comments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    post_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("posts.id", ondelete="CASCADE"), nullable=False
    )
    user_firebase_uid: Mapped[str] = mapped_column(String, nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class Save(Base):
    __tablename__ = "saves"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    post_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("posts.id", ondelete="CASCADE"), nullable=True
    )
    product_id: Mapped[Optional[str]] = mapped_column(
        String, ForeignKey("products.id", ondelete="CASCADE"), nullable=True
    )
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class Purchase(Base):
    __tablename__ = "purchases"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    product_id: Mapped[str] = mapped_column(
        String, ForeignKey("products.id", ondelete="CASCADE"), nullable=False
    )
    quantity: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    price_cents: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    currency: Mapped[str] = mapped_column(String, nullable=False, default="INR")
    order_id: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class WardrobeItem(Base):
    __tablename__ = "wardrobe_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    image_url: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    category: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    color: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    season: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    brand: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    is_favorite: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class Outfit(Base):
    __tablename__ = "outfits"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    occasion: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    is_favorite: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class OutfitItem(Base):
    __tablename__ = "outfit_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    outfit_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("outfits.id", ondelete="CASCADE"), nullable=False
    )
    wardrobe_item_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("wardrobe_items.id", ondelete="CASCADE"), nullable=False
    )


class ActivityEvent(Base):
    __tablename__ = "activity_events"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    kind: Mapped[str] = mapped_column(String, nullable=False)
    description: Mapped[str] = mapped_column(String, nullable=False)
    target_id: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    target_type: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    metadata_json: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class Campaign(Base):
    __tablename__ = "campaigns"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    title: Mapped[str] = mapped_column(String, nullable=False)
    subtitle: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    image_url: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    cta_label: Mapped[str] = mapped_column(String, nullable=False)
    cta_url: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class Decision(Base):
    __tablename__ = "decisions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    query: Mapped[str] = mapped_column(String, nullable=False)
    selected_options: Mapped[Optional[list]] = mapped_column("selected_options", JSON, nullable=True)
    recommended_option_id: Mapped[str] = mapped_column("recommended_option_id", String, nullable=False)
    social_approval: Mapped[int] = mapped_column("social_approval", Integer, nullable=False, default=0)
    reasoning: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class FriendSuggestion(Base):
    __tablename__ = "friend_suggestions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    suggester_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    suggested_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    score: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    reason: Mapped[Optional[str]] = mapped_column(String, nullable=True)


class StylePersona(Base):
    """User's fashion identity used for personalized feed and recommendations.

    Each user gets a default persona ("Urban Minimalist") on signup. The
    persona's ``keywords`` and ``color_palette`` are used to filter product
    recommendations and the "For You" feed section.
    """

    __tablename__ = "style_personas"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True, unique=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    keywords: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    vibe: Mapped[Optional[str]] = mapped_column(String, nullable=True)


class BlendMember(Base):
    __tablename__ = "blend_members"
    __table_args__ = (
        UniqueConstraint("blend_id", "user_firebase_uid", name="uq_blend_members_blend_user"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    blend_id: Mapped[Optional[str]] = mapped_column(String, nullable=True, index=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    user_name: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    joined_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class BlendInvitation(Base):
    __tablename__ = "blend_invitations"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    blend_id: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    token: Mapped[Optional[str]] = mapped_column(String, nullable=True, index=True)
    inviter_firebase_uid: Mapped[str] = mapped_column(String, nullable=False)
    inviter_name: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    invitee_firebase_uid: Mapped[str] = mapped_column(String, nullable=False)
    expires_seconds: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    accepted_by_firebase_uid: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    accepted_at: Mapped[Optional[DateTime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    status: Mapped[str] = mapped_column(String, nullable=False, default="pending")
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class Blend(Base):
    """Collaborative blend group where multiple users swipe on products together.

    Members swipe on products (like/love/dislike), and the system computes
    group compatibility scores and recommends products that maximize
    collective satisfaction.
    """

    __tablename__ = "blends"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False, default="")
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    theme: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    invite_code: Mapped[Optional[str]] = mapped_column(String, nullable=True, index=True)
    cover_image: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    is_private: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    max_members: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    # JSON list of product ids — the shared swipe deck. Persisted once when the
    # blend is created so EVERY member swipes the SAME products in the SAME
    # order (otherwise each member got a random deck and group agreement
    # could never be computed on overlapping votes).
    deck_json: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    user_firebase_uid: Mapped[Optional[str]] = mapped_column(String, ForeignKey("users.firebase_uid"), nullable=True)
    product_id: Mapped[Optional[str]] = mapped_column(String, ForeignKey("products.id"), nullable=True)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

class BlendSwipe(Base):
    """Records a user's swipe on a product within a blend group.

    Score mapping: like=1, love=2, dislike=-1. If a user swipes on the same
    product again, the score is updated (not duplicated). These are aggregated
    by :func:`~app.blend_helpers.compute_blend_results` to rank products.
    """

    __tablename__ = "blend_swipes"
    __table_args__ = (
        UniqueConstraint("blend_id", "user_firebase_uid", "product_id", name="uq_blend_swipes_blend_user_product"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    blend_id: Mapped[str] = mapped_column(
        String, ForeignKey("blends.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    product_id: Mapped[str] = mapped_column(String, nullable=False)
    score: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class BlendMessage(Base):
    """A chat message within a blend group.

    Messages can optionally include an attached product (via the attached_product_*
    fields). Both the REST API and Socket.IO events create BlendMessage records.
    """

    __tablename__ = "blend_messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    blend_id: Mapped[str] = mapped_column(String, nullable=False, index=True)
    sender_firebase_uid: Mapped[str] = mapped_column(String, nullable=False)
    sender_name: Mapped[str] = mapped_column(String, nullable=False, default="")
    content: Mapped[str] = mapped_column(Text, nullable=False)
    attached_product_id: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    attached_product_title: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    attached_product_image: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    attached_product_price: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class UserPreference(Base):
    """User's shopping preferences used for personalized recommendations.

    Stores preferred categories, colors, brands, styles, and other
    preferences. These are set during onboarding and can be updated
    through the persona/preferences screens in the Flutter app.
    """

    __tablename__ = "user_preferences"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, unique=True, nullable=False, index=True)
    preferred_categories: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    preferred_brands: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    preferred_colors: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    preferred_seasons: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    preferred_styles: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    preferred_aesthetics: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    preferred_occasions: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    budget_max: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    shopping_priorities: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    discover_preferences: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)


class TrendingProduct(Base):
    __tablename__ = "trending_products"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    product_id: Mapped[str] = mapped_column(String, nullable=False, index=True)
    trending_score: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    momentum: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    timeframe: Mapped[str] = mapped_column(String, nullable=False, default="daily")
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class TrendingCreator(Base):
    __tablename__ = "trending_creators"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    trending_score: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    timeframe: Mapped[str] = mapped_column(String, nullable=False, default="daily")
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class View(Base):
    """Records a single product view event for trend analytics.

    Each row represents one view. These are aggregated by the trends
    endpoint to compute TrendMetric.view_count.
    """

    __tablename__ = "views"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    product_id: Mapped[str] = mapped_column(String, nullable=False, index=True)
    viewed_by_firebase_uid: Mapped[Optional[str]] = mapped_column(String, nullable=True, index=True)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class AffiliateClick(Base):
    """Records a click on an affiliate link for a product.

    Used to compute TrendMetric.click_count (weighted 3x in trending
    scores because clicks indicate higher purchase intent than views).
    """

    __tablename__ = "affiliate_clicks"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    product_id: Mapped[str] = mapped_column(String, nullable=False, index=True)
    clicked_by_firebase_uid: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class TrendMetric(Base):
    """Aggregated trend metrics for a product within a time window.

    Stores daily/hourly/weekly view and click counts, computed trending
    scores, and momentum (day-over-day growth rate). Updated by the
    ``/api/trends/aggregate`` endpoint.

    Scoring formula: ``trending_score = (view_count * 1.0) + (click_count * 3.0)``
    Clicks are weighted 3x because they indicate higher purchase intent than views.
    """

    __tablename__ = "trend_metrics"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    product_id: Mapped[str] = mapped_column(String, nullable=False, index=True)
    timeframe: Mapped[str] = mapped_column(String, nullable=False)
    window_start: Mapped[DateTime] = mapped_column(DateTime(timezone=True), nullable=False)
    view_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    click_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    trending_score: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    momentum: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    category: Mapped[Optional[str]] = mapped_column(String, nullable=True)


class ProductImage(Base):
    __tablename__ = "product_images"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    product_id: Mapped[str] = mapped_column(
        String, ForeignKey("products.id", ondelete="CASCADE"), nullable=False, index=True
    )
    url: Mapped[str] = mapped_column(String, nullable=False)
    alt_text: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)


class ProductVariant(Base):
    __tablename__ = "product_variants"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    product_id: Mapped[str] = mapped_column(
        String, ForeignKey("products.id", ondelete="CASCADE"), nullable=False, index=True
    )
    size: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    color: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    stock: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    price_modifier: Mapped[Optional[float]] = mapped_column(Float, nullable=True)


class DirectMessage(Base):
    """One-to-one message between two users.

    Direct chat is available only between accepted friends. Messages are
    addressable in either direction through the normalized conversation key.
    """

    __tablename__ = "direct_messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    conversation_key: Mapped[str] = mapped_column(String, nullable=False, index=True)
    sender_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    recipient_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class PushDevice(Base):
    __tablename__ = "push_devices"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    token: Mapped[str] = mapped_column(String, nullable=False, unique=True)
    platform: Mapped[str] = mapped_column(String, nullable=False, default="fcm")
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class DiscoverySwipe(Base):
    """Records a user's swipe on a product in the discovery feed.

    Score mapping: like=1, dislike=-1, save=2. Used to filter out
    already-seen products and to improve future recommendations.
    """

    __tablename__ = "discovery_swipes"
    __table_args__ = (
        UniqueConstraint("user_firebase_uid", "product_id", name="uq_discovery_swipes_user_product"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, nullable=False, index=True)
    product_id: Mapped[str] = mapped_column(
        String, ForeignKey("products.id", ondelete="CASCADE"), nullable=False
    )
    score: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )