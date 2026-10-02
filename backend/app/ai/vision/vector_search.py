"""Vector similarity search using FashionCLIP embeddings.

Provides:
- Similar product search
- Visual search (image to products)
- Style similarity
- Category similarity

Uses pgvector when available for production-scale performance, falls back to NumPy.
"""

from __future__ import annotations

import logging
from typing import List, Tuple, Optional
import numpy as np

from sqlalchemy.orm import Session
from sqlalchemy import func

from ...models import Product
from ..models_ai import ProductEmbedding
from .embedding_service import get_embedding_service

logger = logging.getLogger(__name__)

# Try to import pgvector search for production use
try:
    from .pgvector_search import get_pgvector_search
    PGVECTOR_SEARCH_AVAILABLE = True
except ImportError:
    PGVECTOR_SEARCH_AVAILABLE = False


class VectorSearch:
    """Vector similarity search using FashionCLIP embeddings."""

    def __init__(self):
        """Initialize vector search."""
        self.embedding_service = get_embedding_service()
        self.pgvector_available = PGVECTOR_SEARCH_AVAILABLE
        if self.pgvector_available:
            self.pgvector_search = get_pgvector_search()
            logger.info("Using pgvector for similarity search")
        else:
            logger.info("Using NumPy for similarity search (pgvector unavailable)")

    def compute_cosine_similarity(
        self,
        embedding1: np.ndarray,
        embedding2: np.ndarray,
    ) -> float:
        """Compute cosine similarity between two embeddings.

        Args:
            embedding1: First embedding
            embedding2: Second embedding

        Returns:
            Cosine similarity score (-1 to 1)
        """
        # Normalize embeddings
        norm1 = embedding1 / (np.linalg.norm(embedding1) + 1e-8)
        norm2 = embedding2 / (np.linalg.norm(embedding2) + 1e-8)

        # Compute cosine similarity
        similarity = np.dot(norm1, norm2)
        return float(similarity)

    def find_similar_products(
        self,
        db: Session,
        product_id: int,
        limit: int = 20,
        min_similarity: float = 0.5,
    ) -> List[Tuple[Product, float]]:
        """Find similar products by embedding similarity.

        Args:
            db: Database session
            product_id: Query product ID
            limit: Maximum number of results
            min_similarity: Minimum similarity threshold

        Returns:
            List of (product, similarity_score) tuples
        """
        # Use pgvector if available for production performance
        if self.pgvector_available:
            try:
                return self.pgvector_search.find_similar_products_pgvector(
                    db, product_id, limit, min_similarity
                )
            except Exception as e:
                logger.warning(f"pgvector search failed, falling back to NumPy: {e}")

        # Fallback to NumPy-based search
        # Get query product embedding
        query_embedding = self.embedding_service.get_product_embedding(db, product_id)

        if query_embedding is None:
            logger.warning(f"No embedding found for product {product_id}")
            return []

        # Get all product embeddings
        all_embeddings = db.query(ProductEmbedding).filter(
            ProductEmbedding.combined_embedding.isnot(None),
            ProductEmbedding.product_id != product_id,
        ).all()

        # Compute similarities
        similarities = []
        for pe in all_embeddings:
            if pe.combined_embedding:
                target_embedding = np.array(pe.combined_embedding)
                similarity = self.compute_cosine_similarity(query_embedding, target_embedding)

                if similarity >= min_similarity:
                    similarities.append((pe.product_id, similarity))

        # Sort by similarity
        similarities.sort(key=lambda x: x[1], reverse=True)

        # Get product details
        product_ids = [pid for pid, _ in similarities[:limit]]
        products = db.query(Product).filter(Product.id.in_(product_ids)).all()

        # Map back to products with scores
        product_map = {p.id: p for p in products}
        results = [
            (product_map[pid], score)
            for pid, score in similarities[:limit]
            if pid in product_map
        ]

        return results

    def visual_search(
        self,
        db: Session,
        image_embedding: np.ndarray,
        limit: int = 20,
        min_similarity: float = 0.5,
        category_filter: Optional[str] = None,
    ) -> List[Tuple[Product, float]]:
        """Find similar products by image embedding.

        Args:
            db: Database session
            image_embedding: Query image embedding
            limit: Maximum number of results
            min_similarity: Minimum similarity threshold
            category_filter: Optional category filter

        Returns:
            List of (product, similarity_score) tuples
        """
        # Use pgvector if available for production performance
        if self.pgvector_available:
            try:
                return self.pgvector_search.visual_search_pgvector(
                    db, image_embedding, limit, min_similarity, category_filter
                )
            except Exception as e:
                logger.warning(f"pgvector visual search failed, falling back to NumPy: {e}")

        # Fallback to NumPy-based search
        # Build query for product embeddings
        query = db.query(ProductEmbedding).filter(
            ProductEmbedding.combined_embedding.isnot(None),
        )

        # Apply category filter if specified
        if category_filter:
            query = query.join(Product).filter(
                Product.category.has(name=category_filter)
            )

        embeddings = query.all()

        # Compute similarities
        similarities = []
        for pe in embeddings:
            if pe.combined_embedding:
                target_embedding = np.array(pe.combined_embedding)
                similarity = self.compute_cosine_similarity(image_embedding, target_embedding)

                if similarity >= min_similarity:
                    similarities.append((pe.product_id, similarity))

        # Sort by similarity
        similarities.sort(key=lambda x: x[1], reverse=True)

        # Get product details
        product_ids = [pid for pid, _ in similarities[:limit]]
        products = db.query(Product).filter(Product.id.in_(product_ids)).all()

        # Map back to products with scores
        product_map = {p.id: p for p in products}
        results = [
            (product_map[pid], score)
            for pid, score in similarities[:limit]
            if pid in product_map
        ]

        return results

    def find_similar_by_style(
        self,
        db: Session,
        style: str,
        limit: int = 20,
    ) -> List[Tuple[Product, float]]:
        """Find products similar to a given style.

        Args:
            db: Database session
            style: Style name
            limit: Maximum number of results
            min_similarity: Minimum similarity threshold

        Returns:
            List of (product, similarity_score) tuples
        """
        # Get products with the specified style
        products = db.query(Product).filter(
            Product.style == style,
            Product.is_active == True,
        ).limit(100).all()

        if not products:
            return []

        # Get embeddings for these products
        product_ids = [p.id for p in products]
        embeddings = db.query(ProductEmbedding).filter(
            ProductEmbedding.product_id.in_(product_ids),
            ProductEmbedding.combined_embedding.isnot(None),
        ).all()

        if not embeddings:
            return []

        # Compute average style embedding
        style_embeddings = [np.array(pe.combined_embedding) for pe in embeddings]
        style_embedding = np.mean(style_embeddings, axis=0)

        # Find similar products to this style
        all_embeddings = db.query(ProductEmbedding).filter(
            ProductEmbedding.combined_embedding.isnot(None),
        ).all()

        similarities = []
        for pe in all_embeddings:
            if pe.combined_embedding:
                target_embedding = np.array(pe.combined_embedding)
                similarity = self.compute_cosine_similarity(style_embedding, target_embedding)
                similarities.append((pe.product_id, similarity))

        # Sort by similarity
        similarities.sort(key=lambda x: x[1], reverse=True)

        # Get product details
        product_ids = [pid for pid, _ in similarities[:limit]]
        products = db.query(Product).filter(Product.id.in_(product_ids)).all()

        # Map back to products with scores
        product_map = {p.id: p for p in products}
        results = [
            (product_map[pid], score)
            for pid, score in similarities[:limit]
            if pid in product_map
        ]

        return results
