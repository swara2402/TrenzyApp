"""Product events CRUD router (Phase 10).

Endpoints
---------
POST /api/events/           — record a product event
GET  /api/events/{product_id} — list events for a product (paginated)
GET  /api/events/user/{uid}   — list events for a user (paginated)
"""

from __future__ import annotations

import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import AliasChoices, BaseModel, ConfigDict, Field, field_validator
from sqlalchemy.orm import Session

from ..db import get_session
from ..auth_deps import get_current_user
from ..models_style import ProductEvent, PRODUCT_EVENT_TYPES

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/events", tags=["events"])


# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------

class ProductEventCreate(BaseModel):
    product_id: str
    user_firebase_uid: Optional[str] = None
    event_type: str
    session_id: Optional[str] = None
    source: Optional[str] = None
    metadata_: Optional[dict] = Field(
        default=None,
        validation_alias=AliasChoices("metadata_", "metadata"),
        serialization_alias="metadata",
    )

    model_config = ConfigDict(populate_by_name=True)

    @field_validator("event_type")
    @classmethod
    def validate_event_type(cls, v: str) -> str:
        if v not in PRODUCT_EVENT_TYPES:
            raise ValueError(
                f"Invalid event_type '{v}'. Must be one of: {sorted(PRODUCT_EVENT_TYPES)}"
            )
        return v


class ProductEventRead(BaseModel):
    id: str
    product_id: str
    user_firebase_uid: str
    event_type: str
    session_id: Optional[str] = None
    source: Optional[str] = None
    metadata_: Optional[dict] = Field(
        default=None,
        validation_alias=AliasChoices("metadata_", "metadata"),
        serialization_alias="metadata",
    )

    model_config = ConfigDict(from_attributes=True, populate_by_name=True)


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.post("/", response_model=ProductEventRead, status_code=201)
def record_event(
    payload: ProductEventCreate,
    user: dict = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    """Record a user–product interaction event.

    The event is always attributed to the authenticated user; the
    ``user_firebase_uid`` supplied in the body is ignored so callers cannot
    pollute other users' interaction histories.
    """
    uid = user.get("uid") or user.get("firebase_uid")
    event = ProductEvent(
        product_id=payload.product_id,
        user_firebase_uid=str(uid),
        event_type=payload.event_type,
        session_id=payload.session_id,
        source=payload.source,
        metadata_=payload.metadata_,
    )
    db.add(event)
    db.commit()
    db.refresh(event)
    return event


@router.get("/product/{product_id}", response_model=List[ProductEventRead])
def list_events_for_product(
    product_id: str,
    event_type: Optional[str] = Query(None, description="Filter by event type"),
    limit: int = Query(50, ge=1, le=500),
    offset: int = Query(0, ge=0),
    user: dict = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    """List events for a specific product (newest first).

    Privacy: users may only see their own interaction history. This prevents
    exposing other users' Firebase UIDs and browsing behaviour through a
    public product feed.
    """
    uid = str(user.get("uid") or user.get("firebase_uid"))
    q = (
        db.query(ProductEvent)
        .filter(
            ProductEvent.product_id == product_id,
            ProductEvent.user_firebase_uid == uid,
        )
        .order_by(ProductEvent.created_at.desc())
    )
    if event_type:
        q = q.filter(ProductEvent.event_type == event_type)
    return q.offset(offset).limit(limit).all()


@router.get("/user/{uid}", response_model=List[ProductEventRead])
def list_events_for_user(
    uid: str,
    event_type: Optional[str] = Query(None, description="Filter by event type"),
    limit: int = Query(50, ge=1, le=500),
    offset: int = Query(0, ge=0),
    user: dict = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    """List events for a specific user (newest first).

    Users may only read their own interaction history.
    """
    current_uid = str(user.get("uid") or user.get("firebase_uid"))
    if uid != current_uid:
        raise HTTPException(status_code=403, detail="Cannot view another user's events")
    q = (
        db.query(ProductEvent)
        .filter(ProductEvent.user_firebase_uid == uid)
        .order_by(ProductEvent.created_at.desc())
    )
    if event_type:
        q = q.filter(ProductEvent.event_type == event_type)
    return q.offset(offset).limit(limit).all()
