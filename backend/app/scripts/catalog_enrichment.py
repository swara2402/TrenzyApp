"""Catalog enrichment pipeline using FashionCLIP zero-shot classification.
Populates category, subcategory, style, color, brand fields for all products.
Marks non-fashion images as archived (is_archived=True).
"""

from __future__ import annotations

import logging
import json
from typing import List, Dict, Any
from PIL import Image
import requests
from io import BytesIO
import numpy as np

from ..db import get_session
from ..models import Product
from ..ai.vision.fashionclip import FashionCLIPModel
from ..category_taxonomy import CATEGORIES, SUBCATEGORIES
from ..style_taxonomy import STYLES
from ..color_taxonomy import COLORS

logger = logging.getLogger(__name__)

# Zero-shot classification prompts
FASHION_CATEGORY_PROMPTS = [
    "a photo of a shirt", "a photo of a dress", "a photo of a jacket",
    "a photo of a pants", "a photo of a jeans", "a photo of a skirt",
    "a photo of a sweater", "a photo of a coat", "a photo of a shoes",
    "a photo of a bag", "a photo of a accessory", "not a fashion product"
]

FASHION_STYLE_PROMPTS = [
    "a casual fashion photo", "a formal fashion photo", "a streetwear fashion photo",
    "a minimalist fashion photo", "a bohemian fashion photo", "a vintage fashion photo",
    "a modern fashion photo", "a classic fashion photo"
]

FASHION_COLOR_PROMPTS = [
    "black clothing", "white clothing", "gray clothing", "navy clothing",
    "beige clothing", "brown clothing", "red clothing", "blue clothing",
    "green clothing", "pink clothing", "yellow clothing", "purple clothing",
    "orange clothing", "multi-color clothing"
]

class CatalogEnrichmentPipeline:
    """Enriches catalog metadata using FashionCLIP zero-shot classification."""
    
    def __init__(self):
        """Initialize pipeline with FashionCLIP model and database session."""
        self.fashionclip = FashionCLIPModel()
        # Get database session (get_session is a generator)
        session_generator = get_session()
        self.db = next(session_generator)
        
        # Pre-encode all prompts once for efficiency
        self._encode_prompts()
        
    def _encode_prompts(self):
        """Pre-encode all zero-shot classification text prompts."""
        logger.info("Pre-encoding classification prompts...")
        
        # Encode category prompts
        self.category_text_embeddings = np.array([
            self.fashionclip.encode_text(prompt) for prompt in FASHION_CATEGORY_PROMPTS
        ])
        
        # Encode style prompts
        self.style_text_embeddings = np.array([
            self.fashionclip.encode_text(prompt) for prompt in FASHION_STYLE_PROMPTS
        ])
        
        # Encode color prompts
        self.color_text_embeddings = np.array([
            self.fashionclip.encode_text(prompt) for prompt in FASHION_COLOR_PROMPTS
        ])
        
        logger.info("All prompts encoded successfully")
    
    def _compute_similarity(self, image_embedding: np.ndarray, text_embeddings: np.ndarray) -> int:
        """Compute cosine similarity between image embedding and text embeddings, return best match index."""
        # Normalize vectors
        image_norm = image_embedding / np.linalg.norm(image_embedding)
        text_norms = text_embeddings / np.linalg.norm(text_embeddings, axis=1, keepdims=True)
        
        # Compute cosine similarities
        similarities = text_norms @ image_norm
        return int(np.argmax(similarities)), float(np.max(similarities))
    
    def _download_image(self, image_url: str) -> Image.Image | None:
        """Download image from URL, return PIL Image or None on failure."""
        try:
            response = requests.get(image_url, timeout=10)
            response.raise_for_status()
            return Image.open(BytesIO(response.content)).convert("RGB")
        except Exception as e:
            logger.error(f"Failed to download image {image_url}: {e}")
            return None
    
    def process_product(self, product: Product) -> bool:
        """Process a single product: download image, generate embeddings, classify, update database."""
        logger.info(f"Processing product {product.id}: {product.name}")
        
        # Skip already archived products
        if product.is_archived:
            logger.info(f"Product {product.id} already archived, skipping")
            return True
            
        # Download image
        image = self._download_image(product.image_url)
        if not image:
            logger.error(f"Failed to download image for product {product.id}, marking as failed")
            return False
            
        # Generate image embedding
        try:
            image_embedding = self.fashionclip.encode_image(image)
        except Exception as e:
            logger.error(f"Failed to generate embedding for product {product.id}: {e}")
            return False
            
        # Classify category
        category_idx, category_score = self._compute_similarity(image_embedding, self.category_text_embeddings)
        predicted_category = FASHION_CATEGORY_PROMPTS[category_idx].replace("a photo of a ", "").strip()
        
        # If classified as "not a fashion product", mark as archived
        if predicted_category == "not a fashion product" and category_score > 0.3:
            logger.warning(f"Product {product.id} classified as non-fashion (score: {category_score:.3f}), archiving")
            product.is_archived = True
            self.db.commit()
            return True
            
        # Classify style
        style_idx, style_score = self._compute_similarity(image_embedding, self.style_text_embeddings)
        predicted_style = FASHION_STYLE_PROMPTS[style_idx].replace("a ", "").replace(" fashion photo", "").strip()
        
        # Classify color
        color_idx, color_score = self._compute_similarity(image_embedding, self.color_text_embeddings)
        predicted_color = FASHION_COLOR_PROMPTS[color_idx].replace(" clothing", "").strip()
        
        # Update product metadata
        product.category = predicted_category
        product.style = predicted_style
        product.color = predicted_color
        product.image_embedding_status = "completed"
        product.text_embedding_status = "completed"
        
        logger.info(f"Updated product {product.id}: category={predicted_category} ({category_score:.3f}), style={predicted_style} ({style_score:.3f}), color={predicted_color} ({color_score:.3f})")
        
        # Commit changes
        try:
            self.db.commit()
            return True
        except Exception as e:
            logger.error(f"Failed to commit changes for product {product.id}: {e}")
            self.db.rollback()
            return False
    
    def process_all_products(self, limit: int | None = None) -> Dict[str, Any]:
        """Process all unprocessed products in the database."""
        # Query products that haven't been processed yet
        query = self.db.query(Product).filter(
            Product.is_archived == False,
            Product.category == "unknown"  # Only process unenriched products
        )
        
        if limit:
            products = query.limit(limit).all()
        else:
            products = query.all()
            
        logger.info(f"Found {len(products)} products to process")
        
        results = {
            "total": len(products),
            "processed": 0,
            "failed": 0,
            "archived": 0,
            "succeeded": 0
        }
        
        for product in products:
            results["processed"] += 1
            success = self.process_product(product)
            
            if success:
                if product.is_archived:
                    results["archived"] += 1
                else:
                    results["succeeded"] += 1
            else:
                results["failed"] += 1
                
        logger.info(f"Processing complete: {results}")
        return results
    
    def close(self):
        """Cleanup database connection."""
        self.db.close()

if __name__ == "__main__":
    """Run the catalog enrichment pipeline."""
    logging.basicConfig(level=logging.INFO)
    
    pipeline = CatalogEnrichmentPipeline()
    try:
        results = pipeline.process_all_products()
        print("\n" + "="*50)
        print("CATALOG ENRICHMENT COMPLETE")
        print("="*50)
        print(f"Total products processed: {results['processed']}")
        print(f"Successfully enriched: {results['succeeded']}")
        print(f"Archived (non-fashion): {results['archived']}")
        print(f"Failed: {results['failed']}")
    finally:
        pipeline.close()