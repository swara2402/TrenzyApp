from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy import select, desc
from typing import Optional, List
from datetime import datetime

from ..db import SessionLocal
from ..firebase_auth import verify_firebase_token
from ..models import Decision, Product

router = APIRouter(prefix="/api", tags=["decisions"])


class DecisionRequest(BaseModel):
    query: str
    selectedOptions: List[dict]
    recommendedOptionId: str
    socialApproval: int
    reasoning: str


class ReasoningRequest(BaseModel):
    query: str
    optionTitle: str
    optionPrice: str
    aiScore: Optional[int] = None
    socialApproval: Optional[int] = None


@router.post("/decisions/decisions")
def save_decision(request: Request, payload: DecisionRequest):
    user = verify_firebase_token(request)

    db = SessionLocal()
    try:
        product = db.query(Product).filter(Product.id == payload.recommendedOptionId).first()
        if not product:
            raise HTTPException(status_code=404, detail="Recommended product not found")

        decision = Decision(
            user_firebase_uid=user["uid"],
            query=payload.query,
            selectedOptions=payload.selectedOptions,
            recommendedOptionId=payload.recommendedOptionId,
            socialApproval=payload.socialApproval,
            reasoning=payload.reasoning,
        )

        db.add(decision)
        db.commit()
        db.refresh(decision)

        return {
            "id": decision.id,
            "message": "Decision saved successfully",
        }
    finally:
        db.close()


@router.get("/decisions")
def list_decisions(request: Request, limit: int = 20):
    user = verify_firebase_token(request)

    db = SessionLocal()
    try:
        stmt = select(Decision).where(Decision.user_firebase_uid == user["uid"])
        stmt = stmt.order_by(desc(Decision.created_at)).limit(min(limit, 100))
        decisions = list(db.execute(stmt).scalars().all())

        result = []
        for d in decisions:
            product = db.query(Product).filter(Product.id == d.recommendedOptionId).first()
            result.append({
                "id": d.id,
                "query": d.query,
                "selectedOptions": d.selectedOptions,
                "recommendedOptionId": d.recommendedOptionId,
                "socialApproval": d.socialApproval,
                "reasoning": d.reasoning,
                "createdAt": d.created_at.isoformat() if d.created_at else None,
                "product": {
                    "id": product.id if product else None,
                    "title": product.name if product else None,
                    "price": product.price if product else None,
                    "category": product.category if product else None,
                } if product else None,
            })

        return {"decisions": result}
    finally:
        db.close()


@router.get("/decisions/{decision_id}")
def get_decision(request: Request, decision_id: int):
    user = verify_firebase_token(request)

    db = SessionLocal()
    try:
        decision = db.query(Decision).filter(
            Decision.id == decision_id,
            Decision.user_firebase_uid == user["uid"],
        ).first()

        if not decision:
            raise HTTPException(status_code=404, detail="Decision not found")

        product = db.query(Product).filter(Product.id == decision.recommendedOptionId).first()

        return {
            "id": decision.id,
            "query": decision.query,
            "selectedOptions": decision.selectedOptions,
            "recommendedOptionId": decision.recommendedOptionId,
            "socialApproval": decision.socialApproval,
            "reasoning": decision.reasoning,
            "createdAt": decision.created_at.isoformat() if decision.created_at else None,
            "product": {
                "id": product.id if product else None,
                "title": product.name if product else None,
                "price": product.price if product else None,
                "category": product.category if product else None,
            } if product else None,
        }
    finally:
        db.close()


@router.delete("/decisions/{decision_id}")
def delete_decision(request: Request, decision_id: int):
    user = verify_firebase_token(request)

    db = SessionLocal()
    try:
        decision = db.query(Decision).filter(
            Decision.id == decision_id,
            Decision.user_firebase_uid == user["uid"],
        ).first()

        if not decision:
            raise HTTPException(status_code=404, detail="Decision not found")

        db.delete(decision)
        db.commit()

        return {"message": "Decision deleted successfully"}
    finally:
        db.close()


@router.post("/decisions/reasoning")
def generate_reasoning(request: Request, payload: ReasoningRequest):
    verify_firebase_token(request)

    reasoning_parts = []

    if payload.optionTitle:
        reasoning_parts.append(f"Based on your interest in '{payload.optionTitle}'")

    if payload.optionPrice:
        reasoning_parts.append(f"with a price of {payload.optionPrice}")

    reasoning_parts.append("this option aligns with your style preferences.")

    reasoning = " ".join(reasoning_parts) if reasoning_parts else "This option matches your style preferences."

    return {"reasoning": reasoning}