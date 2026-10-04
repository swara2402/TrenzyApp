"""Online feedback loop for recommendations.

Tracks recommendation impressions, clicks, and conversions for online learning.
"""

from __future__ import annotations

import logging
from typing import List, Optional, Dict
from datetime import datetime
from sqlalchemy.orm import Session

from ..models_ai import InteractionEvent, RecommendationEvent
from ...models import User, Product

logger = logging.getLogger(__name__)


class FeedbackLoop:
    """Online feedback loop for recommendation learning."""

    def __init__(self):
        """Initialize feedback loop."""
        pass

    def log_impression(
        self,
        db: Session,
        user_id: int,
        product_ids: List[int],
        model_version: Optional[str] = None,
        source: Optional[str] = None,
        context: Optional[Dict] = None,
    ):
        """Log recommendation impressions.

        Args:
            db: Database session
            user_id: User ID
            product_ids: List of recommended product IDs
            model_version: Model version used
            source: Source of recommendations (ml, baseline, popularity)
            context: Additional context
        """
        # Log recommendation event
        rec_event = RecommendationEvent(
            user_id=user_id,
            product_ids=product_ids,
            model_version=model_version,
            source=source,
            context=context or {},
            created_at=datetime.utcnow(),
        )
        db.add(rec_event)

        # Log individual impression events
        for product_id in product_ids:
            impression_event = InteractionEvent(
                user_id=user_id,
                event_type="recommendation_impression",
                entity_type="product",
                entity_id=product_id,
                context={
                    "model_version": model_version,
                    "source": source,
                    "rec_event_id": rec_event.id,
                },
                created_at=datetime.utcnow(),
            )
            db.add(impression_event)

        db.commit()
        logger.info(f"Logged {len(product_ids)} impressions for user {user_id}")

    def log_click(
        self,
        db: Session,
        user_id: int,
        product_id: int,
        model_version: Optional[str] = None,
        source: Optional[str] = None,
        position: Optional[int] = None,
    ):
        """Log recommendation click.

        Args:
            db: Database session
            user_id: User ID
            product_id: Clicked product ID
            model_version: Model version used
            source: Source of recommendations
            position: Position in recommendation list
        """
        click_event = InteractionEvent(
            user_id=user_id,
            event_type="recommendation_click",
            entity_type="product",
            entity_id=product_id,
            context={
                "model_version": model_version,
                "source": source,
                "position": position,
            },
            created_at=datetime.utcnow(),
        )
        db.add(click_event)
        db.commit()
        logger.info(f"Logged click for product {product_id} by user {user_id}")

    def log_conversion(
        self,
        db: Session,
        user_id: int,
        product_id: int,
        model_version: Optional[str] = None,
        source: Optional[str] = None,
    ):
        """Log recommendation conversion (purchase).

        Args:
            db: Database session
            user_id: User ID
            product_id: Purchased product ID
            model_version: Model version used
            source: Source of recommendations
        """
        conversion_event = InteractionEvent(
            user_id=user_id,
            event_type="recommendation_conversion",
            entity_type="product",
            entity_id=product_id,
            context={
                "model_version": model_version,
                "source": source,
            },
            created_at=datetime.utcnow(),
        )
        db.add(conversion_event)
        db.commit()
        logger.info(f"Logged conversion for product {product_id} by user {user_id}")

    def log_skip(
        self,
        db: Session,
        user_id: int,
        product_id: int,
        model_version: Optional[str] = None,
        source: Optional[str] = None,
        position: Optional[int] = None,
    ):
        """Log recommendation skip (user scrolled past without engaging).

        Args:
            db: Database session
            user_id: User ID
            product_id: Skipped product ID
            model_version: Model version used
            source: Source of recommendations
            position: Position in recommendation list
        """
        skip_event = InteractionEvent(
            user_id=user_id,
            event_type="recommendation_skip",
            entity_type="product",
            entity_id=product_id,
            context={
                "model_version": model_version,
                "source": source,
                "position": position,
            },
            created_at=datetime.utcnow(),
        )
        db.add(skip_event)
        db.commit()
        logger.info(f"Logged skip for product {product_id} by user {user_id}")

    def get_feedback_metrics(
        self,
        db: Session,
        model_version: Optional[str] = None,
        source: Optional[str] = None,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
    ) -> Dict[str, float]:
        """Get feedback metrics for recommendations.

        Args:
            db: Database session
            model_version: Filter by model version
            source: Filter by source
            start_date: Start date for metrics
            end_date: End date for metrics

        Returns:
            Dictionary of metrics
        """
        from sqlalchemy import func

        # Build base query
        query = db.query(InteractionEvent).filter(
            InteractionEvent.event_type.in_([
                "recommendation_impression",
                "recommendation_click",
                "recommendation_conversion",
            ])
        )

        if model_version:
            query = query.filter(
                InteractionEvent.context["model_version"].astext == model_version
            )

        if source:
            query = query.filter(
                InteractionEvent.context["source"].astext == source
            )

        if start_date:
            query = query.filter(InteractionEvent.created_at >= start_date)

        if end_date:
            query = query.filter(InteractionEvent.created_at <= end_date)

        # Count events
        impressions = query.filter(
            InteractionEvent.event_type == "recommendation_impression"
        ).count()

        clicks = query.filter(
            InteractionEvent.event_type == "recommendation_click"
        ).count()

        conversions = query.filter(
            InteractionEvent.event_type == "recommendation_conversion"
        ).count()

        # Calculate metrics
        click_through_rate = clicks / impressions if impressions > 0 else 0.0
        conversion_rate = conversions / clicks if clicks > 0 else 0.0

        return {
            "impressions": float(impressions),
            "clicks": float(clicks),
            "conversions": float(conversions),
            "click_through_rate": click_through_rate,
            "conversion_rate": conversion_rate,
        }
