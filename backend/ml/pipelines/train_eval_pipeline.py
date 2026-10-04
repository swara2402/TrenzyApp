"""End-to-end training and evaluation pipeline."""

import logging
from typing import Dict, Any
from sqlalchemy.orm import Session

from ..training.lightgbm_ranker import LightGBMRankerTrainer
from ..datasets.interaction_dataset import InteractionDatasetLoader
from ..config.settings import MIN_TRAINING_INTERACTIONS

logger = logging.getLogger(__name__)


class EndToEndMLPipeline:
    """Orchestrates end-to-end data validation, training, and gate checking."""

    def __init__(self, db: Session):
        self.db = db
        self.trainer = LightGBMRankerTrainer(db)
        self.dataset_loader = InteractionDatasetLoader(db)

    def run(self, candidate_version: str = "v1.0-candidate") -> Dict[str, Any]:
        """Execute pipeline."""
        logger.info("Starting End-to-End ML Pipeline (candidate: %s)...", candidate_version)

        # 1. Check data sufficiency
        real_count = self.dataset_loader.count_real_interactions()
        logger.info("Real user positive interactions in DB: %d / %d", real_count, MIN_TRAINING_INTERACTIONS)

        # 2. Run trainer
        result = self.trainer.run_training_pipeline(
            candidate_version=candidate_version,
            allow_demo_mode=False,
        )

        logger.info("Pipeline complete. Result status: %s", result["status"])
        return result
