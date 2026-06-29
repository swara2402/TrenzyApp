from __future__ import annotations

from typing import Optional
from sqlalchemy import String, Integer, DateTime, ForeignKey, JSON, Float
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from sqlalchemy.sql import func



class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    firebase_uid: Mapped[str] = mapped_column(String, unique=True, index=True, nullable=False)
    name: Mapped[str] = mapped_column(String, nullable=False, default="")
    email: Mapped[str] = mapped_column(String, nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Product(Base):
    __tablename__ = "products"

    id: Mapped[str] = mapped_column(String, primary_key=True)

    name: Mapped[str] = mapped_column(String, nullable=False)

    category: Mapped[Optional[str]] = mapped_column(String)
    subcategory: Mapped[Optional[str]] = mapped_column(String)
    article_type: Mapped[Optional[str]] = mapped_column(String)

    gender: Mapped[Optional[str]] = mapped_column(String)
    color: Mapped[Optional[str]] = mapped_column(String)
    season: Mapped[Optional[str]] = mapped_column(String)
    usage: Mapped[Optional[str]] = mapped_column(String)

    price: Mapped[Optional[int]] = mapped_column(Integer)

    brand: Mapped[Optional[str]] = mapped_column(String)
    rating: Mapped[Optional[float]] = mapped_column(Float)

    image_url: Mapped[Optional[str]] = mapped_column(String)

    tags: Mapped[Optional[list]] = mapped_column(JSON)
    affiliate_links: Mapped[Optional[dict]] = mapped_column(JSON)



class AffiliateClick(Base):
    __tablename__ = "affiliate_clicks"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    product_id: Mapped[str] = mapped_column(String, index=True, nullable=False)
    clicked_by_firebase_uid: Mapped[str] = mapped_column(String, index=True, nullable=False)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())



class WishlistItem(Base):
    __tablename__ = "wishlist_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, index=True, nullable=False)
    product_id: Mapped[str] = mapped_column(String, index=True, nullable=False)


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, index=True, nullable=False)
    status: Mapped[str] = mapped_column(String, nullable=False, default="placed")
    items: Mapped[list[dict]] = mapped_column(JSON, nullable=False)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Room(Base):
    __tablename__ = "rooms"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    query: Mapped[str] = mapped_column(String, nullable=False)
    options: Mapped[list[dict]] = mapped_column(JSON, nullable=False, default=list)
    # Mapping optionId -> list of userIds
    votes: Mapped[dict[str, list[str]]] = mapped_column(JSON, nullable=False, default=dict)
    # List of reaction dictionaries: [{'friendName': str, 'emoji': str, 'note': str, 'optionId': str}]
    reactions: Mapped[list[dict]] = mapped_column(JSON, nullable=False, default=list)
    participant_count: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Decision(Base):
    __tablename__ = "decisions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, index=True, nullable=False)

    query: Mapped[str] = mapped_column(String, nullable=False)
    selectedOptions: Mapped[list[dict]] = mapped_column(JSON, nullable=False)
    recommendedOptionId: Mapped[str] = mapped_column(String, nullable=False)
    reasoning: Mapped[str] = mapped_column(String, nullable=False, default="")
    socialApproval: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class CartItem(Base):
    __tablename__ = "cart_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, index=True, nullable=False)
    product_id: Mapped[str] = mapped_column(String, index=True, nullable=False)
    title: Mapped[str] = mapped_column(String, nullable=False)
    price: Mapped[str] = mapped_column(String, nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, nullable=False, default=1)


class OrderItem(Base):
    __tablename__ = "order_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    order_id: Mapped[str] = mapped_column(String, ForeignKey("orders.id", ondelete="CASCADE"), index=True, nullable=False)
    product_id: Mapped[str] = mapped_column(String, nullable=False)
    title: Mapped[str] = mapped_column(String, nullable=False)
    price: Mapped[str] = mapped_column(String, nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)


class Group(Base):
    __tablename__ = "groups"

    id: Mapped[str] = mapped_column(String, primary_key=True)  # Legacy: also used as inviteCode
    name: Mapped[str] = mapped_column(String, nullable=False)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class GroupMember(Base):
    __tablename__ = "group_members"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    group_id: Mapped[str] = mapped_column(String, ForeignKey("groups.id", ondelete="CASCADE"), index=True, nullable=False)
    user_firebase_uid: Mapped[str] = mapped_column(String, index=True, nullable=False)
    user_name: Mapped[str] = mapped_column(String, nullable=False, default="Guest")


class GroupInvitation(Base):
    __tablename__ = "group_invitations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    token: Mapped[str] = mapped_column(String, unique=True, index=True, nullable=False)

    group_id: Mapped[str] = mapped_column(String, ForeignKey("groups.id", ondelete="CASCADE"), index=True, nullable=False)

    inviter_firebase_uid: Mapped[str] = mapped_column(String, index=True, nullable=False)
    inviter_name: Mapped[str] = mapped_column(String, nullable=False, default="Guest")

    # MVP: expiry tracked by duration seconds from created_at
    expires_seconds: Mapped[int] = mapped_column(Integer, nullable=False, default=60 * 60 * 24 * 7)

    status: Mapped[str] = mapped_column(String, nullable=False, default="pending")  # pending|accepted|expired

    accepted_by_firebase_uid: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    accepted_at: Mapped[Optional[DateTime]] = mapped_column(DateTime(timezone=True), nullable=True)


    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class GroupMessage(Base):

    __tablename__ = "group_messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    group_id: Mapped[str] = mapped_column(String, ForeignKey("groups.id", ondelete="CASCADE"), index=True, nullable=False)

    sender_firebase_uid: Mapped[str] = mapped_column(String, index=True, nullable=False)
    sender_name: Mapped[str] = mapped_column(String, nullable=False, default="Guest")

    message: Mapped[str] = mapped_column(String, nullable=False)
    
    # Product sharing support
    attached_product_id: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    attached_product_title: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    attached_product_image: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    attached_product_price: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class GroupSwipe(Base):
    __tablename__ = "group_swipes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    group_id: Mapped[str] = mapped_column(String, ForeignKey("groups.id", ondelete="CASCADE"), index=True, nullable=False)
    user_firebase_uid: Mapped[str] = mapped_column(String, nullable=False)
    product_id: Mapped[str] = mapped_column(String, nullable=False)
    score: Mapped[int] = mapped_column(Integer, nullable=False)  # Like: +1, Love: +2, Dislike: -1


class Friend(Base):
    __tablename__ = "friends"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, index=True, nullable=False)
    friend_firebase_uid: Mapped[str] = mapped_column(String, nullable=False)
    friend_name: Mapped[str] = mapped_column(String, nullable=False, default="Friend")
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class FriendRequest(Base):
    __tablename__ = "friend_requests"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    from_firebase_uid: Mapped[str] = mapped_column(String, index=True, nullable=False)
    from_name: Mapped[str] = mapped_column(String, nullable=False, default="User")
    to_firebase_uid: Mapped[str] = mapped_column(String, index=True, nullable=False)
    status: Mapped[str] = mapped_column(String, nullable=False, default="pending")  # pending|accepted|rejected
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())






class ProductView(Base):
    """Tracks each product view for trend analytics."""
    __tablename__ = "product_views"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    product_id: Mapped[str] = mapped_column(String, index=True, nullable=False)
    viewed_by_firebase_uid: Mapped[Optional[str]] = mapped_column(String, index=True, nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class TrendMetric(Base):
    """Aggregated time-series metrics for trend prediction."""
    __tablename__ = "trend_metrics"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    product_id: Mapped[str] = mapped_column(String, index=True, nullable=False)
    # Time window: "daily" or "hourly"
    timeframe: Mapped[str] = mapped_column(String, nullable=False, default="daily")
    # Start of the time window
    window_start: Mapped[DateTime] = mapped_column(DateTime(timezone=True), nullable=False)
    # Aggregated counts
    view_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    click_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    # Computed trend scores
    trending_score: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    momentum: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    # Category for filtering
    category: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
