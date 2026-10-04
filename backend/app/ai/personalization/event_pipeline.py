"""Interaction event pipeline for behavioral learning.

Captures and processes user interactions to feed the AI learning system.
"""

from __future__ import annotations

from typing import Optional, Dict, Any
import logging
import uuid
from datetime import datetime

from sqlalchemy.orm import Session

from ...models import User
from ..models_ai import InteractionEvent
from ..personalization.style_dna import StyleDNAExtractor

logger = logging.getLogger(__name__)


class EventPipeline:
    """Pipeline for capturing and processing user interaction events."""

    # Event types that should be tracked
    TRACKED_EVENTS = [
        "view_product",
        "like_product",
        "dislike_product",
        "swipe_right",
        "swipe_left",
        "wishlist",
        "remove_wishlist",
        "search",
        "open_outfit",
        "save_outfit",
        "purchase",
        "blend_vote",
        "share",
    ]

    def __init__(
        self,
        style_extractor: Optional[StyleDNAExtractor] = None,
        auto_update_style_dna: bool = True,
        update_threshold: int = 10,
    ):
        """Initialize event pipeline.

        Args:
            style_extractor: Style DNA extractor instance
            auto_update_style_dna: Whether to auto-update Style DNA after events
            update_threshold: Number of events before triggering Style DNA update
        """
        self.style_extractor = style_extractor or StyleDNAExtractor()
        self.auto_update_style_dna = auto_update_style_dna
        self.update_threshold = update_threshold

    def track_event(
        self,
        db: Session,
        user_id: int,
        event_type: str,
        entity_type: Optional[str] = None,
        entity_id: Optional[int] = None,
        context: Optional[Dict[str, Any]] = None,
        session_id: Optional[str] = None,
    ) -> InteractionEvent:
        """Track a user interaction event.

        Args:
            db: Database session
            user_id: User ID
            event_type: Type of event
            entity_type: Type of entity (product, outfit, etc.)
            entity_id: ID of the entity
            context: Additional context
            session_id: Session identifier

        Returns:
            Created InteractionEvent
        """
        if event_type not in self.TRACKED_EVENTS:
            logger.warning(f"Unknown event type: {event_type}")

        event = InteractionEvent(
            user_id=user_id,
            event_type=event_type,
            entity_type=entity_type,
            entity_id=entity_id,
            context=context or {},
            session_id=session_id or str(uuid.uuid4()),
        )

        db.add(event)
        db.commit()

        logger.debug(f"Tracked event: {event_type} for user {user_id}")

        # Auto-update Style DNA if threshold reached
        if self.auto_update_style_dna:
            self._check_and_update_style_dna(db, user_id)

        return event

    def _check_and_update_style_dna(
        self,
        db: Session,
        user_id: int,
    ) -> None:
        """Check if Style DNA should be updated and update if needed.

        Args:
            db: Database session
            user_id: User ID
        """
        # Count recent events
        recent_events = db.query(InteractionEvent).filter(
            InteractionEvent.user_id == user_id,
        ).count()

        if recent_events % self.update_threshold == 0 and recent_events > 0:
            try:
                self.style_extractor.extract_style_dna(db, user_id)
                logger.info(f"Auto-updated Style DNA for user {user_id}")
            except Exception as e:
                logger.error(f"Failed to update Style DNA: {e}")

    def track_product_view(
        self,
        db: Session,
        user_id: int,
        product_id: int,
        source: str = "unknown",
        position: Optional[int] = None,
    ) -> InteractionEvent:
        """Track product view event.

        Args:
            db: Database session
            user_id: User ID
            product_id: Product ID
            source: Where the view came from
            position: Position in list if applicable

        Returns:
            Created InteractionEvent
        """
        context = {"source": source}
        if position is not None:
            context["position"] = position

        return self.track_event(
            db=db,
            user_id=user_id,
            event_type="view_product",
            entity_type="product",
            entity_id=product_id,
            context=context,
        )

    def track_product_like(
        self,
        db: Session,
        user_id: int,
        product_id: int,
        source: str = "unknown",
    ) -> InteractionEvent:
        """Track product like event.

        Args:
            db: Database session
            user_id: User ID
            product_id: Product ID
            source: Where the like came from

        Returns:
            Created InteractionEvent
        """
        return self.track_event(
            db=db,
            user_id=user_id,
            event_type="like_product",
            entity_type="product",
            entity_id=product_id,
            context={"source": source},
        )

    def track_product_dislike(
        self,
        db: Session,
        user_id: int,
        product_id: int,
        source: str = "unknown",
    ) -> InteractionEvent:
        """Track product dislike event.

        Args:
            db: Database session
            user_id: User ID
            product_id: Product ID
            source: Where the dislike came from

        Returns:
            Created InteractionEvent
        """
        return self.track_event(
            db=db,
            user_id=user_id,
            event_type="dislike_product",
            entity_type="product",
            entity_id=product_id,
            context={"source": source},
        )

    def track_wishlist_add(
        self,
        db: Session,
        user_id: int,
        product_id: int,
    ) -> InteractionEvent:
        """Track wishlist add event.

        Args:
            db: Database session
            user_id: User ID
            product_id: Product ID

        Returns:
            Created InteractionEvent
        """
        return self.track_event(
            db=db,
            user_id=user_id,
            event_type="wishlist",
            entity_type="product",
            entity_id=product_id,
        )

    def track_wishlist_remove(
        self,
        db: Session,
        user_id: int,
        product_id: int,
    ) -> InteractionEvent:
        """Track wishlist remove event.

        Args:
            db: Database session
            user_id: User ID
            product_id: Product ID

        Returns:
            Created InteractionEvent
        """
        return self.track_event(
            db=db,
            user_id=user_id,
            event_type="remove_wishlist",
            entity_type="product",
            entity_id=product_id,
        )

    def track_search(
        self,
        db: Session,
        user_id: int,
        query: str,
        result_count: int,
    ) -> InteractionEvent:
        """Track search event.

        Args:
            db: Database session
            user_id: User ID
            query: Search query
            result_count: Number of results

        Returns:
            Created InteractionEvent
        """
        return self.track_event(
            db=db,
            user_id=user_id,
            event_type="search",
            context={
                "query": query,
                "result_count": result_count,
            },
        )

    def track_purchase(
        self,
        db: Session,
        user_id: int,
        product_id: int,
        order_id: int,
        price: float,
    ) -> InteractionEvent:
        """Track purchase event.

        Args:
            db: Database session
            user_id: User ID
            product_id: Product ID
            order_id: Order ID
            price: Purchase price

        Returns:
            Created InteractionEvent
        """
        return self.track_event(
            db=db,
            user_id=user_id,
            event_type="purchase",
            entity_type="product",
            entity_id=product_id,
            context={
                "order_id": order_id,
                "price": price,
            },
        )

    def track_blend_vote(
        self,
        db: Session,
        user_id: int,
        blend_id: int,
        product_id: int,
        vote_type: str,
    ) -> InteractionEvent:
        """Track blend vote event.

        Args:
            db: Database session
            user_id: User ID
            blend_id: Blend ID
            product_id: Product ID
            vote_type: Type of vote (love, like, dislike)

        Returns:
            Created InteractionEvent
        """
        return self.track_event(
            db=db,
            user_id=user_id,
            event_type="blend_vote",
            entity_type="product",
            entity_id=product_id,
            context={
                "blend_id": blend_id,
                "vote_type": vote_type,
            },
        )

    def get_user_interaction_summary(
        self,
        db: Session,
        user_id: int,
        days: int = 30,
    ) -> Dict[str, Any]:
        """Get summary of user interactions.

        Args:
            db: Database session
            user_id: User ID
            days: Number of days to look back

        Returns:
            Interaction summary
        """
        from datetime import timedelta

        cutoff = datetime.utcnow() - timedelta(days=days)

        events = db.query(InteractionEvent).filter(
            InteractionEvent.user_id == user_id,
            InteractionEvent.created_at >= cutoff,
        ).all()

        summary = {
            "total_events": len(events),
            "by_type": {},
            "by_entity_type": {},
        }

        for event in events:
            summary["by_type"][event.event_type] = summary["by_type"].get(event.event_type, 0) + 1
            if event.entity_type:
                summary["by_entity_type"][event.entity_type] = summary["by_entity_type"].get(event.entity_type, 0) + 1

        return summary
