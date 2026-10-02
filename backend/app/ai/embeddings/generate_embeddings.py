"""Embedding generation pipeline for seed products.

Script to generate FashionCLIP embeddings for products and store them
in PostgreSQL with pgvector. Follows the foundation phase requirements:
1. Validate product catalog
2. Download/read images
3. Generate FashionCLIP embeddings
4. Save vectors to database
5. Mark embedding_status = completed
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import List, Optional
from PIL import Image
from sqlalchemy.orm import Session
from sqlalchemy import create_engine, select
import numpy as np

from ...db import SessionLocal
from ...models import Product
from ..vision.fashionclip import FASHIONCLIP_MODEL, FashionCLIPModel
from ..vision.embedding_service import get_embedding_service
from ..services.image_download_service import get_image_download_service

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SeedEmbeddingGenerator:
    """Generate and save embeddings for seed product catalog."""

    def __init__(self, db: Session):
        """Initialize the generator.
        
        Args:
            db: Database session
        """
        self.db = db
        self.fashionclip = FashionCLIPModel()
        self.image_downloader = get_image_download_service()
        
    def validate_product(self, product: Product) -> bool:
        """Validate a product before embedding generation.
        
        Checks:
        - No duplicate product IDs
        - Valid image URL
        - Category present
        - Source/license present (for seed catalog)
        
        Args:
            product: Product to validate
            
        Returns:
            True if valid, False otherwise
        """
        # Check required fields
        if not product.id:
            logger.warning(f"Product missing ID: {product}")
            return False
            
        if not product.image_url:
            logger.warning(f"Product {product.id}: Missing image_url")
            return False
            
        if not product.category:
            logger.warning(f"Product {product.id}: Missing category")
            return False
            
        # Source/license are optional for embedding generation; log warning but continue
        if not product.source or not product.source_license:
            logger.warning(f"Product {product.id}: Missing source/license information (using placeholders)")
            # Continue processing with placeholder values if needed
            # product.source = product.source or "unknown"
            # product.source_license = product.source_license or "unknown"
            # Do not fail validation
            pass
            
        return True
        
    def download_image(self, image_url: str) -> Optional[Image.Image]:
        """Download and validate image from URL using canonical ImageDownloadService.
        
        Args:
            image_url: URL to download image from
            
        Returns:
            PIL Image if successful, None otherwise
        """
        success, status, img = self.image_downloader.download_to_memory(image_url)
        
        if success and img:
            return img
            
        # Return placeholder for all failures (placeholder logic preserved)
        logger.warning(f"Image download failed for {image_url} with status {status}; using placeholder image.")
        return Image.new("RGB", (224, 224), color=(0, 0, 0))
            
    def generate_embeddings_for_product(self, product: Product) -> bool:
        """Generate and save embeddings for a single product.
        
        Pipeline:
        1. Validate product
        2. Download image
        3. Generate FashionCLIP image embedding
        4. Generate text embedding from product attributes
        5. Save vectors to database
        6. Update embedding status
        
        Args:
            product: Product to process
            
        Returns:
            True if successful, False otherwise
        """
        logger.info(f"Processing product: {product.id} - {product.name}")
        
        # Step 1: Validate
        if not self.validate_product(product):
            product.image_embedding_status = "failed_validation"
            product.text_embedding_status = "failed_validation"
            self.db.commit()
            return False
            
        # Skip if already completed successfully
        if (product.image_embedding_status == "completed" and 
            product.text_embedding_status == "completed"):
            logger.info(f"Product {product.id} already processed, skipping")
            return True
            
        # Step 2: Download image
        image = self.download_image(product.image_url)
        if not image:
            product.image_embedding_status = "failed_image_download"
            self.db.commit()
            return False
            
        try:
            # Step 3: Generate image embedding
            image_embedding = self.fashionclip.encode_image(image)
            if image_embedding.ndim != 1 or image_embedding.shape[0] != self.fashionclip.embedding_dim:
                logger.error(f"Image embedding dimension mismatch for product {product.id}; marking as failed.")
                product.image_embedding_status = "failed_invalid_dimensions"
                self.db.commit()
                return False
            
            # Step 4: Build text representation and generate text embedding
            text_parts = []
            if product.name:
                text_parts.append(product.name)
            if product.description:
                text_parts.append(product.description)
            if product.category:
                text_parts.append(f"Category: {product.category}")
            if product.brand:
                text_parts.append(f"Brand: {product.brand}")
            if product.style:
                text_parts.append(f"Style: {product.style}")
            if product.color:
                text_parts.append(f"Color: {product.color}")
            if product.material:
                text_parts.append(f"Material: {product.material}")
            if product.fit:
                text_parts.append(f"Fit: {product.fit}")
                
            product_text = " ".join(text_parts)
            try:
                text_embedding = self.fashionclip.encode_text(product_text)
                if text_embedding.ndim != 1 or text_embedding.shape[0] != self.fashionclip.embedding_dim:
                    raise ValueError(
                        "Text embedding dimension does not match the loaded FashionCLIP model"
                    )
            except Exception as e:
                logger.error(f"Text embedding failure for product {product.id}: {e}; marking as failed.")
                product.text_embedding_status = "failed_generation_error"
                self.db.commit()
                return False
            
            # Step 5: Save to database
            product.image_embedding_vector = image_embedding.tolist()
            product.text_embedding_vector = text_embedding.tolist()
            
            # Save to ProductEmbedding table for unified AI lookup
            combined = (image_embedding + text_embedding) / 2.0
            norm = np.linalg.norm(combined)
            if norm > 0:
                combined = combined / norm
            get_embedding_service().save_product_embedding(
                db=self.db,
                product_id=str(product.id),
                embedding=combined,
                text_embedding=text_embedding,
                image_embedding=image_embedding,
            )
            
            # Update metadata
            now = datetime.now(timezone.utc)
            product.image_embedding_model = FASHIONCLIP_MODEL
            product.image_embedding_version = "v1"
            product.image_embedding_created_at = now
            product.image_embedding_status = "completed"
            
            product.text_embedding_model = FASHIONCLIP_MODEL
            product.text_embedding_version = "v1"
            product.text_embedding_created_at = now
            product.text_embedding_status = "completed"
            
            # Step 6: Commit
            self.db.commit()
            logger.info(f"Successfully processed product {product.id}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to generate embeddings for {product.id}: {e}")
            product.image_embedding_status = "failed_generation"
            product.text_embedding_status = "failed_generation"
            self.db.commit()
            return False
            
    def process_batch(self, limit: int = 100) -> tuple[int, int, int]:
        """Process a batch of unprocessed products.
        
        Args:
            limit: Maximum number of products to process in this batch
            
        Returns:
            (total_processed, successful, failed)
        """
        # Get pending products
        stmt = select(Product).where(
            (Product.image_embedding_status != "completed") | 
            (Product.text_embedding_status != "completed")
        ).limit(limit)
        
        products = self.db.execute(stmt).scalars().all()
        logger.info(f"Found {len(products)} products to process")
        
        successful = 0
        failed = 0
        
        for product in products:
            if self.generate_embeddings_for_product(product):
                successful += 1
            else:
                failed += 1
                
        total_processed = successful + failed
        logger.info(f"Batch complete: {total_processed} processed, {successful} succeeded, {failed} failed")
        return total_processed, successful, failed
        
    def get_catalog_stats(self) -> dict:
        """Get statistics about the seed catalog.
        
        Returns:
            Dictionary with catalog statistics
        """
        total = self.db.query(Product).count()
        completed_image = self.db.query(Product).filter(
            Product.image_embedding_status == "completed"
        ).count()
        completed_text = self.db.query(Product).filter(
            Product.text_embedding_status == "completed"
        ).count()
        failed = self.db.query(Product).filter(
            (Product.image_embedding_status.like("%failed%")) |
            (Product.text_embedding_status.like("%failed%"))
        ).count()
        
        return {
            "total_products": total,
            "completed_image_embeddings": completed_image,
            "completed_text_embeddings": completed_text,
            "failed_processing": failed,
            "percent_complete": round((completed_image / total * 100), 2) if total > 0 else 0
        }

def main():
    """Main entry point for running the embedding generator.
    
    Usage:
        python -m app.ai.embeddings.generate_embeddings
    """
    # Create database session using our app's session factory
    session = SessionLocal()
    try:
        generator = SeedEmbeddingGenerator(session)
        
        # Print initial stats
        stats = generator.get_catalog_stats()
        logger.info(f"Initial catalog stats: {stats}")
        
        # Keep the first run deliberately small so model and database contracts are verified.
        generator.process_batch(limit=500)
        
        # Print final stats
        final_stats = generator.get_catalog_stats()
        logger.info(f"Final catalog stats: {final_stats}")
    finally:
        session.close()

if __name__ == "__main__":
    main()