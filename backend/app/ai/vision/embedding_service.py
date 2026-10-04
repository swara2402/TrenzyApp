"""Embedding service for generating and managing FashionCLIP embeddings.

Provides a unified interface for:
- Product embeddings (image + text)
- User uploaded image embeddings
- Batch embedding generation
- Embedding storage and retrieval
"""

from __future__ import annotations

import logging
import numpy as np
from typing import Optional, List, Dict, Any
from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy.orm import Session

from .fashionclip import FASHIONCLIP_MODEL, get_fashionclip_model, FashionCLIPModel
from ..ml_config import EMBEDDING_DIM
from ...models import Product
from ..models_ai import ProductEmbedding

logger = logging.getLogger(__name__)


class EmbeddingService:
    """Service for generating and managing FashionCLIP embeddings."""

    def __init__(
        self,
        model: Optional[FashionCLIPModel] = None,
    ):
        """Initialize embedding service.

        Args:
            model: FashionCLIP model instance (uses singleton if not provided)
        """
        self.model = model or get_fashionclip_model()
        self.model_name = FASHIONCLIP_MODEL
        self.model_version = "1.0"

    def generate_product_embedding(
        self,
        product: Product,
    ) -> np.ndarray:
        """Generate embedding for a single product.

        Args:
            product: Product model instance

        Returns:
            Combined embedding vector (EMBEDDING_DIM-dimensional, L2-normalised)
        """
        # Build text representation
        text = self._build_product_text(product)

        # Generate text embedding
        text_embedding = self.model.encode_text(text)

        # Generate image embedding if image available
        image_embedding = None
        if product.image_url:
            try:
                image_embedding = self.model.encode_image(product.image_url)
            except Exception as e:
                logger.warning(f"Failed to encode image for product {product.id}: {e}")

        # Combine embeddings — average of text + image when both are available
        if image_embedding is not None:
            combined = (text_embedding + image_embedding) / 2.0
        else:
            combined = text_embedding

        # L2-normalise for cosine similarity via pgvector <=> operator
        norm = np.linalg.norm(combined)
        if norm > 0:
            combined = combined / norm

        return combined

    def generate_product_embeddings_batch(
        self,
        products: List[Product],
        batch_size: int = 32,
    ) -> Dict[str, np.ndarray]:
        """Generate embeddings for multiple products in batch.

        Args:
            products: List of Product instances
            batch_size: Batch size for encoding

        Returns:
            Dictionary mapping product_id (str) to embedding
        """
        embeddings: Dict[str, np.ndarray] = {}

        # Build text representations
        texts = [self._build_product_text(p) for p in products]

        # Encode texts in batch
        text_embeddings = self.model.encode_batch_texts(texts, batch_size)

        # Process images — only products that have image URLs
        products_with_images = [(i, p) for i, p in enumerate(products) if p.image_url]
        image_urls = [p.image_url for _, p in products_with_images]
        image_embeddings_map: Dict[int, np.ndarray] = {}

        if image_urls:
            try:
                batch_image_embs = self.model.encode_batch_images(image_urls, batch_size)
                for (orig_idx, _), img_emb in zip(products_with_images, batch_image_embs):
                    image_embeddings_map[orig_idx] = img_emb
            except Exception as e:
                logger.warning(f"Failed to encode images in batch: {e}")

        # Combine and normalise
        for i, product in enumerate(products):
            text_emb = text_embeddings[i]

            if i in image_embeddings_map:
                combined = (text_emb + image_embeddings_map[i]) / 2.0
            else:
                combined = text_emb

            norm = np.linalg.norm(combined)
            if norm > 0:
                combined = combined / norm

            embeddings[str(product.id)] = combined

        return embeddings

    def save_product_embedding(
        self,
        db: Session,
        product_id: str,
        embedding: np.ndarray,
        text_embedding: Optional[np.ndarray] = None,
        image_embedding: Optional[np.ndarray] = None,
    ) -> ProductEmbedding:
        """Save product embedding to database.

        Args:
            db: Database session
            product_id: Product ID (string)
            embedding: Combined embedding vector
            text_embedding: Optional text-only embedding
            image_embedding: Optional image-only embedding

        Returns:
            ProductEmbedding instance
        """
        # Validate dimension
        if len(embedding) != EMBEDDING_DIM:
            raise ValueError(
                f"Embedding dimension {len(embedding)} != expected {EMBEDDING_DIM}"
            )

        # Validate no NaN or Inf
        if not np.isfinite(embedding).all():
            raise ValueError(f"Embedding for product {product_id} contains NaN or Inf")

        # Resolve product integer PK for the FK relationship.
        # ProductEmbedding.product_id is an Integer FK to products.id,
        # but products.id is a String PK. We join to get the int id.
        # The FK is actually products.id (String), so product_id stays as-is.
        now = datetime.now(timezone.utc)

        # Check if embedding already exists
        existing = db.query(ProductEmbedding).filter(
            ProductEmbedding.product_id == product_id
        ).first()

        emb_list = embedding.tolist()
        text_list = text_embedding.tolist() if text_embedding is not None else None
        img_list = image_embedding.tolist() if image_embedding is not None else None

        if existing:
            # Update existing embedding
            existing.combined_embedding = emb_list
            if text_list:
                existing.text_embedding = text_list
            if img_list:
                existing.image_embedding = img_list
            existing.model_version = self.model_version
            existing.dimension = EMBEDDING_DIM
            existing.needs_regeneration = False
            existing.updated_at = now
        else:
            # Create new embedding
            existing = ProductEmbedding(
                product_id=product_id,
                combined_embedding=emb_list,
                text_embedding=text_list,
                image_embedding=img_list,
                model_version=self.model_version,
                dimension=EMBEDDING_DIM,
                needs_regeneration=False,
            )
            db.add(existing)

        db.commit()
        return existing

    def get_product_embedding(
        self,
        db: Session,
        product_id: str,
    ) -> Optional[np.ndarray]:
        """Retrieve product embedding from database.

        Args:
            db: Database session
            product_id: Product ID

        Returns:
            Embedding vector or None if not found
        """
        embedding = db.query(ProductEmbedding).filter(
            ProductEmbedding.product_id == product_id
        ).first()

        if embedding and embedding.combined_embedding:
            return np.array(embedding.combined_embedding)

        return None

    def generate_and_save_embedding(
        self,
        db: Session,
        product: Product,
    ) -> ProductEmbedding:
        """Generate and save embedding for a product.

        Args:
            db: Database session
            product: Product instance

        Returns:
            ProductEmbedding instance
        """
        # Generate separate text and image embeddings before combining
        text = self._build_product_text(product)
        text_emb = self.model.encode_text(text)

        image_emb: Optional[np.ndarray] = None
        if product.image_url:
            try:
                image_emb = self.model.encode_image(product.image_url)
            except Exception as e:
                logger.warning(f"Image encode failed for {product.id}: {e}")

        if image_emb is not None:
            combined = (text_emb + image_emb) / 2.0
        else:
            combined = text_emb

        norm = np.linalg.norm(combined)
        if norm > 0:
            combined = combined / norm

        return self.save_product_embedding(
            db,
            str(product.id),
            combined,
            text_embedding=text_emb,
            image_embedding=image_emb,
        )

    def _build_product_text(self, product: Product) -> str:
        """Build text representation from product attributes.

        Args:
            product: Product instance

        Returns:
            Combined text string

        Note:
            ``Product.category`` and ``Product.brand`` are plain String columns,
            not ORM relationships. Access them directly, not via ``.name``.
        """
        parts: list[str] = []

        if product.name:
            parts.append(product.name)

        if product.description:
            parts.append(product.description)

        # category is a String column — access directly, NOT product.category.name
        if product.category:
            parts.append(product.category)

        if product.style:
            parts.append(product.style)

        if product.color:
            parts.append(product.color)

        if product.material:
            parts.append(product.material)

        if product.fit:
            parts.append(product.fit)

        if product.occasion:
            parts.append(product.occasion)

        # brand is a String column — access directly, NOT product.brand.name
        if product.brand:
            parts.append(product.brand)

        if product.gender:
            parts.append(product.gender)

        return " ".join(parts)


# Singleton instance
_embedding_service_instance: Optional[EmbeddingService] = None


def get_embedding_service() -> EmbeddingService:
    """Get singleton embedding service instance.

    Returns:
        EmbeddingService instance
    """
    global _embedding_service_instance

    if _embedding_service_instance is None:
        _embedding_service_instance = EmbeddingService()

    return _embedding_service_instance
