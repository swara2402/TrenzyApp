from __future__ import annotations

from typing import Optional

from sqlalchemy import DateTime, Integer, String
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from sqlalchemy.sql import func

from .models import Base


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_firebase_uid: Mapped[str] = mapped_column(String, index=True, nullable=False)

    kind: Mapped[str] = mapped_column(String, nullable=False, default="in-app")
    title: Mapped[str] = mapped_column(String, nullable=False, default="Notification")
    body: Mapped[str] = mapped_column(String, nullable=False, default="")

    read: Mapped[bool] = mapped_column(Integer, nullable=False, default=0)  # 0/1

    payload_json: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
