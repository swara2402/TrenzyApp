"""pgvector-based similarity search for production vector operations.

Provides efficient vector similarity search using PostgreSQL pgvector extension
with HNSW indexes for fast approximate nearest neighbor search.

This replaces the NumPy-based cosine similarity search for production-scale
performance.
"""

from __future__ import annotations

import logging
from typing import List, Tuple, Optional
import numpy as np

from sqlalchemy.orm import Session
from sqlalchemy import text, func

from ...models import Product
from ..models_ai import ProductEmbedding, UserEmbedding

logger = logging.getLogger(__name__)


class PgvectorSearch:
    """Vector similarity search using pgvector with HNSW indexes."""

    def __init__(self):
        """Initialize pgvector search."""
        self._check_pgvector_available()

    def _check_pgvector_available(self) -> bool:
        """Check if pgvector extension is available."""
        try:
            from pgvector.sqlalchemy import Vector
            self.pgvector_available = True
            logger.info("pgvector extension available")
            return True
        except ImportError:
            self.pgvector_available = False
            logger.warning("pgvector not available, falling back to NumPy similarity")
            return False

    def find_similar_products_pgvector(
        self,
        db: Session,
        product_id: int,
        limit: int = 20,
        min_similarity: float = 0.5,
    ) -> List[Tuple[Product, float]]:
        """Find similar products using pgvector cosine similarity.

        Uses the efficient <=> operator for cosine distance with HNSW index.

        Args:
            db: Database session
            product_id: Query product ID
            limit: Maximum number of results
            min_similarity: Minimum similarity threshold

        Returns:
            List of (product, similarity_score) tuples
        """
        if not self.pgvector_available:
            logger.warning("pgvector not available, using fallback search")
            return self._find_similar_products_fallback(db, product_id, limit, min_similarity)

        try:
            # Get query product embedding
            query_embedding = db.query(ProductEmbedding).filter(
                ProductEmbedding.product_id == product_id
            ).first()

            if not query_embedding or not query_embedding.combined_embedding:
                logger.warning(f"No embedding found for product {product_id}")
                return []

            # Convert to numpy array and normalize for cosine similarity
            query_vector = np.array(query_embedding.combined_embedding)
            query_vector = query_vector / np.linalg.norm(query_vector)

            # Use pgvector <=> operator for cosine distance
            # Note: <=> returns cosine distance, so we convert to similarity: 1 - distance
            query_text = ", ".join([str(x) for x in query_vector])

            sql_query = text("""
                SELECT p.id, p.name, 1 - (pe.combined_embedding_vector <=> :query_vector::vector) as similarity
                FROM product_embeddings pe
                JOIN products p ON pe.product_id = p.id
                WHERE pe.product_id != :product_id
                AND pe.combined_embedding_vector IS NOT NULL
                AND p.is_active = true
                ORDER BY pe.combined_embedding_vector <=> :query_vector::vector
                LIMIT :limit
            """)

            result = db.execute(sql_query, {
                "query_vector": f"[{query_text}]",
                "product_id": product_id,
                "limit": limit * 2  # Get more results to filter by threshold
            }).fetchall()

            # Filter by similarity threshold and convert to Product objects
            product_ids = [row[0] for row in result if row[2] >= min_similarity]
            similarities = {row[0]: row[2] for row in result if row[2] >= min_similarity}

            if not product_ids:
                return []

            products = db.query(Product).filter(Product.id.in_(product_ids)).all()
            product_map = {p.id: p for p in products}

            results = [
                (product_map[pid], similarities[pid])
                for pid in product_ids
                if pid in product_map
            ][:limit]

            return results

        except Exception as e:
            logger.error(f"pgvector search failed: {e}, falling back to NumPy")
            return self._find_similar_products_fallback(db, product_id, limit, min_similarity)

    def _find_similar_products_fallback(
        self,
        db: Session,
        product_id: int,
        limit: int = 20,
        min_similarity: float = 0.5,
    ) -> List[Tuple[Product, float]]:
        """Fallback NumPy-based similarity search when pgvector unavailable."""
        from .vector_search import VectorSearch
        vector_search = VectorSearch()
        return vector_search.find_similar_products(db, product_id, limit, min_similarity)

    def visual_search_pgvector(
        self,
        db: Session,
        image_embedding: np.ndarray,
        limit: int = 20,
        min_similarity: float = 0.5,
        category_filter: Optional[str] = None,
    ) -> List[Tuple[Product, float]]:
        """Visual search using pgvector with optional category filter.

        Args:
            db: Database session
            image_embedding: Query image embedding
            limit: Maximum number of results
            min_similarity: Minimum similarity threshold
            category_filter: Optional category filter

        Returns:
            List of (product, similarity_score) tuples
        """
        if not self.pgvector_available:
            logger.warning("pgvector not available, using fallback search")
            return self._visual_search_fallback(db, image_embedding, limit, min_similarity, category_filter)

        try:
            # Normalize query vector
            query_vector = image_embedding / np.linalg.norm(image_embedding)
            query_text = ", ".join([str(x) for x in query_vector])

            # Build SQL query with optional category filter
            if category_filter:
                sql_query = text("""
                    SELECT p.id, p.name, 1 - (pe.combined_embedding_vector <=> :query_vector::vector) as similarity
                    FROM product_embeddings pe
                    JOIN products p ON pe.product_id = p.id
                    JOIN categories c ON p.category_id = c.id
                    WHERE pe.combined_embedding_vector IS NOT NULL
                    AND p.is_active = true
                    AND c.name = :category
                    ORDER BY pe.combined_embedding_vector <=> :query_vector::vector
                    LIMIT :limit
                """)
                params = {
                    "query_vector": f"[{query_text}]",
                    "category": category_filter,
                    "limit": limit * 2
                }
            else:
                sql_query = text("""
                    SELECT p.id, p.name, 1 - (pe.combined_embedding_vector <=> :query_vector::vector) as similarity
                    FROM product_embeddings pe
                    JOIN products p ON pe.product_id = p.id
                    WHERE pe.combined_embedding_vector IS NOT NULL
                    AND p.is_active = true
                    ORDER BY pe.combined_embedding_vector <=> :query_vector::vector
                    LIMIT :limit
                """)
                params = {
                    "query_vector": f"[{query_text}]",
                    "limit": limit * 2
                }

            result = db.execute(sql_query, params).fetchall()

            # Filter by similarity threshold
            product_ids = [row[0] for row in result if row[2] >= min_similarity]
            similarities = {row[0]: row[2] for row in result if row[2] >= min_similarity}

            if not product_ids:
                return []

            products = db.query(Product).filter(Product.id.in_(product_ids)).all()
            product_map = {p.id: p for p in products}

            results = [
                (product_map[pid], similarities[pid])
                for pid in product_ids
                if pid in product_map
            ][:limit]

            return results

        except Exception as e:
            logger.error(f"pgvector visual search failed: {e}, falling back to NumPy")
            return self._visual_search_fallback(db, image_embedding, limit, min_similarity, category_filter)

    def _visual_search_fallback(
        self,
        db: Session,
        image_embedding: np.ndarray,
        limit: int = 20,
        min_similarity: float = 0.5,
        category_filter: Optional[str] = None,
    ) -> List[Tuple[Product, float]]:
        """Fallback NumPy-based visual search when pgvector unavailable."""
        from .vector_search import VectorSearch
        vector_search = VectorSearch()
        return vector_search.visual_search(db, image_embedding, limit, min_similarity, category_filter)

    def migrate_embeddings_to_pgvector(self, db: Session, batch_size: int = 100) -> dict:
        """Migrate existing JSON embeddings to pgvector columns.

        This is a one-time migration to populate the pgvector columns
        with data from the existing JSON columns.

        Args:
            db: Database session
            batch_size: Number of embeddings to migrate per batch

        Returns:
            Migration statistics
        """
        if not self.pgvector_available:
            logger.warning("pgvector not available, skipping migration")
            return {"status": "skipped", "reason": "pgvector not available"}

        stats = {
            "user_embeddings_migrated": 0,
            "product_embeddings_migrated": 0,
            "errors": 0
        }

        try:
            # Migrate user embeddings
            user_embeddings = db.query(UserEmbedding).filter(
                UserEmbedding.embedding.isnot(None)
            ).all()

            for i, ue in enumerate(user_embeddings):
                try:
                    if ue.embedding and len(ue.embedding) > 0:
                        # Use raw SQL to update the vector column
                        vector_text = ",".join([str(x) for x in ue.embedding])
                        db.execute(text("""
                            UPDATE user_embeddings 
                            SET embedding_vector = :vector::vector
                            WHERE id = :id
                        """), {"vector": f"[{vector_text}]", "id": ue.id})
                        stats["user_embeddings_migrated"] += 1

                        if (i + 1) % batch_size == 0:
                            db.commit()
                            logger.info(f"Migrated {i + 1}/{len(user_embeddings)} user embeddings")

                except Exception as e:
                    logger.error(f"Failed to migrate user embedding {ue.id}: {e}")
                    stats["errors"] += 1

            db.commit()

            # Migrate product embeddings
            product_embeddings = db.query(ProductEmbedding).filter(
                ProductEmbedding.combined_embedding.isnot(None)
            ).all()

            for i, pe in enumerate(product_embeddings):
                try:
                    if pe.combined_embedding and len(pe.combined_embedding) > 0:
                        vector_text = ",".join([str(x) for x in pe.combined_embedding])
                        db.execute(text("""
                            UPDATE product_embeddings 
                            SET combined_embedding_vector = :vector::vector
                            WHERE id = :id
                        """), {"vector": f"[{vector_text}]", "id": pe.id})
                        stats["product_embeddings_migrated"] += 1

                        if (i + 1) % batch_size == 0:
                            db.commit()
                            logger.info(f"Migrated {i + 1}/{len(product_embeddings)} product embeddings")

                except Exception as e:
                    logger.error(f"Failed to migrate product embedding {pe.id}: {e}")
                    stats["errors"] += 1

            db.commit()
            logger.info(f"Migration complete: {stats}")
            return stats

        except Exception as e:
            logger.error(f"Migration failed: {e}")
            db.rollback()
            stats["status"] = "failed"
            stats["error"] = str(e)
            return stats


# Singleton instance
_pgvector_search_instance: Optional[PgvectorSearch] = None


def get_pgvector_search() -> PgvectorSearch:
    """Get singleton pgvector search instance."""
    global _pgvector_search_instance
    if _pgvector_search_instance is None:
        _pgvector_search_instance = PgvectorSearch()
    return _pgvector_search_instance