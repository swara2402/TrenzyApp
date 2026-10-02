"""Content moderation / report models."""
from __future__ import annotations

from typing import Optional

from sqlalchemy import DateTime, String, Text, Index
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from .models import Base


class ContentReport(Base):
    """User-submitted report against a post, comment, or user."""

    __tablename__ = "content_reports"
    __table_args__ = (
        Index("ix_content_reports_status_created", "status", "created_at"),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True)
    reporter_firebase_uid: Mapped[str] = mapped_column(String, index=True, nullable=False)
    target_type: Mapped[str] = mapped_column(String, nullable=False)  # post|comment|user
    target_id: Mapped[str] = mapped_column(String, index=True, nullable=False)
    reason: Mapped[str] = mapped_column(String, nullable=False, default="other")
    details: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String, nullable=False, default="open")  # open|reviewing|resolved|dismissed
    resolver_note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    resolved_at: Mapped[Optional[DateTime]] = mapped_column(DateTime(timezone=True), nullable=True)
