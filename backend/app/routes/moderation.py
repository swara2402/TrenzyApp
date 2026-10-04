"""Content moderation endpoints.

Users can report posts, comments, or users. Admins can list and resolve reports.
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Any, Literal, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ..auth_deps import get_current_user, require_admin
from ..db import get_session
from ..models_moderation import ContentReport

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/moderation", tags=["moderation"])

AllowedTarget = Literal["post", "comment", "user"]
AllowedReason = Literal[
    "spam", "harassment", "hate", "sexual", "violence", "misinformation", "other"
]


class CreateReportRequest(BaseModel):
    target_type: AllowedTarget
    target_id: str = Field(min_length=1, max_length=128)
    reason: AllowedReason = "other"
    details: Optional[str] = Field(default=None, max_length=2000)


class ResolveReportRequest(BaseModel):
    status: Literal["reviewing", "resolved", "dismissed"]
    resolver_note: Optional[str] = Field(default=None, max_length=2000)


@router.post("/reports")
def create_report(
    payload: CreateReportRequest,
    user: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    uid = user["uid"]
    report = ContentReport(
        id=str(uuid.uuid4()),
        reporter_firebase_uid=uid,
        target_type=payload.target_type,
        target_id=payload.target_id.strip(),
        reason=payload.reason,
        details=(payload.details or "").strip() or None,
        status="open",
    )
    session.add(report)
    session.commit()
    logger.info(
        "content_report_created reporter=%s type=%s target=%s reason=%s",
        uid, payload.target_type, payload.target_id, payload.reason,
    )
    return {"id": report.id, "status": report.status}


@router.get("/reports")
def list_reports(
    status: Optional[str] = Query(default="open"),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    admin: dict = Depends(require_admin),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    q = session.query(ContentReport)
    if status:
        q = q.filter(ContentReport.status == status)
    total = q.count()
    rows = (
        q.order_by(ContentReport.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    return {
        "total": total,
        "items": [
            {
                "id": r.id,
                "reporter_firebase_uid": r.reporter_firebase_uid,
                "target_type": r.target_type,
                "target_id": r.target_id,
                "reason": r.reason,
                "details": r.details,
                "status": r.status,
                "resolver_note": r.resolver_note,
                "created_at": r.created_at.isoformat() if r.created_at else None,
                "resolved_at": r.resolved_at.isoformat() if r.resolved_at else None,
            }
            for r in rows
        ],
    }


@router.post("/reports/{report_id}/resolve")
def resolve_report(
    report_id: str,
    payload: ResolveReportRequest,
    admin: dict = Depends(require_admin),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    report = session.get(ContentReport, report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    report.status = payload.status
    report.resolver_note = payload.resolver_note
    if payload.status in ("resolved", "dismissed"):
        report.resolved_at = datetime.now(timezone.utc)
    session.commit()
    return {"id": report.id, "status": report.status}
