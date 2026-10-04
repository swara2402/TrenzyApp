"""Setup demo database with products, users, and synthetic interactions.

Run this script to prepare a local SQLite database for training:
    python -m scripts.setup_demo_database
"""

import os
import sys
import logging
from pathlib import Path

# Use PostgreSQL database (Docker container) instead of SQLite
os.environ.pop("TRENZY_TEST_DB", None)
os.environ["APP_ENV"] = "development"

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent))

import json
from sqlalchemy.orm import Session
from app.db import engine, Base, SessionLocal
from app.models import User, Product
sys.path.insert(0, str(Path(__file__).parent.parent.parent))  # Add project root to path
from ml.data.demo_data import load_products, populate_products, synthesize_users, synthesize_interactions

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def main():
    """Set up the demo database."""
    logger.info("Setting up demo PostgreSQL database...")
    
    # Create all database tables
    logger.info("Creating database tables...")
    Base.metadata.create_all(bind=engine)
    
    # Get a database session
    db: Session = SessionLocal()
    
    try:
        # Load products from the backend/data/products.json file
        products_path = Path(__file__).parent.parent / "data" / "products.json"
        if not products_path.exists():
            logger.error(f"Products file not found at {products_path}")
            return
            
        logger.info(f"Loading products from {products_path}")
        products = load_products(products_path)
        
        # Populate products in the database
        populate_products(db, products, engine)
        
        # Create synthetic users
        logger.info("Creating synthetic users...")
        user_ids = synthesize_users(db, count=20)  # Create 20 demo users
        
        # Get all product IDs from the database
        product_ids = [p.id for p in db.query(Product.id).all()]
        logger.info(f"Found {len(product_ids)} products in database")
        
        if len(product_ids) == 0:
            logger.error("No products found in database after loading")
            return
            
        # Generate synthetic interaction events
        logger.info("Generating synthetic interaction events...")
        synthesize_interactions(db, product_ids, user_ids, events_per_user=50)
        
        logger.info("Demo database setup completed successfully!")
        logger.info(f"Created {len(user_ids)} users with synthetic interactions")
        logger.info("You can now run: python -m scripts.train_all_models")
        
    except Exception as e:
        db.rollback()
        logger.exception(f"Failed to set up demo database: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    main()