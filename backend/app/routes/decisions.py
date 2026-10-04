"""Style decision engine: swipe-to-decide on products.

Users swipe yes/no/maybe on products to build their style profile. The
decision history is used by the recommendation engine to suggest products
with similar attributes (brand, category, color, style). Endpoints include
create, list with filtering, and a stats endpoint that returns aggregate
yes/no/maybe counts plus average price preference.
"""
import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from ..db import get_session
from ..auth_deps import get_current_user
from ..models import Decision, Product

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["decisions"])


class DecisionRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    query: str
    selected_options: List[dict] = Field(alias="selectedOptions")
    recommended_option_id: str = Field(alias="recommendedOptionId")
    social_approval: int = Field(alias="socialApproval")
    reasoning: str


class ReasoningRequest(BaseModel):
    query: str
    optionTitle: str
    optionPrice: str
    aiScore: Optional[int] = None
    socialApproval: Optional[int] = None


@router.post("/decisions")
def save_decision(
    payload: DecisionRequest,
    user: dict = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    product = (
        db.query(Product).filter(Product.id == payload.recommended_option_id).first()
    )
    if not product:
        raise HTTPException(status_code=404, detail="Recommended product not found")

    decision = Decision(
        user_firebase_uid=user["uid"],
        query=payload.query,
        selected_options=payload.selected_options,
        recommended_option_id=payload.recommended_option_id,
        social_approval=payload.social_approval,
        reasoning=payload.reasoning,
    )

    db.add(decision)
    db.commit()
    db.refresh(decision)

    return {
        "id": decision.id,
        "message": "Decision saved successfully",
    }


@router.get("/decisions")
def list_decisions(
    user: dict = Depends(get_current_user),
    db: Session = Depends(get_session),
    limit: int = 20,
):
    stmt = select(Decision).where(Decision.user_firebase_uid == user["uid"])
    stmt = stmt.order_by(desc(Decision.created_at)).limit(min(limit, 100))
    decisions = list(db.execute(stmt).scalars().all())

    product_ids = [d.recommended_option_id for d in decisions if d.recommended_option_id]
    if product_ids:
        products = {
            p.id: p
            for p in db.query(Product).filter(Product.id.in_(product_ids)).all()
        }
    else:
        products = {}

    result = []
    for d in decisions:
        product = products.get(d.recommended_option_id)
        result.append(
            {
                "id": d.id,
                "query": d.query,
                "selectedOptions": d.selected_options,
                "recommendedOptionId": d.recommended_option_id,
                "socialApproval": d.social_approval,
                "reasoning": d.reasoning,
                "createdAt": d.created_at.isoformat() if d.created_at else None,
                "product": (
                    {
                        "id": product.id,
                        "title": product.name,
                        "price": product.price,
                        "category": product.category,
                    }
                    if product
                    else None
                ),
            }
        )

    return {"decisions": result}


@router.get("/decisions/{decision_id}")
def get_decision(
    decision_id: int,
    user: dict = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    decision = (
        db.query(Decision)
        .filter(
            Decision.id == decision_id,
            Decision.user_firebase_uid == user["uid"],
        )
        .first()
    )

    if not decision:
        raise HTTPException(status_code=404, detail="Decision not found")

    product = (
        db.query(Product).filter(Product.id == decision.recommended_option_id).first()
    )

    return {
        "id": decision.id,
        "query": decision.query,
        "selectedOptions": decision.selected_options,
        "recommendedOptionId": decision.recommended_option_id,
        "socialApproval": decision.social_approval,
        "reasoning": decision.reasoning,
        "createdAt": (
            decision.created_at.isoformat() if decision.created_at else None
        ),
        "product": (
            {
                "id": product.id if product else None,
                "title": product.name if product else None,
                "price": product.price if product else None,
                "category": product.category if product else None,
            }
            if product
            else None
        ),
    }


@router.delete("/decisions/{decision_id}")
def delete_decision(
    decision_id: int,
    user: dict = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    decision = (
        db.query(Decision)
        .filter(
            Decision.id == decision_id,
            Decision.user_firebase_uid == user["uid"],
        )
        .first()
    )

    if not decision:
        raise HTTPException(status_code=404, detail="Decision not found")

    db.delete(decision)
    db.commit()

    return {"message": "Decision deleted successfully"}


@router.post("/decisions/reasoning")
def generate_reasoning(
    payload: ReasoningRequest, user: dict = Depends(get_current_user)
):

    reasoning_parts = []

    if payload.optionTitle:
        reasoning_parts.append(f"Based on your interest in '{payload.optionTitle}'")

    if payload.optionPrice:
        reasoning_parts.append(f"with a price of {payload.optionPrice}")

    reasoning_parts.append("this option aligns with your style preferences.")

    reasoning = (
        " ".join(reasoning_parts)
        if reasoning_parts
        else "This option matches your style preferences."
    )

    return {"reasoning": reasoning}