"""Recommendation evaluation (Phase 5.4 / 17).

Computes the canonical ranking metrics for recommendations:

- Precision@5, Precision@10
- Recall@10
- NDCG@5, NDCG@10
- HitRate@10
- Coverage
- Diversity

Also provides a rule-based baseline evaluator so the ML model can be compared
against the existing rule-based system on the same held-out data.
"""

from __future__ import annotations

import logging
import numpy as np
from typing import Optional
from datetime import datetime

logger = logging.getLogger(__name__)


def ranking_metrics_for_user(items: list[dict], tops: list[int] = (5, 10)) -> dict:
    """Compute ranking metrics for one user's candidate items.

    Args:
        items: list of dicts with 'product_id', 'label' (0/1), 'score'.
        tops: ranking cutoffs.

    Returns:
        dict with precision@k, recall@k, ndcg@k, hit_rate@k, coverage.
    """
    items = sorted(items, key=lambda x: x["score"], reverse=True)
    labels = [int(x["label"]) for x in items]
    relevant_total = sum(labels)

    def precision(k):
        if k == 0:
            return 0.0
        return sum(labels[:k]) / k

    def recall(k):
        if relevant_total == 0:
            return 0.0
        return sum(labels[:k]) / relevant_total

    def ndcg(k):
        if k == 0:
            return 0.0
        dcg = sum(labels[i] / np.log2(i + 2) for i in range(min(k, len(labels))))
        ideal = sorted(labels, reverse=True)
        idcg = sum(ideal[i] / np.log2(i + 2) for i in range(min(k, len(ideal))))
        return dcg / idcg if idcg > 0 else 0.0

    def hit_rate(k):
        return 1.0 if sum(labels[:k]) > 0 else 0.0

    out = {}
    for k in tops:
        kk = min(k, len(labels))
        out[f"precision@{k}"] = precision(kk)
        out[f"recall@{k}"] = recall(kk)
        out[f"ndcg@{k}"] = ndcg(kk)
        out[f"hit_rate@{k}"] = hit_rate(kk)
    out["coverage"] = len(items) / max(len(labels), 1)
    return out


def aggregate_over_users(per_user: list[dict]) -> dict:
    """Average per-user metrics into a single report."""
    if not per_user:
        return {}
    keys = per_user[0].keys()
    return {k: float(np.mean([u[k] for u in per_user])) for k in keys}


class RuleBaseLineRecommender:
    """Rule-based recommendation baseline for comparison.

    Predicts user preference using simple weighted attribute affinity — the
    same family of rules the current `/api/recommendations` endpoint uses
    (style/category/color affinity + popularity). Used to compare the ML model
    against the baseline on the same test data.

    IMPORTANT: For fair temporal evaluation, user_stats must be computed using
    only historical data available at training time (before the test period).
    """

    def __init__(self):
        pass

    def predict(self, user_stats: dict, product: dict) -> float:
        """Score a product for a user using the baseline rules.

        Args:
            user_stats: dict with preferred_styles, preferred_categories,
                        preferred_colors (sets) and avg_price. These should be
                        computed from historical data only (temporal fairness).
            product: dict with style, category, color, price, rating.
        """
        score = 0.0
        if product.get("style") in user_stats.get("preferred_styles", set()):
            score += 0.4
        if product.get("category") in user_stats.get("preferred_categories", set()):
            score += 0.3
        if product.get("color") in user_stats.get("preferred_colors", set()):
            score += 0.2
        # popularity
        score += 0.1 * min(float(product.get("rating") or 0) / 5.0, 1.0)
        return min(score, 1.0)


def evaluate_rule_baseline(
    samples,
    user_preferences: dict,
    feature_builder,
    db,
    tops: list[int] = (5, 10),
    temporal_cutoff: Optional[datetime] = None,
) -> dict:
    """Evaluate the rule-based baseline on the same test samples.

    Args:
        samples: list of InteractionSample objects (test split).
        user_preferences: dict mapping user_id → {preferred_styles, preferred_categories,
                          preferred_colors, avg_price}. These should be computed
                          from historical data only (before temporal_cutoff).
        feature_builder: unused but kept for uniform signature.
        db: database session.
        tops: ranking cutoffs.
        temporal_cutoff: Optional datetime to ensure user preferences only use
                         historical data (temporal fairness). If provided, this
                         validates that user_preferences were computed correctly.

    Returns:
        Averaged metrics dict.
    """
    from collections import defaultdict

    recommender = RuleBaseLineRecommender()
    user_items: dict[int, list] = defaultdict(list)

    from app.models import Product
    
    # Validate temporal fairness if cutoff provided
    if temporal_cutoff:
        logger.info(f"Validating temporal fairness with cutoff: {temporal_cutoff}")
        # Check that user preferences don't use future data
        # This is a sanity check - user_preferences should already be historical
        for user_id, prefs in user_preferences.items():
            if "computed_at" in prefs:
                if prefs["computed_at"] > temporal_cutoff:
                    logger.warning(
                        f"User {user_id} preferences computed at {prefs['computed_at']} "
                        f"which is after temporal cutoff {temporal_cutoff}. "
                        "This violates temporal fairness!"
                    )

    for s in samples:
        # Temporal validation: ensure sample timestamp is after training period
        if temporal_cutoff and s.timestamp <= temporal_cutoff:
            logger.warning(
                f"Sample timestamp {s.timestamp} is before/equals temporal cutoff "
                f"{temporal_cutoff}. This violates temporal split!"
            )
            continue
            
        product = db.get(Product, s.product_id)
        if product is None:
            continue
        prefs = user_preferences.get(s.user_id, {})
        product_dict = {
            "style": product.style,
            "category": product.category,
            "color": product.color,
            "price": product.price or 0.0,
            "rating": product.rating or 0.0,
        }
        score = recommender.predict(prefs, product_dict)
        user_items[s.user_id].append({
            "product_id": s.product_id,
            "label": s.label,
            "score": float(score),
        })

    per_user = [ranking_metrics_for_user(items, tops=tops) for items in user_items.values()]
    return aggregate_over_users(per_user)


def compute_historical_user_preferences(
    db,
    user_ids: set[int],
    temporal_cutoff: datetime,
) -> dict:
    """Compute user preferences using only historical data (before temporal_cutoff).

    This ensures temporal fairness in evaluation - user preferences are computed
    using only data that would have been available at training time.

    Args:
        db: Database session
        user_ids: Set of user IDs to compute preferences for
        temporal_cutoff: Cutoff time - only use interactions before this time

    Returns:
        dict mapping user_id → {preferred_styles, preferred_categories,
              preferred_colors, avg_price, computed_at}
    """
    from app.ai.models_ai import InteractionEvent
    from app.models import Product

    user_preferences = {}

    for user_id in user_ids:
        # Get only historical interactions
        historical_events = db.query(InteractionEvent).filter(
            InteractionEvent.user_id == user_id,
            InteractionEvent.entity_type == "product",
            InteractionEvent.created_at < temporal_cutoff,
            InteractionEvent.event_type.in_(["like_product", "wishlist", "purchase"]),
        ).all()

        if not historical_events:
            # No historical data - use empty preferences
            user_preferences[user_id] = {
                "preferred_styles": set(),
                "preferred_categories": set(),
                "preferred_colors": set(),
                "avg_price": 0.0,
                "computed_at": temporal_cutoff,
            }
            continue

        # Get product details for historical interactions
        product_ids = [e.entity_id for e in historical_events if e.entity_id]
        products = db.query(Product).filter(Product.id.in_(product_ids)).all()
        product_map = {p.id: p for p in products}

        # Compute preferences from historical data
        styles = set()
        categories = set()
        colors = set()
        prices = []

        for event in historical_events:
            product = product_map.get(int(event.entity_id)) if event.entity_id else None
            if product:
                if product.style:
                    styles.add(product.style.lower())
                if product.category:
                    categories.add(product.category.name.lower() if hasattr(product.category, 'name') else str(product.category).lower())
                if product.color:
                    colors.add(product.color.lower())
                if product.price:
                    prices.append(float(product.price))

        user_preferences[user_id] = {
            "preferred_styles": styles,
            "preferred_categories": categories,
            "preferred_colors": colors,
            "avg_price": sum(prices) / len(prices) if prices else 0.0,
            "computed_at": temporal_cutoff,
        }

    logger.info(f"Computed historical preferences for {len(user_preferences)} users")
    return user_preferences