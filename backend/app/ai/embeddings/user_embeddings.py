"""User embedding generation.

Generates user embeddings based on their interaction history and style profile.
"""

from __future__ import annotations

from typing import List, Dict
import logging
import numpy as np

from sentence_transformers import SentenceTransformer
from sqlalchemy.orm import Session

from ...models import User, Product
from ..models_ai import UserEmbedding, UserStyleProfile, InteractionEvent
from .product_embeddings import ProductEmbeddingPipeline, compute_cosine_similarity

logger = logging.getLogger(__name__)


class UserEmbeddingGenerator:
    """Generates user embeddings from interaction history."""

    def __init__(
        self,
        text_model_name: str = "all-MiniLM-L6-v2",
        device: str = "cpu",
    ):
        """Initialize embedding model.

        Args:
            text_model_name: Sentence transformer model
            device: Device to run on
        """
        self.device = device
        self.text_model = SentenceTransformer(text_model_name, device=device)

    def generate_from_style_profile(
        self,
        style_profile: UserStyleProfile,
    ) -> np.ndarray:
        """Generate user embedding from style profile.

        Args:
            style_profile: UserStyleProfile instance

        Returns:
            User embedding vector
        """
        # Build text representation from style profile
        parts = []

        # Style categories weighted by scores
        for style, score in style_profile.style_scores.items():
            if score > 0.5:  # Only include strong preferences
                parts.append(f"{style} fashion")

        # Colors
        for color, score in style_profile.color_scores.items():
            if score > 0.5:
                parts.append(f"{color} color")

        # Fits
        for fit, score in style_profile.fit_scores.items():
            if score > 0.5:
                parts.append(f"{fit} fit")

        # Brands
        for brand, score in style_profile.brand_scores.items():
            if score > 0.5:
                parts.append(f"{brand} brand")

        # Categories
        for category, score in style_profile.category_scores.items():
            if score > 0.5:
                parts.append(f"{category} category")

        text = " ".join(parts) if parts else "casual fashion"
        embedding = self.text_model.encode(text, convert_to_numpy=True)
        return embedding

    def generate_from_interactions(
        self,
        db: Session,
        user_id: int,
        limit: int = 100,
    ) -> np.ndarray:
        """Generate user embedding from recent positive interactions.

        Args:
            db: Database session
            user_id: User ID
            limit: Number of interactions to consider

        Returns:
            User embedding vector
        """
        # Get recent positive interactions
        positive_events = db.query(InteractionEvent).filter(
            InteractionEvent.user_id == user_id,
            InteractionEvent.event_type.in_(["like_product", "wishlist", "save_outfit", "purchase"]),
        ).order_by(InteractionEvent.created_at.desc()).limit(limit).all()

        if not positive_events:
            # Fallback to default embedding
            return self.text_model.encode("casual fashion", convert_to_numpy=True)

        # Get product embeddings for interacted products
        product_embeddings = []
        for event in positive_events:
            if event.entity_type == "product" and event.entity_id:
                product_emb = db.query(ProductEmbedding).filter(
                    ProductEmbedding.product_id == event.entity_id
                ).first()
                if product_emb and product_emb.combined_embedding:
                    product_embeddings.append(np.array(product_emb.combined_embedding))

        if not product_embeddings:
            return self.text_model.encode("casual fashion", convert_to_numpy=True)

        # Average the product embeddings
        avg_embedding = np.mean(product_embeddings, axis=0)
        return avg_embedding

    def generate_hybrid_embedding(
        self,
        style_profile: UserStyleProfile,
        interaction_embedding: np.ndarray,
        style_weight: float = 0.3,
    ) -> np.ndarray:
        """Combine style profile and interaction embeddings.

        Args:
            style_profile: UserStyleProfile instance
            interaction_embedding: Embedding from interactions
            style_weight: Weight for style profile (0-1)

        Returns:
            Hybrid embedding vector
        """
        style_embedding = self.generate_from_style_profile(style_profile)

        # Normalize
        style_norm = style_embedding / (np.linalg.norm(style_embedding) + 1e-8)
        interaction_norm = interaction_embedding / (np.linalg.norm(interaction_embedding) + 1e-8)

        # Weighted combination
        hybrid = style_weight * style_norm + (1 - style_weight) * interaction_norm

        # Renormalize
        hybrid = hybrid / (np.linalg.norm(hybrid) + 1e-8)

        return hybrid
