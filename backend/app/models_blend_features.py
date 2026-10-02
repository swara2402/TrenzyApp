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
    func,
    JSON,
)
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base


class SharedWishlistItem(Base):
    __tablename__ = "shared_wishlist_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    blend_id: Mapped[str] = mapped_column(
        String, ForeignKey("blends.id", ondelete="CASCADE"), nullable=False, index=True
    )
    product_id: Mapped[str] = mapped_column(String, nullable=False)
    product_name: Mapped[str] = mapped_column(String, nullable=False, default="")
    product_price: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    product_image: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    product_brand: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    product_category: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    product_url: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    added_by_uid: Mapped[str] = mapped_column(String, nullable=False)
    added_by_name: Mapped[str] = mapped_column(String, nullable=False, default="")
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    is_favorite: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    purchase_link: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class MoodboardItem(Base):
    __tablename__ = "moodboard_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    blend_id: Mapped[str] = mapped_column(
        String, ForeignKey("blends.id", ondelete="CASCADE"), nullable=False, index=True
    )
    item_type: Mapped[str] = mapped_column(
        String, nullable=False, default="product"
    )
    content: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    image_url: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    caption: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    added_by_uid: Mapped[str] = mapped_column(String, nullable=False)
    added_by_name: Mapped[str] = mapped_column(String, nullable=False, default="")
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class BlendInsight(Base):
    __tablename__ = "blend_insights"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    blend_id: Mapped[str] = mapped_column(
        String, ForeignKey("blends.id", ondelete="CASCADE"), nullable=False, index=True
    )
    insight_type: Mapped[str] = mapped_column(String, nullable=False)
    title: Mapped[str] = mapped_column(String, nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    confidence: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    category: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    metadata_json: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
