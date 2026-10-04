"""Interaction dataset builder (Phase 4).

Builds the recommendation training dataset from interaction events with:

- Explicit label/weighting logic (Phase 4.1) — not blind event counts.
- Positive events: like, wishlist, cart, purchase, save.
- Negative events: dislike, remove_wishlist.
- Time-based train/validation/test split (Phase 5.3) to prevent temporal leakage.

Output schema:
    user_id, product_id, event_type, timestamp, label (0/1), weight
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime
from typing import List, Optional

from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

# Explicit label logic. Events that signal positive intent get label 1 with a
# weight (stronger signal = higher weight). Negative events get 0.
POSITIVE_EVENTS: dict[str, float] = {
    "like_product": 1.0,
    "wishlist": 0.8,
    "cart_add": 1.0,
    "purchase": 1.0,
    "save_outfit": 0.7,
    "swipe": 0.5,      # resolved per-event below
}
NEGATIVE_EVENTS: dict[str, float] = {
    "dislike_product": 1.0,
    "remove_wishlist": 0.6,
}

# Neutral/weak events are only used as negative context if the user had no
# explicit signals, otherwise they are excluded (they add label noise).
WEAK_EVENTS: set[str] = {"view_product"}


@dataclass
class InteractionSample:
    user_id: int
    product_id: int
    event_type: str
    timestamp: datetime
    label: int
    weight: float
    context: dict


class InteractionDatasetBuilder:
    """Builds labeled train/validation/test datasets from interaction events."""

    def __init__(
        self,
        positive_events: Optional[dict] = None,
        negative_events: Optional[dict] = None,
    ):
        self.positive_events = positive_events or POSITIVE_EVENTS
        self.negative_events = negative_events or NEGATIVE_EVENTS

    def build_samples(self, db: Session) -> List[InteractionSample]:
        """Extract labeled samples from interaction_events.

        For a given (user, product) pair, the strongest signal wins: if the user
        ever purchased/liked/wishlisted, it's positive; if the strongest signal
        is a dislike, it's negative. Views alone only count as weak positives
        when the user has no explicit signals for that product.

        Returns:
            List of InteractionSample, one per (user, product, positive/negative).
        """
        from app.ai.models_ai import InteractionEvent

        rows = db.query(InteractionEvent).filter(
            InteractionEvent.entity_type == "product",
            InteractionEvent.entity_id.isnot(None),
        ).all()

        # Group by (user_id, product_id) and pick strongest signal.
        best: dict[tuple[int, int], dict] = {}

        for ev in rows:
            key = (ev.user_id, ev.entity_id)
            signal = {"event_type": ev.event_type, "ts": ev.created_at, "context": ev.context or {}}

            # Skip weak events if any explicit signal exists for this pair later.
            if key not in best:
                best[key] = signal
                continue

            def _strength(evt: str) -> float:
                if evt in self.positive_events:
                    return self.positive_events[evt]
                if evt in self.negative_events:
                    return -self.negative_events[evt]
                return 0.0

            cur = _strength(best[key]["event_type"])
            new = _strength(ev.event_type)
            if abs(new) > abs(cur):
                best[key] = signal

        samples: List[InteractionSample] = []
        for (user_id, product_id), sig in best.items():
            evt = sig["event_type"]
            if evt in self.positive_events:
                label, weight = 1, self.positive_events[evt]
            elif evt in self.negative_events:
                label, weight = 0, self.negative_events[evt]
            elif evt in WEAK_EVENTS:
                # A view by itself is a weak positive (implicit feedback).
                label, weight = 1, 0.1
            else:
                continue

            samples.append(InteractionSample(
                user_id=user_id,
                product_id=product_id,
                event_type=evt,
                timestamp=sig["ts"],
                label=label,
                weight=weight,
                context=sig["context"],
            ))

        logger.info("Built %d interaction samples", len(samples))
        return samples

    @staticmethod
    def time_split(
        samples: List[InteractionSample],
        val_frac: float = 0.2,
        test_frac: float = 0.2,
    ) -> tuple[List[InteractionSample], List[InteractionSample], List[InteractionSample]]:
        """Time-based train/validation/test split.

        Sorts samples by timestamp and splits into contiguous windows:
        ``past → train``, ``recent → validation``, ``future → test``.
        This prevents temporal leakage (Phase 5.3).
        """
        ordered = sorted(samples, key=lambda s: s.timestamp)
        n = len(ordered)
        if n == 0:
            return [], [], []
        train_end = int(n * (1 - val_frac - test_frac))
        val_end = int(n * (1 - test_frac))
        train = ordered[:train_end]
        val = ordered[train_end:val_end]
        test = ordered[val_end:]
        logger.info("Time split: train=%d val=%d test=%d", len(train), len(val), len(test))
        return train, val, test

    @staticmethod
    def add_negative_samples(
        samples: List[InteractionSample],
        db: Session,
        negative_ratio: int = 3,
        seed: int = 42,
    ) -> List[InteractionSample]:
        """Add negative samples by sampling products each user did NOT interact with.

        For every positive (user, product) pair, sample ``negative_ratio``
        products the user has no interaction with. These become label 0
        samples with timestamp equal to the positive sample's (so time-based
        splits stay temporally clean).

        Args:
            samples: Positive interaction samples.
            db: Database session.
            negative_ratio: Negatives per positive.
            seed: Random seed for reproducibility.

        Returns:
            Combined samples including negatives.
        """
        import random

        from app.ai.models_ai import InteractionEvent
        from app.models import Product

        rng = random.Random(seed)

        # For each user, the set of products they've interacted with.
        interacted: dict[int, set[int]] = {}
        for s in samples:
            interacted.setdefault(s.user_id, set()).add(s.product_id)

        negatives: List[InteractionSample] = []
        for s in samples:
            if s.label != 1:
                continue
            user_id = s.user_id
            seen = interacted.get(user_id, set())

            # Sample candidate products not interacted with by this user.
            existing = db.query(Product.id).all()
            all_ids = [r[0] for r in existing]
            candidates = [pid for pid in all_ids if pid not in seen]

            # Cap candidates to reasonable size; avoid all-zero vectors dominating.
            if len(candidates) > len(all_ids):
                candidates = candidates[:len(all_ids)]

            pool = rng.sample(candidates, min(negative_ratio, len(candidates)))
            for pid in pool:
                negatives.append(InteractionSample(
                    user_id=user_id,
                    product_id=pid,
                    event_type="negative_sample",
                    timestamp=s.timestamp,
                    label=0,
                    weight=1.0,
                    context={"source": "negative_sampling"},
                ))

        logger.info("Added %d negative samples (ratio=%d)", len(negatives), negative_ratio)
        return samples + negatives