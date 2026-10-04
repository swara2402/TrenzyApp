"""Affiliate campaign management (admin-only).

CRUD endpoints for affiliate marketing campaigns. Only users with
``is_admin=True`` can create, update, or delete campaigns. Regular users
can view active campaigns for the affiliate banner in the app.
"""
from __future__ import annotations

import logging

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..models import Campaign

router = APIRouter(prefix="/api/campaigns", tags=["campaigns"])


class CampaignResponse(BaseModel):
    id: int
    title: str
    subtitle: Optional[str] = None
    imageUrl: Optional[str] = None
    ctaLabel: str
    ctaUrl: Optional[str] = None


@router.get("/featured", response_model=Optional[CampaignResponse])
def get_featured_campaign(request: Request, session: Session = Depends(get_session)):
    decoded = verify_firebase_token(request)
    if not decoded.get("uid"):
        raise HTTPException(status_code=401, detail="Unauthorized")

    campaign = (
        session.query(Campaign)
        .filter(Campaign.active.is_(True))
        .order_by(Campaign.sort_order.asc(), Campaign.created_at.desc())
        .first()
    )
    if not campaign:
        return None
    return CampaignResponse(
        id=campaign.id,
        title=campaign.title,
        subtitle=campaign.subtitle,
        imageUrl=campaign.image_url,
        ctaLabel=campaign.cta_label,
        ctaUrl=campaign.cta_url,
    )
