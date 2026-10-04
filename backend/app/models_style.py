"""Style DNA and Product Event models (Phase 10).

StyleDNA stores a per-product FashionCLIP embedding projected through a
lightweight style encoder to produce a compact "style fingerprint" vector.

ProductEvent captures user interactions with products (view, click,
purchase, etc.) for downstream personalisation and analytics pipelines.
"""

from __future__ import annotations

import uuid
from typing import Optional
from sqlalchemy import String, Integer, ForeignKey, JSON, Index, DateTime
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from .db import Base
from .ai.ml_config import EMBEDDING_DIM

# Optional pgvector — fallback to JSON for SQLite (dev / test)
try:
    from pgvector.sqlalchemy import Vector
    _PGVECTOR_AVAILABLE = True
except ImportError:  # pragma: no cover
    Vector = None  # type: ignore[assignment,misc]
    _PGVECTOR_AVAILABLE = False


def _new_uuid() -> str:
    return str(uuid.uuid4())


class StyleDNA(Base):
    """Per-product style fingerprint vector.

    The ``dna_vector`` column stores the L2-normalised style embedding of
    dimension ``EMBEDDING_DIM``.  When pgvector is unavailable (SQLite dev
    mode) the vector is stored as a JSON array.

    Columns
    -------
    id : str (UUID PK)
    product_id : str  — FK → products.id (CASCADE DELETE)
    dna_vector : list[float]  — style embedding vector
    model_name : str  — name of the model that produced this DNA
    model_version : str  — version tag (e.g. "v1")
    metadata_ : dict  — arbitrary extra metadata (JSON)
    created_at : datetime
    """

    __tablename__ = "style_dna"

    id: Mapped[str] = mapped_column(
        String, primary_key=True, default=_new_uuid
    )
    product_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("products.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    dna_vector: Mapped[Optional[list]] = mapped_column(
        Vector(EMBEDDING_DIM) if _PGVECTOR_AVAILABLE else JSON,  # type: ignore[arg-type]
        nullable=True,
    )
    model_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    model_version: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    metadata_: Mapped[Optional[dict]] = mapped_column(
        "metadata", JSON, nullable=True, default=dict
    )
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )



# ---------------------------------------------------------------------------
# Product events
# ---------------------------------------------------------------------------

#: Allowed event types — complete set per requirements.
PRODUCT_EVENT_TYPES: frozenset[str] = frozenset(
    {"impression", "view", "click", "like", "dislike", "save", "add_to_outfit", "share", 
     "add_to_cart", "purchase"}
)


class ProductEvent(Base):
    """User interaction events on products.

    Used for downstream personalisation (collaborative filtering, bandit
    feedback loops) and analytics.

    Columns
    -------
    id : str (UUID PK)
    product_id : str — FK → products.id (CASCADE DELETE)
    user_firebase_uid : str — Firebase UID of the acting user
    event_type : str — one of PRODUCT_EVENT_TYPES
    session_id : str | None — optional client session ID for funnel analysis
    source : str | None — originating surface (e.g. "feed", "search", "blend")
    metadata : dict | None — extra context (e.g. query string, blend_id)
    created_at : datetime
    """

    __tablename__ = "product_events"

    id: Mapped[str] = mapped_column(
        String, primary_key=True, default=_new_uuid
    )
    product_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("products.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_firebase_uid: Mapped[str] = mapped_column(
        String, nullable=False, index=True
    )
    event_type: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    session_id: Mapped[Optional[str]] = mapped_column(String(128), nullable=True)
    source: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    metadata_: Mapped[Optional[dict]] = mapped_column("metadata", JSON, nullable=True, default=dict)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True
    )

    __table_args__ = (
        Index("ix_product_events_user_product", "user_firebase_uid", "product_id"),
        Index("ix_product_events_event_type_created", "event_type", "created_at"),
    )