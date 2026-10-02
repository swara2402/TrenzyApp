"""Style DNA CRUD router (Phase 10).

Endpoints
---------
GET  /api/style-dna/{product_id}  — retrieve Style DNA for a product
POST /api/style-dna/              — create or upsert Style DNA
DELETE /api/style-dna/{product_id} — delete Style DNA for a product
GET  /api/style-dna/similar/{product_id}?limit=N — find similar products by DNA
"""

from __future__ import annotations

import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import AliasChoices, BaseModel, ConfigDict, Field
from sqlalchemy.orm import Session

from ..db import get_session
from ..auth_deps import get_current_user
from ..models_style import StyleDNA, PRODUCT_EVENT_TYPES  # noqa: F401

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/style-dna", tags=["style-dna"])


# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------

class StyleDNACreate(BaseModel):
    product_id: str
    dna_vector: List[float]
    model_name: Optional[str] = None
    model_version: Optional[str] = None
    metadata_: Optional[dict] = Field(
        default=None,
        validation_alias=AliasChoices("metadata_", "metadata"),
        serialization_alias="metadata",
    )

    model_config = ConfigDict(populate_by_name=True)


class StyleDNARead(BaseModel):
    id: str
    product_id: str
    dna_vector: Optional[List[float]]
    model_name: Optional[str]
    model_version: Optional[str]
    metadata_: Optional[dict] = Field(
        default=None,
        validation_alias=AliasChoices("metadata_", "metadata"),
        serialization_alias="metadata",
    )

    model_config = ConfigDict(from_attributes=True, populate_by_name=True)


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.get("/{product_id}", response_model=StyleDNARead)
def get_style_dna(product_id: str, db: Session = Depends(get_session)):
    """Retrieve Style DNA for a single product."""
    dna = db.query(StyleDNA).filter(StyleDNA.product_id == product_id).first()
    if not dna:
        raise HTTPException(status_code=404, detail="Style DNA not found for this product")
    return dna


@router.post("/", response_model=StyleDNARead, status_code=201)
def upsert_style_dna(
    payload: StyleDNACreate,
    _user: dict = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    """Create or upsert Style DNA for a product.

    If a record for ``product_id`` already exists it is updated in place.
    """
    existing = (
        db.query(StyleDNA).filter(StyleDNA.product_id == payload.product_id).first()
    )
    if existing:
        existing.dna_vector = payload.dna_vector
        existing.model_name = payload.model_name
        existing.model_version = payload.model_version
        existing.metadata_ = payload.metadata_
        db.commit()
        db.refresh(existing)
        return existing

    dna = StyleDNA(
        product_id=payload.product_id,
        dna_vector=payload.dna_vector,
        model_name=payload.model_name,
        model_version=payload.model_version,
        metadata_=payload.metadata_,
    )
    db.add(dna)
    db.commit()
    db.refresh(dna)
    return dna


@router.delete("/{product_id}", status_code=204)
def delete_style_dna(
    product_id: str,
    _user: dict = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    """Delete Style DNA for a product."""
    dna = db.query(StyleDNA).filter(StyleDNA.product_id == product_id).first()
    if not dna:
        raise HTTPException(status_code=404, detail="Style DNA not found")
    db.delete(dna)
    db.commit()


@router.get("/similar/{product_id}")
def similar_by_dna(
    product_id: str,
    limit: int = Query(10, ge=1, le=50),
    db: Session = Depends(get_session),
):
    """Return the top-N products most similar by Style DNA vector (cosine).

    Falls back to returning an empty list when pgvector is unavailable
    (SQLite dev mode).
    """
    source = db.query(StyleDNA).filter(StyleDNA.product_id == product_id).first()
    if not source or source.dna_vector is None:
        raise HTTPException(status_code=404, detail="Style DNA not found for this product")

    try:
        # pgvector cosine distance operator <=>
        results = (
            db.query(StyleDNA)
            .filter(StyleDNA.product_id != product_id, StyleDNA.dna_vector.isnot(None))
            .order_by(StyleDNA.dna_vector.op("<=>")(source.dna_vector))
            .limit(limit)
            .all()
        )
        return [{"product_id": r.product_id, "model_name": r.model_name} for r in results]
    except Exception:
        logger.warning("Vector similarity query failed (pgvector not available?). Returning empty list.")
        return []
