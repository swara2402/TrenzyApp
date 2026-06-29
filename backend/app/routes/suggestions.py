from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy import select, or_
from typing import Optional

from ..db import SessionLocal
from ..firebase_auth import verify_firebase_token
from ..models import Product

router = APIRouter(prefix="/api", tags=["suggestions"])


class ReasoningRequest(BaseModel):
    query: str
    option: dict
    socialApproval: Optional[int] = None
    aiScore: Optional[int] = None


def generate_reasoning(query: str, option: dict, socialApproval: int, aiScore: int) -> str:
    query_lower = (query or "").lower()
    price_num = 0.0
    if option.get("price"):
        try:
            price_num = float("".join([c for c in str(option.get("price")) if c.isdigit() or c == "."]))
        except Exception:
            price_num = 0.0

    reasons: list[str] = []

    if aiScore is None:
        aiScore = 0

    if aiScore >= 90:
        reasons.append(f"A {aiScore}% AI match score places this firmly at the top of your options.")
    elif aiScore >= 80:
        reasons.append(f"At {aiScore}% AI match, this aligns strongly with your stated vibe.")
    else:
        reasons.append(f"With a {aiScore}% match score, this is a credible pick for your intent.")

    if socialApproval >= 60:
        reasons.append(f"Your social room gave it {socialApproval}% approval — a clear group favourite.")
    elif socialApproval > 0:
        reasons.append(f"The room had mixed votes, but {socialApproval}% supported this option.")

    if 0 < price_num < 80:
        reasons.append(f"At Rs {price_num:.0f}, it delivers strong value without stretching your budget.")
    elif 80 <= price_num < 150:
        reasons.append("The price sits in a premium-but-accessible range, justifying the quality.")
    elif price_num >= 150:
        reasons.append("It is an investment piece — justified by its uniqueness and match score.")

    if any(k in query_lower for k in ["date", "night", "dinner"]):
        reasons.append("Its elevated aesthetic is calibrated for evening occasions.")
    elif any(k in query_lower for k in ["casual", "brunch", "weekend"]):
        reasons.append("The relaxed structure makes it effortless for daytime social settings.")
    elif any(k in query_lower for k in ["office", "work", "formal"]):
        reasons.append("Clean lines transition seamlessly from desk to after-hours.")
    elif any(k in query_lower for k in ["airport", "travel"]):
        reasons.append("Comfort-forward design keeps you styled through long transit hours.")
    elif any(k in query_lower for k in ["party", "event"]):
        reasons.append("The statement silhouette is built for high-energy social environments.")

    return " ".join(reasons)


_DEFAULTS = [
    {
        "id": "ethereal-summer-set-api",
        "name": "Ethereal Summer Set",
        "subtitle": "Best for your style mood",
        "price": "Rs 124.00",
        "matchScore": 95,
        "gradient": ["F4F1E8", "E4DBBC"],
        "silhouetteColor": "B2A257",
        "category": "Dresses",
    },
    {
        "id": "silk-gold-accents-api",
        "name": "Silk & Gold Accents",
        "subtitle": "Curated Essentials Server-Side",
        "price": "Rs 89.00",
        "matchScore": 92,
        "gradient": ["59D7F2", "D5B16A"],
        "silhouetteColor": "FFFFFF",
        "category": "Dresses",
    },
    {
        "id": "soft-lavender-knit-api",
        "name": "Soft Lavender Knit",
        "subtitle": "Backend Weekend Wear",
        "price": "Rs 72.00",
        "matchScore": 88,
        "gradient": ["243447", "0B1118"],
        "silhouetteColor": "EFBAAE",
        "category": "Tops",
    },
]


def _product_to_suggestion(p):
    if isinstance(p, dict):
        return {
            "id": p.get("id", ""),
            "title": p.get("title") or p.get("name", ""),
            "subtitle": p.get("subtitle"),
            "price": p.get("price"),
            "matchScore": p.get("matchScore", 85),
            "gradient": p.get("gradient", ["F4F1E8", "E4DBBC"]),
            "silhouetteColor": p.get("silhouetteColor", "B2A257"),
            "category": p.get("category"),
        }
    return {
        "id": p.id,
        "title": p.name,
        "subtitle": p.brand or p.category,
        "price": f"Rs {p.price or 0}",
        "matchScore": 85,
        "gradient": ["F4F1E8", "E4DBBC"],
        "silhouetteColor": "B2A257",
        "category": p.category,
    }


@router.get("/suggestions")
def suggestions(request: Request, query: str = "your style mood"):
    verify_firebase_token(request)
    normalized_query = query.strip() or "your style mood"

    db = SessionLocal()
    try:
        query_lower = normalized_query.lower()
        filters = []
        if any(k in query_lower for k in ["dress", "dresses", "evening", "party"]):
            filters.append(Product.category == "Dresses")
        if any(k in query_lower for k in ["shoe", "shoes", "sneaker", "sneakers", "boots", "heels", "stilettos"]):
            filters.append(Product.category == "Shoes")
        if any(k in query_lower for k in ["accessory", "accessories", "bag", "watch", "sunglasses"]):
            filters.append(Product.category == "Accessories")
        if any(k in query_lower for k in ["top", "tops", "shirt", "blouse", "sweater"]):
            filters.append(Product.category == "Tops")
        if any(k in query_lower for k in ["bottom", "bottoms", "trousers", "jeans", "shorts"]):
            filters.append(Product.category == "Bottoms")

        stmt = select(Product)
        if filters:
            stmt = stmt.where(or_(*filters))
        
        stmt = stmt.limit(3)
        products = list(db.execute(stmt).scalars().all())

        if not products:
            if db.query(Product).count() == 0:
                for p in _DEFAULTS:
                    db.add(Product(
                        id=p["id"],
                        name=p["name"],
                        category=p.get("category"),
                        price=0,
                    ))
                db.commit()
            products = _DEFAULTS

        return {
            "suggestions": [_product_to_suggestion(p) for p in products]
        }
    finally:
        db.close()


@router.post("/suggestions/reasoning")
def reasoning(payload: ReasoningRequest, request: Request):
    verify_firebase_token(request)
    reasoning_text = generate_reasoning(
        payload.query,
        payload.option,
        payload.socialApproval or 0,
        payload.aiScore or 0,
    )
    return {"reasoning": reasoning_text}