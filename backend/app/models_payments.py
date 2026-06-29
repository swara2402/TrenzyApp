from __future__ import annotations

from sqlalchemy import Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from typing import Optional

# Python 3.9 compatibility: avoid `X | None` union annotations in ORM models.


from sqlalchemy.sql import func

from .models import Base


class Payment(Base):
    __tablename__ = "payments"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, index=True, nullable=False)

    # MVP/payment gateway fields
    amount_paise: Mapped[int] = mapped_column(Integer, nullable=False)
    currency: Mapped[str] = mapped_column(String, nullable=False, default="INR")

    razorpay_order_id: Mapped[str] = mapped_column(String, nullable=False)
    razorpay_payment_id: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    razorpay_signature: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    # When verified successfully, we create a normal Order record.
    order_id: Mapped[Optional[str]] = mapped_column(String, nullable=True)


    status: Mapped[str] = mapped_column(
        String,
        nullable=False,
        default="created",  # created|verified|failed|refunded
    )

    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

