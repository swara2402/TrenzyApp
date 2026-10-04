"""Train the Style DNA model.

Usage:
    python -m scripts.train_style_dna_model
"""

import sys
import logging
from pathlib import Path

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.db import get_session
from app.ai.personalization.style_dna_trainer import StyleDNATrainer
from app.ai.registry import ModelRegistry

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def main():
    """Train Style DNA model."""
    logger.info("Starting Style DNA model training...")

    # Get database session
    db = next(get_session())

    try:
        # Initialize trainer
        trainer = StyleDNATrainer(
            model_dir="models/style_dna",
        )

        # Train model
        logger.info("Training style classifiers...")
        classifiers = trainer.train_and_save(db)

        if not classifiers:
            logger.error("Training failed")
            return

        logger.info("Training completed successfully")

        # Register model in registry
        registry = ModelRegistry()

        version = "v1.0"
        artifact_path = "models/style_dna/v1.0/style_classifiers.pkl"

        registry.register_model(
            model_name="style_dna",
            version=version,
            artifact_path=artifact_path,
            metrics={"num_classifiers": len(classifiers)},
            dataset_version="v1.0",
            feature_version="v1.0",
        )

        logger.info(f"Model registered as style_dna/{version}")

    finally:
        db.close()


if __name__ == "__main__":
    main()
