"""Train all ML models in order.

Usage:
    python -m scripts.train_all_models
"""

import sys
import logging
from pathlib import Path
import subprocess

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent))

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def run_script(script_name: str) -> bool:
    """Run a training script.

    Args:
        script_name: Name of the script to run

    Returns:
        True if successful
    """
    logger.info(f"Running {script_name}...")
    try:
        result = subprocess.run(
            [sys.executable, "-m", script_name],
            cwd=str(Path(__file__).parent.parent),
            check=True,
            capture_output=True,
            text=True,
        )
        logger.info(f"{script_name} completed successfully")
        logger.info(result.stdout)
        return True
    except subprocess.CalledProcessError as e:
        logger.error(f"{script_name} failed: {e}")
        logger.error(e.stderr)
        return False


def main():
    """Train all models in order."""
    logger.info("Starting ML model training pipeline...")

    # Step 1: Generate product embeddings (prerequisite)
    logger.info("Step 1: Generating product embeddings...")
    if not run_script("scripts.generate_product_embeddings"):
        logger.error("Failed to generate embeddings, aborting")
        return

    # Step 2: Train recommendation model
    logger.info("Step 2: Training recommendation model...")
    if not run_script("scripts.train_recommendation_model"):
        logger.error("Failed to train recommendation model")
        # Continue with other models

    # Step 3: Train Style DNA model
    logger.info("Step 3: Training Style DNA model...")
    if not run_script("scripts.train_style_dna_model"):
        logger.error("Failed to train Style DNA model")
        # Continue with other models

    # Step 4: Train outfit compatibility model
    logger.info("Step 4: Training outfit compatibility model...")
    if not run_script("scripts.train_outfit_compatibility_model"):
        logger.error("Failed to train outfit compatibility model")
        # Continue with other models

    # Step 5: Train blend model
    logger.info("Step 5: Training blend model...")
    if not run_script("scripts.train_blend_model"):
        logger.error("Failed to train blend model")
        # Continue with other models

    # Step 6: Train trend prediction model
    logger.info("Step 6: Training trend prediction model...")
    if not run_script("scripts.train_trend_model"):
        logger.error("Failed to train trend prediction model")

    logger.info("ML model training pipeline completed")


if __name__ == "__main__":
    main()
