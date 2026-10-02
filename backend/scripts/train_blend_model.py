"""Train the blend model.

Usage:
    python -m scripts.train_blend_model
"""

import sys
import logging
from pathlib import Path

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.db import get_session
from app.ai.blends.blend_trainer import BlendModelTrainer
from app.ai.registry import ModelRegistry

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def main():
    """Train blend model."""
    logger.info("Starting blend model training...")

    # Get database session
    db = next(get_session())

    try:
        # Initialize trainer
        trainer = BlendModelTrainer(
            model_type="lightgbm",
            model_dir="models/blend",
        )

        # Train model
        logger.info("Training model...")
        model, metadata = trainer.train(db)

        if model is None:
            logger.error("Training failed")
            return

        logger.info("Training completed successfully")
        logger.info(f"Model metadata: {metadata}")

        # Register model in registry
        registry = ModelRegistry()

        version = metadata.get("version", "v1.0")
        artifact_path = metadata.get("artifact_path")

        registry.register_model(
            model_name="blend",
            version=version,
            artifact_path=artifact_path,
            metrics=metadata.get("metrics", {}),
            dataset_version=metadata.get("dataset_version"),
            feature_version=metadata.get("feature_version"),
        )

        logger.info(f"Model registered as blend/{version}")

    finally:
        db.close()


if __name__ == "__main__":
    main()
