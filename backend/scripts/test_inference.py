"""Test inference pipelines with fallback chain.

Usage:
    python -m scripts.test_inference
"""

import sys
import logging
from pathlib import Path

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.db import get_session
from app.ai.recommendation.inference import RecommendationInference
from app.ai.personalization.style_dna_inference import StyleDNAInference
from app.ai.outfits.compatibility_inference import OutfitCompatibilityInference
from app.ai.blends.blend_inference import BlendInference
from app.ai.trends.trend_inference import TrendInference

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def test_recommendation_inference(db):
    """Test recommendation inference."""
    logger.info("Testing recommendation inference...")

    inference = RecommendationInference(fallback_to_rules=True)

    # Test with a sample user (user_id=1)
    products, explanations, model_version, source = inference.get_recommendations(
        db=db,
        user_id=1,
        limit=5,
    )

    logger.info(f"Recommendation source: {source}")
    logger.info(f"Model version: {model_version}")
    logger.info(f"Products returned: {len(products)}")

    return source != "none"


def test_style_dna_inference(db):
    """Test Style DNA inference."""
    logger.info("Testing Style DNA inference...")

    inference = StyleDNAInference(fallback_to_aggregation=True)

    # Test with a sample user (user_id=1)
    style_scores, model_version, source = inference.compute_style_dna(
        db=db,
        user_id=1,
    )

    logger.info(f"Style DNA source: {source}")
    logger.info(f"Model version: {model_version}")
    logger.info(f"Style scores: {style_scores}")

    return source != "none"


def test_outfit_compatibility_inference(db):
    """Test outfit compatibility inference."""
    logger.info("Testing outfit compatibility inference...")

    inference = OutfitCompatibilityInference(fallback_to_rules=True)

    # Get sample products
    from app.models import Product
    products = db.query(Product).filter(Product.is_active == True).limit(3).all()

    if len(products) < 3:
        logger.warning("Not enough products to test outfit compatibility")
        return False

    score, model_version, source = inference.compute_compatibility(db, products)

    logger.info(f"Compatibility source: {source}")
    logger.info(f"Model version: {model_version}")
    logger.info(f"Compatibility score: {score}")

    return source != "none"


def test_blend_inference(db):
    """Test blend inference."""
    logger.info("Testing blend inference...")

    inference = BlendInference(fallback_to_aggregation=True)

    # Get sample users and product
    from app.models import Product
    users = [1, 2]  # Sample user IDs
    product = db.query(Product).filter(Product.is_active == True).first()

    if not product:
        logger.warning("No products found to test blend inference")
        return False

    score, model_version, source = inference.compute_group_preference(
        db=db,
        user_ids=users,
        product_id=product.id,
    )

    logger.info(f"Blend source: {source}")
    logger.info(f"Model version: {model_version}")
    logger.info(f"Preference score: {score}")

    return source != "none"


def test_trend_inference(db):
    """Test trend inference."""
    logger.info("Testing trend inference...")

    inference = TrendInference(fallback_to_popularity=True)

    # Get sample product
    from app.models import Product
    product = db.query(Product).filter(Product.is_active == True).first()

    if not product:
        logger.warning("No products found to test trend inference")
        return False

    score, model_version, source = inference.compute_trend_score(
        db=db,
        product_id=product.id,
    )

    logger.info(f"Trend source: {source}")
    logger.info(f"Model version: {model_version}")
    logger.info(f"Trend score: {score}")

    return source != "none"


def main():
    """Test all inference pipelines."""
    logger.info("Starting inference pipeline tests...")

    db = next(get_session())

    try:
        results = {}

        # Test each inference pipeline
        results["recommendation"] = test_recommendation_inference(db)
        results["style_dna"] = test_style_dna_inference(db)
        results["outfit_compatibility"] = test_outfit_compatibility_inference(db)
        results["blend"] = test_blend_inference(db)
        results["trend"] = test_trend_inference(db)

        # Summary
        logger.info("\n=== Test Summary ===")
        for model, passed in results.items():
            status = "✓ PASSED" if passed else "✗ FAILED"
            logger.info(f"{model}: {status}")

        all_passed = all(results.values())
        if all_passed:
            logger.info("\nAll inference pipelines working correctly!")
        else:
            logger.warning("\nSome inference pipelines failed or returned no results")

    finally:
        db.close()


if __name__ == "__main__":
    main()
