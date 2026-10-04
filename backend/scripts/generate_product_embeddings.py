#!/usr/bin/env python3
"""Generate FashionCLIP embeddings for all products in the catalog.

This script:
1. Loads all active products from the database
2. Generates FashionCLIP embeddings for each product
3. Saves embeddings to the product_embeddings table
4. Supports batch processing for efficiency
5. Migrates embeddings to pgvector when available

Usage:
    python scripts/generate_product_embeddings.py
    python scripts/generate_product_embeddings.py --batch-size 64
    python scripts/generate_product_embeddings.py --limit 1000
    python scripts/generate_product_embeddings.py --migrate-pgvector
"""

import argparse
import logging
import sys
from pathlib import Path
from typing import Optional

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.db import SessionLocal
from app.models import Product
from app.ai.vision.embedding_service import get_embedding_service
from app.ai.models_ai import ProductEmbedding
from app.ai.vision.pgvector_search import get_pgvector_search

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def generate_embeddings(
    batch_size: int = 32,
    limit: Optional[int] = None,
    skip_existing: bool = True,
    migrate_pgvector: bool = False,
):
    """Generate embeddings for all products.

    Args:
        batch_size: Batch size for embedding generation
        limit: Maximum number of products to process (None for all)
        skip_existing: Skip products that already have embeddings
        migrate_pgvector: Migrate embeddings to pgvector after generation
    """
    db = SessionLocal()
    embedding_service = get_embedding_service()

    try:
        # Get products
        query = db.query(Product).filter(Product.is_active == True)

        if skip_existing:
            # Get product IDs that already have embeddings
            existing_ids = db.query(ProductEmbedding.product_id).all()
            existing_ids = [pid[0] for pid in existing_ids]
            if existing_ids:
                query = query.filter(~Product.id.in_(existing_ids))
                logger.info(f"Skipping {len(existing_ids)} products with existing embeddings")

        if limit:
            query = query.limit(limit)

        products = query.all()
        total = len(products)

        logger.info(f"Generating embeddings for {total} products (batch_size={batch_size})")

        if total == 0:
            logger.info("No products to process")
            return

        # Process in batches
        processed = 0
        failed = 0

        for i in range(0, total, batch_size):
            batch = products[i:i + batch_size]
            logger.info(f"Processing batch {i // batch_size + 1}/{(total + batch_size - 1) // batch_size}")

            try:
                # Generate embeddings for batch
                embeddings = embedding_service.generate_product_embeddings_batch(
                    batch, batch_size=batch_size
                )

                # Save embeddings
                for product in batch:
                    if product.id in embeddings:
                        embedding_service.save_product_embedding(
                            db, product.id, embeddings[product.id]
                        )
                        processed += 1
                    else:
                        logger.warning(f"Failed to generate embedding for product {product.id}")
                        failed += 1

                db.commit()
                logger.info(f"Batch complete: {processed}/{total} processed, {failed} failed")

            except Exception as e:
                db.rollback()
                logger.error(f"Batch failed: {e}")
                failed += len(batch)

        logger.info(f"Complete: {processed} embeddings generated, {failed} failed")

        # Migrate to pgvector if requested
        if migrate_pgvector:
            logger.info("Migrating embeddings to pgvector...")
            pgvector_search = get_pgvector_search()
            migration_stats = pgvector_search.migrate_embeddings_to_pgvector(db, batch_size=batch_size)
            logger.info(f"Migration stats: {migration_stats}")

    finally:
        db.close()


def main():
    parser = argparse.ArgumentParser(description="Generate FashionCLIP embeddings for products")
    parser.add_argument(
        "--batch-size",
        type=int,
        default=32,
        help="Batch size for embedding generation (default: 32)"
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Maximum number of products to process (default: all)"
    )
    parser.add_argument(
        "--skip-existing",
        action="store_true",
        default=True,
        help="Skip products that already have embeddings (default: True)"
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Regenerate embeddings for all products (overrides --skip-existing)"
    )
    parser.add_argument(
        "--migrate-pgvector",
        action="store_true",
        help="Migrate embeddings to pgvector after generation"
    )

    args = parser.parse_args()

    if args.force:
        args.skip_existing = False

    logger.info("Starting product embedding generation...")
    logger.info(f"Batch size: {args.batch_size}")
    logger.info(f"Limit: {args.limit or 'all'}")
    logger.info(f"Skip existing: {args.skip_existing}")
    logger.info(f"Migrate to pgvector: {args.migrate_pgvector}")

    generate_embeddings(
        batch_size=args.batch_size,
        limit=args.limit,
        skip_existing=args.skip_existing,
        migrate_pgvector=args.migrate_pgvector,
    )

    logger.info("Done")


if __name__ == "__main__":
    main()
