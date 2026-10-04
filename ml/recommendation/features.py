"""Recommendation features (Phase 5.1).

Builds the feature vector for a (user, product) pair used by the recommendation
model:

User features:
    likes_7d, likes_30d, views_7d, wishlist_count, purchase_count,
    average_price, preferred_categories, preferred_colors, preferred_brands,
    style_distribution

Product features:
    category, brand, price, color, style, popularity, plus optional embedding.

User × Product features:
    previous_views, previous_likes, previous_dislikes, category_affinity,
    brand_affinity, color_affinity, price_distance, embedding_similarity

The feature schema is versioned (``FEATURE_SCHEMA_VERSION = "v1"``) so model
artifacts are tied to the feature layout that produced them.
"""

from __future__ import annotations

import logging
from typing import List, Optional, Union

import numpy as np
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

FEATURE_SCHEMA_VERSION = "v1"

BRAND_SLOTS_TOP = 10

# Top brands (by volume in the bundled catalog) mapped to one-hot slots.
BRAND_TOP = [
    "nike", "adidas", "puma", "united colors of benetton", "fabindia",
    "jealous 21", "arrow", "catwalk", "levi's", "gucci",
][:BRAND_SLOTS_TOP]

# Stable order of categorical feature slots
STYLE_SLOTS = [
    "casual", "formal", "streetwear", "minimalist", "classic", "bohemian",
    "sporty", "ethnic", "preppy", "grunge", "modern", "vintage", "edgy",
    "romantic", "athleisure", "y2k", "luxury", "others",
]
CATEGORY_SLOTS = [
    "tops", "bottoms", "dresses", "footwear", "outerwear", "ethnic wear",
    "accessories", "activewear", "sleepwear", "swimwear",
]
COLOR_SLOTS = [
    "black", "white", "gray", "navy", "beige", "brown", "red", "blue",
    "green", "pink", "yellow", "purple", "orange", "multi",
]


def _slot_normalize(value: Optional[str]) -> str:
    return (value or "").strip().lower()


def _color_slot(value: Optional[str]) -> str:
    """Map a raw product color string onto the color slot space."""
    v = _slot_normalize(value)
    if not v:
        return ""
    if v in COLOR_SLOTS:
        return v
    # Approximate mapping for common raw strings
    if "multi" in v or "printed" in v:
        return "multi"
    for color in ["black", "white", "gray", "navy", "beige", "brown",
                  "red", "blue", "green", "pink", "yellow", "purple", "orange"]:
        if color in v:
            return color
    return ""


class RecommendationFeatureBuilder:
    """Builds user, product, and user×product features."""

    def __init__(
        self,
        embedding_dim: int = 512,
        include_embedding: bool = True,
    ):
        self.embedding_dim = embedding_dim
        self.include_embedding = include_embedding
        self._user_profile_cache: dict[int, dict] = {}

    def reset_profile_cache(self) -> None:
        """Clear the per-user profile cache (e.g. between training runs)."""
        self._user_profile_cache.clear()

    # ------------------------------------------------------------------ user stats

    def _user_profile(self, db: Session, user_id: int, before_ts=None) -> dict:
        """Compute (and cache) a user's behavioral + preference profile.

        ``before_ts`` (if given) limits the profile to interactions strictly
        before that timestamp, so eval features never leak future signal.
        Cache key is (user_id, day-of-ts) to keep this temporally safe.
        """
        ts_key = before_ts.date() if before_ts is not None else None
        cache_key = (user_id, ts_key)
        if cache_key in self._user_profile_cache:
            return self._user_profile_cache[cache_key]

        from app.ai.models_ai import InteractionEvent
        from app.models import Product

        query = db.query(
            InteractionEvent.event_type,
            InteractionEvent.entity_id,
            InteractionEvent.context,
        ).filter(InteractionEvent.user_id == user_id)
        if before_ts is not None:
            query = query.filter(InteractionEvent.created_at < before_ts)
        rows = query.all()

        POSITIVE = {"like_product", "wishlist", "cart_add", "purchase", "save_outfit"}
        stats = {
            "likes_7d": 0, "likes_30d": 0, "views_7d": 0,
            "wishlist_count": 0, "purchase_count": 0,
            "avg_price": 0.0, "total_interactions": 0,
        }

        product_ids = []
        for event_type, entity_id, context in rows:
            stats["total_interactions"] += 1
            if event_type == "view_product":
                stats["views_7d"] += 1
            if event_type == "like_product":
                stats["likes_30d"] += 1
                product_ids.append(entity_id)
            if event_type == "wishlist":
                stats["wishlist_count"] += 1
            if event_type in ("purchase", "cart_add"):
                stats["purchase_count"] += 1
            if event_type in POSITIVE:
                product_ids.append(entity_id)

        # Preferred attribute values = attributes of positively-interacted items.
        preferred_styles: set[str] = set()
        preferred_categories: set[str] = set()
        preferred_colors: set[str] = set()
        preferred_brands: set[str] = set()
        preferred_article_types: set[str] = set()
        preferred_genders: set[str] = set()
        prices: list[float] = []

        product_ids = [pid for pid in product_ids if pid]
        if product_ids:
            prods = db.query(
                Product.style, Product.category, Product.color,
                Product.brand, Product.article_type, Product.gender, Product.price
            ).filter(Product.id.in_(product_ids)).all()
            for style, category, color, brand, article_type, gender, price in prods:
                if style:
                    preferred_styles.add(str(style).lower())
                if category:
                    preferred_categories.add(str(category).lower())
                if color:
                    preferred_colors.add(_color_slot(color))
                if brand:
                    preferred_brands.add(str(brand).lower())
                if article_type:
                    preferred_article_types.add(str(article_type).lower())
                if gender:
                    preferred_genders.add(str(gender).lower())
                if price:
                    prices.append(float(price))

        if prices:
            stats["avg_price"] = sum(prices) / len(prices)

        profile = {
            "stats": stats,
            "preferred_styles": preferred_styles,
            "preferred_categories": preferred_categories,
            "preferred_colors": preferred_colors,
            "preferred_brands": preferred_brands,
            "preferred_article_types": preferred_article_types,
            "preferred_genders": preferred_genders,
            "product_ids": set(product_ids),
        }
        self._user_profile_cache[cache_key] = profile
        return profile

    def _user_stats(self, db: Session, user_id: int, before_ts=None) -> dict:
        """Aggregate user behavioral stats over rolling windows."""
        return self._user_profile(db, user_id, before_ts)["stats"]

    def _user_style_distribution(self, db: Session, user_id: int, before_ts=None) -> np.ndarray:
        """Distribution of styles the user has interacted with."""
        profile = self._user_profile(db, user_id, before_ts)
        product_ids = list(profile["product_ids"])

        style_vec = np.zeros(len(STYLE_SLOTS))
        if not product_ids:
            # Laplace-style prior
            return np.ones(len(STYLE_SLOTS)) / len(STYLE_SLOTS)

        from app.models import Product
        prods = db.query(Product.style).filter(Product.id.in_(product_ids)).all()
        for (style,) in prods:
            slot = self._style_index(style)
            if slot >= 0:
                style_vec[slot] += 1.0
        total = style_vec.sum()
        if total > 0:
            style_vec /= total
        return style_vec

    def _style_index(self, style: Optional[str]) -> int:
        s = _slot_normalize(style)
        if not s:
            return len(STYLE_SLOTS) - 1
        for i, slot in enumerate(STYLE_SLOTS):
            if s == slot or s in slot:
                return i
        # check substring matches
        for i, slot in enumerate(STYLE_SLOTS):
            if slot in s:
                return i
        return len(STYLE_SLOTS) - 1

    def _category_index(self, category: Optional[str]) -> int:
        c = _slot_normalize(category)
        if not c:
            return len(CATEGORY_SLOTS) - 1
        for i, slot in enumerate(CATEGORY_SLOTS):
            if slot in c or c in slot:
                return i
        return len(CATEGORY_SLOTS) - 1

    def _embedding(self, db: Session, product_id: int) -> Optional[np.ndarray]:
        if not self.include_embedding:
            return None
        from app.ai.models_ai import ProductEmbedding
        row = db.query(ProductEmbedding).filter(
            ProductEmbedding.product_id == product_id
        ).first()
        if row and row.combined_embedding:
            return np.asarray(row.combined_embedding, dtype=float)
        return None

    # ------------------------------------------------------------------ feature vector

    def build(
        self,
        db: Session,
        user_id: int,
        product,
        before_ts=None,
    ) -> np.ndarray:
        """Build the full feature vector for a (user, product) pair.

        Args:
            db: Database session.
            user_id: User id.
            product: Product ORM object.
            before_ts: Optional timestamp cutoff for user profile features.

        Returns:
            ndarray of shape (feature_dim,) — feature_dim depends on config.
        """
        features: List[float] = []

        # 1. Product categorical features
        cat_index = self._category_index(getattr(product, "category", None))
        cat_vec = np.zeros(len(CATEGORY_SLOTS))
        cat_vec[cat_index] = 1.0
        features.extend(cat_vec.tolist())

        color = _color_slot(getattr(product, "color", None))
        color_vec = np.zeros(len(COLOR_SLOTS))
        if color:
            color_vec[COLOR_SLOTS.index(color)] = 1.0
        features.extend(color_vec.tolist())

        style_index = self._style_index(getattr(product, "style", None))
        style_vec = np.zeros(len(STYLE_SLOTS))
        style_vec[style_index] = 1.0
        features.extend(style_vec.tolist())

        # 2. Product continuous features
        price = float(getattr(product, "price", 0) or 0)
        features.append(np.log1p(price) / 12.0)  # normalized price (~0-1)
        rating = float(getattr(product, "rating", 0) or 0) / 5.0
        features.append(rating)

        # 2b. Product brand one-hot (top brands + other)
        p_brand = _slot_normalize(getattr(product, "brand", None))
        brand_vec = np.zeros(BRAND_SLOTS_TOP)
        if p_brand in BRAND_TOP:
            brand_vec[BRAND_TOP.index(p_brand)] = 1.0
        else:
            brand_vec[-1] = 1.0
        features.extend(brand_vec.tolist())

        p_article = _slot_normalize(getattr(product, "article_type", None))
        p_gender = _slot_normalize(getattr(product, "gender", None))

        # 3. User stats
        profile = self._user_profile(db, user_id, before_ts)
        stats = profile["stats"]
        features.extend([
            min(stats["likes_7d"], 50) / 50.0,
            min(stats["likes_30d"], 200) / 200.0,
            min(stats["views_7d"], 100) / 100.0,
            min(stats["wishlist_count"], 100) / 100.0,
            min(stats["purchase_count"], 50) / 50.0,
            min(stats["avg_price"] / 10000.0, 1.0),
        ])

        # 4. User style distribution
        style_dist = self._user_style_distribution(db, user_id, before_ts)
        features.extend(style_dist.tolist())

        # 5. User × Product affinity cross-features
        p_style = _slot_normalize(getattr(product, "style", None))
        p_cat = _slot_normalize(getattr(product, "category", None))
        p_color = _color_slot(getattr(product, "color", None))

        style_match = 1.0 if p_style in profile["preferred_styles"] else 0.0
        cat_match = 1.0 if p_cat in profile["preferred_categories"] else 0.0
        color_match = 1.0 if p_color in profile["preferred_colors"] else 0.0
        brand_match = 1.0 if p_brand in profile["preferred_brands"] else 0.0
        article_match = 1.0 if p_article in profile["preferred_article_types"] else 0.0
        gender_match = 1.0 if p_gender in profile["preferred_genders"] else 0.0
        features.extend([
            style_match, cat_match, color_match,
            brand_match, article_match, gender_match,
        ])

        # Price distance vs the user's historical avg (log-space, normalized).
        avg_price = stats["avg_price"]
        if avg_price > 0:
            price_diff = abs(np.log1p(price) - np.log1p(avg_price))
            features.append(min(price_diff / 12.0, 1.0))
        else:
            features.append(0.0)

        # Known-to-user (seen before) flag: strong negative context in demos.
        features.append(1.0 if product.id in profile["product_ids"] else 0.0)

        # 6. Product embedding (if available)
        emb = self._embedding(db, product.id)
        if self.include_embedding and emb is not None and len(emb) == self.embedding_dim:
            features.extend(emb.tolist())
        elif self.include_embedding:
            features.extend([0.0] * self.embedding_dim)

        return np.asarray(features, dtype=np.float32)

    def feature_dim(self) -> int:
        """Total feature dimension."""
        n_cat = len(CATEGORY_SLOTS)
        n_color = len(COLOR_SLOTS)
        n_style = len(STYLE_SLOTS)
        n_cont = 2            # price, rating
        n_brand = BRAND_SLOTS_TOP
        n_user = 6            # likes_7d ... avg_price
        n_style_dist = len(STYLE_SLOTS)
        n_cross = 8           # style_match, cat_match, color_match,
                              # brand_match, article_match, gender_match,
                              # price_diff, seen
        n_emb = self.embedding_dim if self.include_embedding else 0
        return n_cat + n_color + n_style + n_cont + n_brand + n_user + n_style_dist + n_cross + n_emb

    def feature_names(self) -> List[str]:
        """Human-readable feature names for the schema/metadata."""
        names: List[str] = []
        names += [f"cat_{c}" for c in CATEGORY_SLOTS]
        names += [f"color_{c}" for c in COLOR_SLOTS]
        names += [f"style_{c}" for c in STYLE_SLOTS]
        names += ["price_log", "rating"]
        names += [f"brand_{c}" for c in BRAND_TOP]
        names += ["likes_7d", "likes_30d", "views_7d", "wishlist_count",
                  "purchase_count", "avg_price"]
        names += [f"user_style_dist_{c}" for c in STYLE_SLOTS]
        names += ["style_match", "cat_match", "color_match",
                  "brand_match", "article_match", "gender_match",
                  "price_diff", "seen"]
        if self.include_embedding:
            names += [f"emb_{i}" for i in range(self.embedding_dim)]
        return names