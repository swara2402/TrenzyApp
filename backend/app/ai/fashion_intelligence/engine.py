"""Shared, explainable fashion-intelligence ranking core.

This module deliberately has no model/network dependency. It is the stable
contract used by AI Stylist and Outfit Builder while a learned ranker is
trained and evaluated behind the same interface.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from itertools import combinations, product
from typing import Any, Mapping, Protocol, Sequence


@dataclass(frozen=True)
class WardrobeItem:
    id: str
    category: str
    color: str | None = None
    style_tags: frozenset[str] = field(default_factory=frozenset)
    occasion_tags: frozenset[str] = field(default_factory=frozenset)
    pattern: str | None = None
    fabric: str | None = None
    source: str = "wardrobe"

    @classmethod
    def from_mapping(cls, value: Mapping[str, Any]) -> "WardrobeItem":
        return cls(
            id=str(value.get("id", value.get("product_id", ""))),
            category=str(value.get("category", "")).strip().lower(),
            color=(str(value["color"]).strip().lower() if value.get("color") else None),
            style_tags=frozenset(str(x).lower() for x in value.get("style_tags", []) if x),
            occasion_tags=frozenset(str(x).lower() for x in value.get("occasion_tags", []) if x),
            pattern=(str(value["pattern"]).lower() if value.get("pattern") else None),
            fabric=(str(value["fabric"]).lower() if value.get("fabric") else None),
            source=str(value.get("source", "wardrobe")),
        )


@dataclass(frozen=True)
class OutfitCandidate:
    items: tuple[WardrobeItem, ...]
    score: float
    reasons: tuple[str, ...]


class OutfitRanker(Protocol):
    def score(self, features: Mapping[str, float]) -> float: ...


class RuleBasedRanker:
    """Baseline scorer; can be replaced by a calibrated learned ranker."""

    def score(self, features: Mapping[str, float]) -> float:
        weights = {
            "color_harmony": 0.30,
            "style_coherence": 0.25,
            "occasion_fit": 0.25,
            "preference_fit": 0.15,
            "wardrobe_coverage": 0.05,
        }
        return round(100 * sum(weights[k] * features[k] for k in weights), 2)


def _norm(value: str | None) -> str:
    return (value or "").strip().lower()


def _color_score(items: Sequence[WardrobeItem]) -> float:
    colors = {_norm(item.color) for item in items if item.color}
    if len(colors) <= 1:
        return 1.0
    neutrals = {"black", "white", "grey", "gray", "beige", "cream", "navy", "brown", "denim"}
    if colors.issubset(neutrals):
        return 0.95
    if len(colors & neutrals) >= 1:
        return 0.82
    return 0.65


def _style_score(items: Sequence[WardrobeItem], preferred: set[str]) -> float:
    tags = [set(item.style_tags) for item in items if item.style_tags]
    if not tags:
        base = 0.5
    else:
        union = set.union(*tags)
        intersection = set.intersection(*tags)
        base = 0.55 + 0.45 * (len(intersection) / max(1, len(union)))
    if preferred:
        all_tags = set.union(*(set(x.style_tags) for x in items))
        base = 0.7 * base + 0.3 * (len(all_tags & preferred) / len(preferred))
    return min(1.0, base)


def _occasion_score(items: Sequence[WardrobeItem], occasion: str | None) -> float:
    if not occasion:
        return 0.7
    tagged = [item for item in items if item.occasion_tags]
    if not tagged:
        return 0.5
    matches = sum(occasion in item.occasion_tags for item in tagged)
    return matches / len(tagged)


def rank_outfits(
    items: Sequence[WardrobeItem | Mapping[str, Any]],
    *,
    occasion: str | None = None,
    preferred_styles: Sequence[str] = (),
    liked_item_ids: Sequence[str] = (),
    disliked_item_ids: Sequence[str] = (),
    ranker: OutfitRanker | None = None,
    limit: int = 10,
) -> list[OutfitCandidate]:
    """Build valid combinations and return deterministic, explainable rankings.

    Supported categories: top, bottom, one_piece, footwear, accessory.
    A valid base outfit is either top+bottom or one_piece; footwear and
    accessories are optional. The function never invents wardrobe products.
    """
    normalized = [x if isinstance(x, WardrobeItem) else WardrobeItem.from_mapping(x) for x in items]
    normalized = [x for x in normalized if x.id and x.category in {"top", "bottom", "one_piece", "footwear", "accessory"}]
    by_category: dict[str, list[WardrobeItem]] = {}
    for item in normalized:
        by_category.setdefault(item.category, []).append(item)

    bases: list[tuple[WardrobeItem, ...]] = []
    bases.extend(tuple(pair) for pair in product(by_category.get("top", []), by_category.get("bottom", [])))
    bases.extend((piece,) for piece in by_category.get("one_piece", []))
    if not bases:
        return []

    candidates: dict[tuple[str, ...], OutfitCandidate] = {}
    ranker = ranker or RuleBasedRanker()
    preferred = {_norm(x) for x in preferred_styles if x}
    liked, disliked = set(liked_item_ids), set(disliked_item_ids)

    for base in bases:
        footwear_options = [None, *by_category.get("footwear", [])]
        accessory_options = [None, *by_category.get("accessory", [])]
        for shoe, accessory in product(footwear_options, accessory_options):
            outfit = tuple(x for x in (*base, shoe, accessory) if x is not None)
            ids = tuple(sorted(x.id for x in outfit))
            if len(ids) != len(set(ids)) or set(ids) & disliked:
                continue
            features = {
                "color_harmony": _color_score(outfit),
                "style_coherence": _style_score(outfit, preferred),
                "occasion_fit": _occasion_score(outfit, _norm(occasion) or None),
                "preference_fit": (1.0 if any(x.id in liked for x in outfit) else 0.65),
                "wardrobe_coverage": min(1.0, len(outfit) / 4),
            }
            reasons = []
            if features["color_harmony"] >= 0.8:
                reasons.append("The colours work well together.")
            if features["style_coherence"] >= 0.75:
                reasons.append("The pieces share a coherent style.")
            if occasion and features["occasion_fit"] >= 0.75:
                reasons.append(f"The items fit the {occasion} occasion.")
            if any(x.id in liked for x in outfit):
                reasons.append("It includes an item you have liked.")
            score = ranker.score(features)
            candidates[ids] = OutfitCandidate(outfit, score, tuple(reasons or ["A balanced starting combination."]))

    return sorted(candidates.values(), key=lambda x: (-x.score, tuple(i.id for i in x.items)))[:max(0, limit)]
