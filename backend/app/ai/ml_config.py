"""ML configuration constants — single source of truth.

This module is the canonical source for all ML hyperparameters and constants.
Import from here instead of hardcoding values anywhere else.

Critical invariant
------------------
Every component that deals with embedding vectors (DB columns, training,
inference, pgvector search) **must** obtain the dimension from
``EMBEDDING_DIM`` in this module. Hardcoding ``512`` (or any other number)
elsewhere will cause silent dimension mismatches that are extremely hard to
debug.

Usage::

    from .ml_config import EMBEDDING_DIM, FASHIONCLIP_MODEL_NAME

    # In SQLAlchemy model:
    embedding_vector = mapped_column(Vector(EMBEDDING_DIM), nullable=True)

    # In training feature builder:
    fallback = [0.0] * EMBEDDING_DIM
"""

from __future__ import annotations

import logging
import os
from typing import Optional

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# FashionCLIP model identifier
# ---------------------------------------------------------------------------

FASHIONCLIP_MODEL_NAME: str = "Marqo/marqo-fashionCLIP"

# ---------------------------------------------------------------------------
# Embedding dimension
#
# Strategy (in order of priority):
#   1. Read ML_EMBEDDING_DIM environment variable (allows CI/test override).
#   2. Default to 512, which is the documented projection_dim for
#      Marqo/marqo-fashionCLIP (https://huggingface.co/Marqo/marqo-fashionCLIP).
#
# At model-load time (fashionclip.py) the actual dimension is re-read from
# model.config.projection_dim and compared against this constant.  A loud
# RuntimeError is raised if they differ, so mismatches are caught immediately
# rather than silently producing wrong-shaped vectors.
# ---------------------------------------------------------------------------

def _resolve_embedding_dim() -> int:
    """Determine embedding dimension.

    Reads ML_EMBEDDING_DIM from environment (useful for tests/CI that don't
    want to download the full model).  Falls back to 512 — the published
    projection_dim for Marqo/marqo-fashionCLIP.
    """
    env_val = os.environ.get("ML_EMBEDDING_DIM")
    if env_val:
        try:
            dim = int(env_val)
            if dim <= 0:
                raise ValueError("ML_EMBEDDING_DIM must be a positive integer")
            logger.info("ML_EMBEDDING_DIM from environment: %d", dim)
            return dim
        except ValueError as exc:
            logger.error("Invalid ML_EMBEDDING_DIM env var '%s': %s", env_val, exc)

    # Documented default for Marqo/marqo-fashionCLIP
    return 512


EMBEDDING_DIM: int = _resolve_embedding_dim()

# Image download retry configuration
IMAGE_DOWNLOAD_MAX_RETRIES: int = 10  # further increased retries for persistent failures
IMAGE_DOWNLOAD_BACKOFF_BASE: int = 5  # larger backoff base seconds for exponential backoff

# ---------------------------------------------------------------------------
# Normalization
# ---------------------------------------------------------------------------

#: Whether embeddings are L2-normalised before storage and search.
#: Must be True for cosine similarity via pgvector <=> operator.
NORMALIZE_EMBEDDINGS: bool = True

# ---------------------------------------------------------------------------
# Training hyperparameters (LightGBM baseline)
# ---------------------------------------------------------------------------

LIGHTGBM_DEFAULTS: dict = {
    "n_estimators": 100,
    "learning_rate": 0.1,
    "max_depth": 8,
    "num_leaves": 31,
    "random_state": 42,
    "verbose": -1,
}

NEGATIVE_SAMPLE_RATIO: int = 3          # negative samples per positive
VALIDATION_SPLIT: float = 0.2           # fraction of data held out for val
MIN_INTERACTIONS_TO_TRAIN: int = 1_000  # minimum real interactions before training

# ---------------------------------------------------------------------------
# Catalog quality gates
# ---------------------------------------------------------------------------

MIN_IMAGE_WIDTH: int = 400
MIN_IMAGE_HEIGHT: int = 400
ALLOWED_MIME_TYPES: frozenset = frozenset({"image/jpeg", "image/png", "image/webp"})
PHASH_DUPLICATE_THRESHOLD: int = 10     # hamming distance ≤ this = near-duplicate

# ---------------------------------------------------------------------------
# Validation helper (called from fashionclip.py after model load)
# ---------------------------------------------------------------------------

def validate_model_embedding_dim(actual_dim: int) -> None:
    """Assert that the loaded model's projection dim matches ``EMBEDDING_DIM``.

    Args:
        actual_dim: The ``projection_dim`` read from the loaded model's config.

    Raises:
        RuntimeError: if ``actual_dim`` != ``EMBEDDING_DIM``.  This is an
            intentional hard failure — a silent mismatch would cause DB inserts
            to fail or silently truncate vectors.
    """
    if actual_dim != EMBEDDING_DIM:
        raise RuntimeError(
            f"Embedding dimension mismatch: model produces {actual_dim}-dimensional "
            f"vectors but EMBEDDING_DIM={EMBEDDING_DIM}. "
            f"Set ML_EMBEDDING_DIM={actual_dim} in your environment and re-run "
            f"Alembic migrations to resize the pgvector columns."
        )
    logger.info("Embedding dimension validated: %d", actual_dim)
