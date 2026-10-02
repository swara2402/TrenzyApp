"""Product embedding pipeline.

Generates multimodal embeddings for products combining:
- Text embeddings (name, description, attributes)
- Image embeddings (product images)
- Combined multimodal embedding
"""

from __future__ import annotations

from typing import Optional, List
import logging

from sentence_transformers import SentenceTransformer
from PIL import Image
import torch
import numpy as np

from ...models import Product
from ..models_ai import ProductEmbedding

logger = logging.getLogger(__name__)


class ProductEmbeddingPipeline:
    """Generates and manages product embeddings."""

    def __init__(
        self,
        text_model_name: str = "all-MiniLM-L6-v2",
        image_model_name: str = "Marqo/marqo-fashionCLIP",
        device: Optional[str] = None,
    ):
        """Initialize embedding models.

        Uses FashionCLIP for fashion-specific image understanding.

        Args:
            text_model_name: Sentence transformer model for text
            image_model_name: FashionCLIP model for fashion images
            device: Device to run models on (cuda/cpu)
        """
        self.device = device or ("cuda" if torch.cuda.is_available() else "cpu")
        logger.info(f"Loading text model: {text_model_name}")
        self.text_model = SentenceTransformer(text_model_name, device=self.device)
        logger.info(f"Loading FashionCLIP model: {image_model_name}")
        self.image_model = SentenceTransformer(image_model_name, device=self.device)

    def _build_text_representation(self, product: Product) -> str:
        """Build text representation from product attributes.

        Args:
            product: Product model instance

        Returns:
            Combined text string for embedding
        """
        parts = []

        # Core attributes
        if product.name:
            parts.append(product.name)
        if product.description:
            parts.append(product.description)

        # Category and brand
        if product.category:
            parts.append(f"Category: {product.category}")
        if product.brand:
            parts.append(f"Brand: {product.brand}")

        # Style attributes
        if product.style:
            parts.append(f"Style: {product.style}")
        if product.occasion:
            parts.append(f"Occasion: {product.occasion}")
        if product.material:
            parts.append(f"Material: {product.material}")
        if product.fit:
            parts.append(f"Fit: {product.fit}")

        # Color
        if product.color:
            parts.append(f"Color: {product.color}")

        return " ".join(parts)

    def generate_text_embedding(self, product: Product) -> np.ndarray:
        """Generate text embedding for a product.

        Args:
            product: Product model instance

        Returns:
            Text embedding vector
        """
        text = self._build_text_representation(product)
        embedding = self.text_model.encode(text, convert_to_numpy=True)
        return embedding

    def generate_image_embedding(
        self,
        image_path: str,
    ) -> np.ndarray:
        """Generate image embedding from product image.

        Args:
            image_path: Path to product image

        Returns:
            Image embedding vector
        """
        try:
            image = Image.open(image_path)
            # Convert to RGB if necessary
            if image.mode != "RGB":
                image = image.convert("RGB")
            embedding = self.image_model.encode(image, convert_to_numpy=True)
            return embedding
        except Exception as e:
            logger.error(f"Failed to generate image embedding: {e}")
            # Never return zero vector - raise exception to prevent embedding contamination
            raise RuntimeError(f"Image embedding generation failed: {str(e)}") from e

    def generate_combined_embedding(
        self,
        text_embedding: np.ndarray,
        image_embedding: np.ndarray,
        text_weight: float = 0.5,
    ) -> np.ndarray:
        """Combine text and image embeddings.

        Args:
            text_embedding: Text embedding vector
            image_embedding: Image embedding vector
            text_weight: Weight for text embedding (0-1)

        Returns:
            Combined embedding vector
        """
        # Normalize embeddings
        text_norm = text_embedding / (np.linalg.norm(text_embedding) + 1e-8)
        image_norm = image_embedding / (np.linalg.norm(image_embedding) + 1e-8)

        # Weighted combination
        combined = text_weight * text_norm + (1 - text_weight) * image_norm

        # Renormalize
        combined = combined / (np.linalg.norm(combined) + 1e-8)

        return combined

    def generate_product_embeddings(
        self,
        product: Product,
        image_path: Optional[str] = None,
        model_version: str = "v1.0",
    ) -> dict:
        """Generate all embeddings for a product.

        Args:
            product: Product model instance
            image_path: Optional path to product image
            model_version: Model version identifier

        Returns:
            Dictionary with text, image, and combined embeddings
        """
        text_embedding = self.generate_text_embedding(product)
        image_embedding = None

        if image_path:
            image_embedding = self.generate_image_embedding(image_path)

        combined_embedding = None
        if image_embedding is not None:
            combined_embedding = self.generate_combined_embedding(
                text_embedding, image_embedding
            )
        else:
            # If no image, use text embedding as combined
            combined_embedding = text_embedding / (np.linalg.norm(text_embedding) + 1e-8)

        return {
            "text_embedding": text_embedding.tolist(),
            "image_embedding": image_embedding.tolist() if image_embedding is not None else None,
            "combined_embedding": combined_embedding.tolist(),
            "dimension": len(text_embedding),
            "model_version": model_version,
        }


def compute_cosine_similarity(
    embedding1: List[float],
    embedding2: List[float],
) -> float:
    """Compute cosine similarity between two embeddings.

    Args:
        embedding1: First embedding vector
        embedding2: Second embedding vector

    Returns:
        Cosine similarity score (0-1)
    """
    vec1 = np.array(embedding1)
    vec2 = np.array(embedding2)

    dot_product = np.dot(vec1, vec2)
    norm1 = np.linalg.norm(vec1)
    norm2 = np.linalg.norm(vec2)

    if norm1 == 0 or norm2 == 0:
        return 0.0

    return dot_product / (norm1 * norm2)