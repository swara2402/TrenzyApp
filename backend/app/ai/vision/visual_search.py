"""Visual fashion search.

Allows users to upload an image and find similar fashion items.
"""

from __future__ import annotations

from typing import List, Optional, Tuple
import logging
import numpy as np

from PIL import Image
from sentence_transformers import SentenceTransformer
from sqlalchemy.orm import Session

from ...models import Product
from ..models_ai import ProductEmbedding

logger = logging.getLogger(__name__)


class VisualFashionSearch:
    """Visual search for fashion items."""

    def __init__(
        self,
        image_model_name: str = "clip-ViT-B-32",
        device: str = "cpu",
    ):
        """Initialize visual search.

        Args:
            image_model_name: CLIP model for image embeddings
            device: Device to run on
        """
        self.device = device
        logger.info(f"Loading image model: {image_model_name}")
        self.image_model = SentenceTransformer(image_model_name, device=device)

    def encode_image(self, image_path: str) -> np.ndarray:
        """Encode an image to embedding vector.

        Args:
            image_path: Path to image file

        Returns:
            Image embedding vector
        """
        try:
            image = Image.open(image_path)
            if image.mode != "RGB":
                image = image.convert("RGB")
            embedding = self.image_model.encode(image, convert_to_numpy=True)
            return embedding
        except Exception as e:
            logger.error(f"Failed to encode image: {e}")
            # Never return zero vector - raise exception to prevent embedding contamination
            raise RuntimeError(f"Image encoding failed: {str(e)}") from e

    def encode_image_bytes(self, image_bytes: bytes) -> np.ndarray:
        """Encode image bytes to embedding vector.

        Args:
            image_bytes: Image data as bytes

        Returns:
            Image embedding vector
        """
        try:
            image = Image.open(image_bytes)
            if image.mode != "RGB":
                image = image.convert("RGB")
            embedding = self.image_model.encode(image, convert_to_numpy=True)
            return embedding
        except Exception as e:
            logger.error(f"Failed to encode image bytes: {e}")
            # Never return zero vector - raise exception to prevent embedding contamination
            raise RuntimeError(f"Image byte encoding failed: {str(e)}") from e

    def search_similar_products(
        self,
        db: Session,
        image_embedding: np.ndarray,
        limit: int = 20,
        min_similarity: float = 0.5,
    ) -> List[Tuple[Product, float]]:
        """Search for products similar to an image using pgvector.

        Uses PostgreSQL pgvector extension's built-in similarity search for efficient
        vector queries. Falls back to in-memory calculation if pgvector is not available.

        Args:
            db: Database session
            image_embedding: Query image embedding
            limit: Number of results to return
            min_similarity: Minimum similarity threshold

        Returns:
            List of (product, similarity_score) tuples
        """
        from ...models import PGVECTOR_AVAILABLE
        
        if PGVECTOR_AVAILABLE:
            # Use pgvector's efficient similarity search (<=> operator is cosine distance)
            # Convert our numpy array to a list for SQLAlchemy
            embedding_list = image_embedding.tolist()
            
            # Query products with completed embeddings, order by similarity
            from sqlalchemy import func
            products = db.query(
                Product,
                (1 - Product.image_embedding_vector.cosine_distance(embedding_list)).label('similarity')
            ).filter(
                Product.image_embedding_status == "completed",
                Product.image_embedding_vector.isnot(None),
                Product.is_archived == False,
            ).order_by(
                Product.image_embedding_vector.cosine_distance(embedding_list)
            ).limit(limit).all()
            
            # Format results and filter by min_similarity
            results = []
            for product, similarity in products:
                if similarity >= min_similarity:
                    results.append((product, float(similarity)))
            
            return results
        else:
            # Fallback to in-memory calculation for non-pgvector environments
            # Get all products with completed embeddings
            products = db.query(Product).filter(
                Product.image_embedding_status == "completed",
                Product.image_embedding_vector.isnot(None),
                Product.is_archived == False,
            ).all()
            
            if not products:
                logger.warning("No product image embeddings found")
                return []

            # Compute similarities
            results = []
            for product in products:
                if product.image_embedding_vector:
                    product_emb = np.array(product.image_embedding_vector)
                    similarity = self._cosine_similarity(image_embedding, product_emb)

                    if similarity >= min_similarity:
                        results.append((product, similarity))

            # Sort by similarity
            results.sort(key=lambda x: x[1], reverse=True)

            return results[:limit]

    def _cosine_similarity(
        self,
        vec1: np.ndarray,
        vec2: np.ndarray,
    ) -> float:
        """Compute cosine similarity between two vectors.

        Args:
            vec1: First vector
            vec2: Second vector

        Returns:
            Similarity score (0-1)
        """
        dot_product = np.dot(vec1, vec2)
        norm1 = np.linalg.norm(vec1)
        norm2 = np.linalg.norm(vec2)

        if norm1 == 0 or norm2 == 0:
            return 0.0

        return dot_product / (norm1 * norm2)

    def analyze_fashion_attributes(
        self,
        image_embedding: np.ndarray,
    ) -> dict:
        """Analyze fashion attributes from image.

        This is a simplified version. A full implementation would use
        a dedicated fashion attribute detection model.

        Args:
            image_embedding: Image embedding

        Returns:
            Dictionary of detected attributes
        """
        # In a full implementation, this would use a model like:
        # - Fashion-CLIP for attribute classification
        # - A dedicated segmentation model
        # - Color detection model

        # For now, return placeholder
        return {
            "dominant_colors": ["black", "white"],
            "style": "casual",
            "garment_type": "top",
            "pattern": "solid",
            "confidence": 0.7,
        }