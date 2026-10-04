from __future__ import annotations

from typing import Optional

from sqlalchemy import DateTime, Integer, String, JSON
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from .models import Base


class Payment(Base):
    __tablename__ = "payments"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, index=True, nullable=False)

    # MVP/payment gateway fields
    amount_paise: Mapped[int] = mapped_column(Integer, nullable=False)
    currency: Mapped[str] = mapped_column(String, nullable=False, default="INR")

    razorpay_order_id: Mapped[str] = mapped_column(String, nullable=False, index=True)
    razorpay_payment_id: Mapped[Optional[str]] = mapped_column(String, nullable=True, index=True)
    razorpay_signature: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    # Immutable transaction item snapshot taken at order creation time
    snapshot_json: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)

    # When verified/finalized successfully, we link the created Order record.
    order_id: Mapped[Optional[str]] = mapped_column(String, nullable=True, index=True)

    # State machine: created -> authorized -> captured -> order_pending -> completed | failed | reconciliation_needed | refunded
    status: Mapped[str] = mapped_column(
        String,
        nullable=False,
        default="created",
    )

    error_message: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    verified_at: Mapped[Optional[DateTime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

