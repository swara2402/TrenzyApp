"""Hybrid recommendation engine.

Implements a multi-factor recommendation system that combines:
1. Embedding similarity (semantic + visual)
2. User Style DNA matching
3. Behavioral prediction
4. Contextual factors
5. Diversity and novelty scoring
"""

from __future__ import annotations

from typing import List, Dict, Optional, Tuple
import logging
import numpy as np
from datetime import datetime

from sqlalchemy.orm import Session
from sqlalchemy import and_, or_

from ...models import Product, User
from ..models_ai import (
    UserEmbedding,
    ProductEmbedding,
    UserStyleProfile,
    InteractionEvent,
)
from ..embeddings.product_embeddings import compute_cosine_similarity

logger = logging.getLogger(__name__)


class RuleBasedRecommender:
    """Rule-based recommendation engine combining multiple signals (formerly HybridRecommender)."""

    def __init__(
        self,
        embedding_weight: float = 0.35,
        style_weight: float = 0.25,
        behavioral_weight: float = 0.25,
        context_weight: float = 0.10,
        diversity_weight: float = 0.05,
    ):
        """Initialize recommender with signal weights.

        Args:
            embedding_weight: Weight for embedding similarity
            style_weight: Weight for Style DNA matching
            behavioral_weight: Weight for behavioral prediction
            context_weight: Weight for contextual factors
            diversity_weight: Weight for diversity/novelty
        """
        self.embedding_weight = embedding_weight
        self.style_weight = style_weight
        self.behavioral_weight = behavioral_weight
        self.context_weight = context_weight
        self.diversity_weight = diversity_weight

    def _compute_embedding_score(
        self,
        user_embedding: List[float],
        product_embedding: List[float],
    ) -> float:
        """Compute embedding similarity score.

        Args:
            user_embedding: User embedding vector
            product_embedding: Product embedding vector

        Returns:
            Similarity score (0-1)
        """
        return compute_cosine_similarity(user_embedding, product_embedding)

    def _compute_style_score(
        self,
        style_profile: UserStyleProfile,
        product: Product,
    ) -> float:
        """Compute Style DNA matching score.

        Args:
            style_profile: User's Style DNA
            product: Product to score

        Returns:
            Style match score (0-1)
        """
        score = 0.0
        count = 0

        # Style category match
        if product.style and product.style.lower() in style_profile.style_scores:
            score += style_profile.style_scores[product.style.lower()]
            count += 1

        # Fit match
        if product.fit and product.fit.lower() in style_profile.fit_scores:
            score += style_profile.fit_scores[product.fit.lower()]
            count += 1

        # Color match
        if product.color and product.color.lower() in style_profile.color_scores:
            score += style_profile.color_scores[product.color.lower()]
            count += 1

        # Occasion match
        if product.occasion and product.occasion.lower() in style_profile.occasion_scores:
            score += style_profile.occasion_scores[product.occasion.lower()]
            count += 1

        # Material match
        if product.material and product.material.lower() in style_profile.material_scores:
            score += style_profile.material_scores[product.material.lower()]
            count += 1

        # Brand affinity
        if product.brand and product.brand.lower() in style_profile.brand_scores:
            score += style_profile.brand_scores[product.brand.lower()]
            count += 1

        # Category preference
        if product.category and product.category.lower() in style_profile.category_scores:
            score += style_profile.category_scores[product.category.lower()]
            count += 1

        if count > 0:
            return score / count
        return 0.5  # Neutral score if no matches

    def _compute_behavioral_score(
        self,
        db: Session,
        user_id: int,
        product_id: int,
        interacted_embeddings: Optional[List[List[float]]] = None,
        current_embedding: Optional[List[float]] = None,
    ) -> float:
        """Compute behavioral prediction score.

        Uses interaction history to predict likelihood of engagement.

        Args:
            db: Database session
            user_id: User ID
            product_id: Product ID
            interacted_embeddings: Optional pre-fetched embeddings of products
                the user has interacted with. When ``None`` (the default) they
                are loaded from the database. Supplying pre-fetched values lets
                callers avoid an N+1 query pattern when scoring many products.
            current_embedding: Optional pre-fetched embedding for ``product_id``.

        Returns:
            Behavioral score (0-1)
        """
        if interacted_embeddings is None:
            interacted_embeddings = self._load_interacted_embeddings(db, user_id)

        if not interacted_embeddings:
            return 0.5  # Neutral for new users

        if current_embedding is None:
            current = db.query(ProductEmbedding).filter(
                ProductEmbedding.product_id == product_id,
                ProductEmbedding.combined_embedding.isnot(None),
            ).first()
            current_embedding = current.combined_embedding if current else None

        if not current_embedding:
            return 0.5

        # Compute average similarity to interacted products
        similarities = []
        for embedding in interacted_embeddings:
            if embedding:
                sim = compute_cosine_similarity(
                    current_embedding,
                    embedding,
                )
                similarities.append(sim)

        if not similarities:
            return 0.5

        return np.mean(similarities)

    def _load_interacted_embeddings(
        self,
        db: Session,
        user_id: int,
    ) -> List[List[float]]:
        """Load embeddings for products the user has positively interacted with.

        Performed once per recommendation request so scoring many candidates
        does not trigger a query per product.
        """
        interacted_ids = [
            entity_id
            for (entity_id,) in db.query(InteractionEvent.entity_id).filter(
                InteractionEvent.user_id == user_id,
                InteractionEvent.entity_type == "product",
                InteractionEvent.event_type.in_(["like_product", "wishlist", "purchase"]),
            ).all()
            if entity_id
        ]

        if not interacted_ids:
            return []

        rows = db.query(ProductEmbedding.combined_embedding).filter(
            ProductEmbedding.product_id.in_(interacted_ids),
            ProductEmbedding.combined_embedding.isnot(None),
        ).all()
        return [row[0] for row in rows if row[0]]

    def _compute_context_score(
        self,
        product: Product,
        context: Dict[str, any],
    ) -> float:
        """Compute contextual score based on request context.

        Args:
            product: Product to score
            context: Context dictionary (occasion, budget, etc.)

        Returns:
            Context score (0-1)
        """
        score = 1.0

        # Occasion match
        if "occasion" in context and product.occasion:
            if context["occasion"].lower() != product.occasion.lower():
                score *= 0.5

        # Budget constraint
        if "max_price" in context:
            if product.price > context["max_price"]:
                score *= 0.0
            elif product.price > context["max_price"] * 0.8:
                score *= 0.5

        # Category filter
        if "category" in context and product.category:
            if context["category"].lower() != product.category.lower():
                score *= 0.3

        # Style filter
        if "style" in context and product.style:
            if context["style"].lower() != product.style.lower():
                score *= 0.5

        return score

    def _compute_diversity_score(
        self,
        product: Product,
        already_selected: List[Product],
    ) -> float:
        """Compute diversity score to avoid similar items.

        Args:
            product: Product to score
            already_selected: Already selected products

        Returns:
            Diversity score (0-1)
        """
        if not already_selected:
            return 1.0

        # Check for diversity in categories
        categories = [p.category for p in already_selected if p.category]
        if product.category and product.category in categories:
            return 0.5

        # Check for diversity in brands
        brands = [p.brand for p in already_selected if p.brand]
        if product.brand and product.brand in brands:
            return 0.7

        # Check for diversity in colors
        colors = [p.color for p in already_selected if p.color]
        if product.color and product.color in colors:
            return 0.7

        return 1.0

    def compute_final_score(
        self,
        db: Session,
        user_id: int,
        product: Product,
        user_embedding: Optional[List[float]] = None,
        style_profile: Optional[UserStyleProfile] = None,
        context: Optional[Dict[str, any]] = None,
        already_selected: Optional[List[Product]] = None,
        product_embedding: Optional[List[float]] = None,
        behavioral_score: Optional[float] = None,
        interacted_embeddings: Optional[List[List[float]]] = None,
        product_embedding_provided: bool = False,
    ) -> float:
        """Compute final recommendation score combining all signals.

        Args:
            db: Database session
            user_id: User ID
            product: Product
            user_embedding: User embedding vector
            style_profile: User Style DNA profile
            context: Request context
            already_selected: Already selected products for diversity
            product_embedding: Pre-fetched combined embedding for ``product``.
                When ``product_embedding_provided`` is True, no embedding query
                is issued for this product.
            behavioral_score: Pre-computed behavioral score. When provided the
                behavioral query path is skipped.
            interacted_embeddings: Pre-fetched interacted embeddings used for the
                behavioral score when ``behavioral_score`` is not supplied.

        Returns:
            Final score (0-1)
        """
        scores = {}

        # Get user embedding if not provided
        if user_embedding is None:
            user_emb = db.query(UserEmbedding).filter(
                UserEmbedding.user_id == user_id
            ).first()
            user_embedding = user_emb.embedding if user_emb else None

        # Get product embedding (unless the caller already provided one, which
        # is how the batched ``recommend`` path avoids an N+1 query pattern).
        if product_embedding_provided:
            resolved_product_embedding = product_embedding
        else:
            product_emb = db.query(ProductEmbedding).filter(
                ProductEmbedding.product_id == product.id
            ).first()
            resolved_product_embedding = (
                product_emb.combined_embedding if product_emb else None
            )

        # Get style profile if not provided
        if style_profile is None:
            style_profile = db.query(UserStyleProfile).filter(
                UserStyleProfile.user_id == user_id
            ).first()

        # Compute individual scores
        if user_embedding and resolved_product_embedding:
            scores["embedding"] = self._compute_embedding_score(
                user_embedding,
                resolved_product_embedding,
            )
        else:
            scores["embedding"] = 0.5

        if style_profile:
            scores["style"] = self._compute_style_score(style_profile, product)
        else:
            scores["style"] = 0.5

        if behavioral_score is not None:
            scores["behavioral"] = behavioral_score
        else:
            scores["behavioral"] = self._compute_behavioral_score(
                db,
                user_id,
                product.id,
                interacted_embeddings=interacted_embeddings,
                current_embedding=resolved_product_embedding,
            )

        if context:
            scores["context"] = self._compute_context_score(product, context)
        else:
            scores["context"] = 1.0

        if already_selected:
            scores["diversity"] = self._compute_diversity_score(product, already_selected)
        else:
            scores["diversity"] = 1.0

        # Weighted combination
        final_score = (
            self.embedding_weight * scores["embedding"]
            + self.style_weight * scores["style"]
            + self.behavioral_weight * scores["behavioral"]
            + self.context_weight * scores["context"]
            + self.diversity_weight * scores["diversity"]
        )

        return final_score

    def recommend(
        self,
        db: Session,
        user_id: int,
        limit: int = 20,
        context: Optional[Dict[str, any]] = None,
        exclude_product_ids: Optional[List[int]] = None,
    ) -> List[Tuple[Product, float]]:
        """Generate recommendations for a user.

        Args:
            db: Database session
            user_id: User ID
            limit: Number of recommendations to return
            context: Request context
            exclude_product_ids: Product IDs to exclude

        Returns:
            List of (product, score) tuples sorted by score
        """
        # Get candidate products
        query = db.query(Product).filter(Product.is_archived == False)

        if exclude_product_ids:
            query = query.filter(~Product.id.in_(exclude_product_ids))

        candidates = query.all()

        if not candidates:
            return []

        # Pre-fetch all per-user / per-candidate data ONCE before scoring. The
        # scoring loop must not issue a query per product, otherwise a large
        # catalog turns a single recommendation call into thousands of round
        # trips (slow enough to time a request out / exhaust the worker).
        user_emb = db.query(UserEmbedding).filter(
            UserEmbedding.user_id == user_id
        ).first()
        user_embedding = user_emb.embedding if user_emb else None

        style_profile = db.query(UserStyleProfile).filter(
            UserStyleProfile.user_id == user_id
        ).first()

        interacted_embeddings = self._load_interacted_embeddings(db, user_id)

        candidate_ids = [p.id for p in candidates]
        embedding_rows = db.query(
            ProductEmbedding.product_id,
            ProductEmbedding.combined_embedding,
        ).filter(
            ProductEmbedding.product_id.in_(candidate_ids),
            ProductEmbedding.combined_embedding.isnot(None),
        ).all()
        embeddings_by_product = {
            product_id: embedding
            for product_id, embedding in embedding_rows
            if embedding
        }

        # Score all candidates
        scored_products = []
        already_selected = []

        for product in candidates:
            product_embedding = embeddings_by_product.get(product.id)
            score = self.compute_final_score(
                db=db,
                user_id=user_id,
                product=product,
                user_embedding=user_embedding,
                style_profile=style_profile,
                context=context,
                already_selected=already_selected,
                product_embedding=product_embedding,
                interacted_embeddings=interacted_embeddings,
                product_embedding_provided=True,
            )
            scored_products.append((product, score))

        # Sort by score
        scored_products.sort(key=lambda x: x[1], reverse=True)

        return scored_products[:limit]

    def explain_recommendation(
        self,
        db: Session,
        user_id: int,
        product: Product,
    ) -> str:
        """Generate explanation for why a product was recommended.

        Args:
            db: Database session
            user_id: User ID
            product: Recommended product

        Returns:
            Natural language explanation
        """
        style_profile = db.query(UserStyleProfile).filter(
            UserStyleProfile.user_id == user_id
        ).first()

        if not style_profile:
            return "Recommended based on popular trends."

        reasons = []

        # Style match
        if product.style and product.style.lower() in style_profile.style_scores:
            score = style_profile.style_scores[product.style.lower()]
            if score > 0.6:
                reasons.append(f"matches your preference for {product.style} style")

        # Fit match
        if product.fit and product.fit.lower() in style_profile.fit_scores:
            score = style_profile.fit_scores[product.fit.lower()]
            if score > 0.6:
                reasons.append(f"aligns with your preference for {product.fit} fits")

        # Color match
        if product.color and product.color.lower() in style_profile.color_scores:
            score = style_profile.color_scores[product.color.lower()]
            if score > 0.6:
                reasons.append(f"features {product.color}, a color you often choose")

        # Brand affinity
        if product.brand and product.brand.lower() in style_profile.brand_scores:
            score = style_profile.brand_scores[product.brand.lower()]
            if score > 0.6:
                reasons.append(f"from {product.brand}, a brand you like")

        if not reasons:
            return "Recommended based on your browsing patterns."

        return "Recommended because it " + ", and ".join(reasons) + "."