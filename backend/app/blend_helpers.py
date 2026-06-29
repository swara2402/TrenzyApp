from __future__ import annotations

from typing import Any

from sqlalchemy.orm import Session

from .models import GroupSwipe, Product


def _product_dict(product: Product | None) -> dict[str, Any] | None:
    if not product:
        return None
    return {
        "id": product.id,
        "title": product.name,
        "subtitle": product.brand or product.category,
        "price": product.price or 0,
        "matchScore": 85,
        "gradient": ["F4F1E8", "E4DBBC"],
        "silhouetteColor": "B2A257",
        "category": product.category,
    }


def compute_blend_results(db: Session, group_id: str) -> dict[str, Any]:
    """Aggregate swipes, rank products, and resolve ties per category."""
    swipes = db.query(GroupSwipe).filter(GroupSwipe.group_id == group_id).all()

    stats: dict[str, dict[str, Any]] = {}
    for swipe in swipes:
        entry = stats.setdefault(
            swipe.product_id,
            {"totalScore": 0, "loveCount": 0, "likeCount": 0, "dislikeCount": 0},
        )
        entry["totalScore"] += swipe.score
        if swipe.score >= 2:
            entry["loveCount"] += 1
        elif swipe.score == 1:
            entry["likeCount"] += 1
        elif swipe.score < 0:
            entry["dislikeCount"] += 1

    ranked: list[dict[str, Any]] = []
    for product_id, agg in stats.items():
        product = db.query(Product).filter(Product.id == product_id).first()
        product_data = _product_dict(product)
        if not product_data:
            continue
        ranked.append(
            {
                "product": product_data,
                "score": agg["totalScore"],
                "loveCount": agg["loveCount"],
                "likeCount": agg["likeCount"],
                "dislikeCount": agg["dislikeCount"],
            }
        )

    ranked.sort(
        key=lambda item: (
            item["score"],
            item["loveCount"],
            item["likeCount"],
            item["product"].get("matchScore") or 0,
        ),
        reverse=True,
    )

    categories = ["Dresses", "Shoes", "Accessories", "Tops", "Bottoms"]
    categorized: dict[str, list[dict[str, Any]]] = {cat: [] for cat in categories}

    for item in ranked:
        cat = item["product"].get("category") or "Dresses"
        if cat not in categorized:
            categorized[cat] = []
        categorized[cat].append(
            {
                "product": {
                    "id": item["product"]["id"],
                    "title": item["product"]["title"],
                    "price": item["product"]["price"],
                    "gradient": item["product"].get("gradient"),
                    "silhouetteColor": item["product"].get("silhouetteColor"),
                },
                "score": item["score"],
                "loveCount": item["loveCount"],
                "likeCount": item["likeCount"],
            }
        )

    winners: dict[str, Any] = {}
    for cat, items in categorized.items():
        if not items:
            continue
        top_score = items[0]["score"]
        tied = [p for p in items if p["score"] == top_score]
        winners[cat] = {
            "products": tied,
            "isTie": len(tied) > 1,
            "score": top_score,
        }

    overall_winner = ranked[0] if ranked else None
    overall_tied = False
    if ranked:
        top = ranked[0]["score"]
        overall_tied = sum(1 for r in ranked if r["score"] == top) > 1

    return {
        "blendRecommendations": categorized,
        "winners": winners,
        "overallWinner": overall_winner,
        "overallTie": overall_tied,
        "totalSwipes": len(swipes),
    }
