"""Shared shopping priority scoring logic for feed and recommendations.

Maps user shopping priorities (from onboarding) to SQLAlchemy scoring
expressions that boost matching products in query results.
"""
from __future__ import annotations

from typing import Optional

import sqlalchemy
from sqlalchemy import case, func

from ..models import Product


def _cap_expr(expr: sqlalchemy.ClauseElement):
    """Cap a score at 1.0 in a dialect-portable way.

    PostgreSQL has ``LEAST``; SQLite (dev fallback) has ``MIN``.
    """
    from ..db import engine
    if getattr(engine.dialect, "name", "") == "sqlite":
        return func.min(expr, 1.0)
    return func.least(expr, func.cast(1.0, sqlalchemy.Float))


def priority_score_expr(priorities: list[str]) -> Optional[sqlalchemy.ClauseElement]:
    """Build a combined priority boost expression from the user's priorities.

    Each priority maps to a 0-1 score based on how well a product matches.
    The total is the sum of all individual scores, capped at 1.0.

    Priority mapping:
    - Affordable price: boost low-price products
    - Quality: boost high-rated products
    - Latest trends: boost products with style tags
    - Brand: boost products with known brand names
    - Unique styles: boost products with unique style tags
    - Comfort: boost casual/athletic products
    - Versatility: boost products with occasion tags
    - Sustainability: boost products with tags (fallback)
    """
    if not priorities:
        return None

    boosts = []
    for p in priorities:
        p_lower = p.lower()
        if 'affordable' in p_lower or 'price' in p_lower:
            boosts.append(case(
                (Product.price < 500, 1.0),
                (Product.price < 1000, 0.8),
                (Product.price < 2000, 0.6),
                (Product.price < 5000, 0.4),
                (Product.price < 10000, 0.2),
                else_=0.1,
            ))
        elif 'quality' in p_lower:
            boosts.append(case(
                (Product.rating >= 4.5, 1.0),
                (Product.rating >= 4.0, 0.8),
                (Product.rating >= 3.5, 0.6),
                (Product.rating >= 3.0, 0.4),
                else_=0.2,
            ))
        elif 'trend' in p_lower:
            boosts.append(case(
                (Product.style_tags.isnot(None), 0.8),
                else_=0.3,
            ))
        elif 'brand' in p_lower:
            boosts.append(case(
                (Product.brand.isnot(None), 0.8),
                else_=0.2,
            ))
        elif 'unique' in p_lower or 'style' in p_lower:
            boosts.append(case(
                (Product.style_tags.isnot(None), 0.9),
                else_=0.2,
            ))
        elif 'comfort' in p_lower:
            boosts.append(case(
                (Product.usage.ilike('%casual%'), 0.9),
                (Product.usage.ilike('%sport%'), 0.8),
                else_=0.3,
            ))
        elif 'versatility' in p_lower:
            boosts.append(case(
                (Product.occasion_tags.isnot(None), 0.8),
                else_=0.3,
            ))
        elif 'sustain' in p_lower:
            boosts.append(case(
                (Product.tags.isnot(None), 0.6),
                else_=0.1,
            ))

    if not boosts:
        return None

    combined = boosts[0]
    for b in boosts[1:]:
        combined = combined + b
    return _cap_expr(combined)
