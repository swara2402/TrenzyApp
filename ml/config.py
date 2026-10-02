"""Central ML pipeline configuration.

Environment variables:
- ``TRENZY_TEST_DB=1``  → run against in-memory SQLite (local/demo/tests).
- ``ML_PRODUCTS_CSV``   → path to the products CSV/JSON used for the demo path.
- ``ML_CONTEXT``        → "demo" (synthetic interactions, no real users) or
                          "production" (real user interaction events).
"""

from __future__ import annotations

import os
from pathlib import Path

# Repo root (parent of ml/)
REPO_ROOT = Path(__file__).resolve().parent.parent

BACKEND_DIR = REPO_ROOT / "backend"
DEFAULT_PRODUCTS_CSV = Path(
    os.getenv("ML_PRODUCTS_CSV", "/Users/sam/Downloads/data/output/trenzy_products.csv")
)

# Where trained artifacts live
MODELS_DIR = REPO_ROOT / "models"

# Evaluation reports
REPORTS_DIR = REPO_ROOT / "reports"
LATEST_REPORTS_DIR = REPO_ROOT / "reports" / "latest"

# Demo mode uses synthetic interaction events when there is no real data yet.
ML_CONTEXT = os.getenv("ML_CONTEXT", "demo").strip().lower()

# SQLite (test/demo) or Postgres (production)
# Priority: ML_USE_POSTGRES=1 → PostgreSQL, TRENZY_TEST_DB=1 → SQLite, default → PostgreSQL
ML_USE_POSTGRES = os.getenv("ML_USE_POSTGRES", "0") == "1"
TEST_DB_MODE = os.getenv("TRENZY_TEST_DB", "0") == "1"
USE_SQLITE = not ML_USE_POSTGRES and TEST_DB_MODE

# Model metadata used in registry registration
DEFAULT_FEATURE_VERSION = "v1"
DEFAULT_DATASET_VERSION = "v1"

EMBEDDING_MODEL = os.getenv("ML_EMBEDDING_MODEL", "all-MiniLM-L6-v2")
EMBEDDING_VERSION = os.getenv("ML_EMBEDDING_VERSION", "miniLM-L6-v1")


def ensure_dirs() -> None:
    """Create directories used by the pipeline."""
    for d in (MODELS_DIR, REPORTS_DIR, LATEST_REPORTS_DIR):
        d.mkdir(parents=True, exist_ok=True)


def models_dir_for(model_name: str) -> Path:
    """Directory for a model's versioned artifacts."""
    ensure_dirs()
    return MODELS_DIR / model_name


def get_data_source_info() -> dict:
    """Get information about the current data source configuration."""
    return {
        "ml_context": ML_CONTEXT,
        "use_sqlite": USE_SQLITE,
        "ml_use_postgres": ML_USE_POSTGRES,
        "test_db_mode": TEST_DB_MODE,
        "data_source": "SQLite (demo/test)" if USE_SQLITE else "PostgreSQL (production)",
    }


def validate_data_source_for_training() -> list[str]:
    """Validate data source configuration for production training.
    
    Returns warnings if configuration suggests we're not using real production data.
    """
    warnings = []
    
    if ML_CONTEXT == "demo":
        warnings.append("ML_CONTEXT=demo: Using synthetic interaction data, not real user behavior")
    
    if USE_SQLITE:
        warnings.append("Using SQLite database: Training on demo/test data, not production PostgreSQL")
    
    if not ML_USE_POSTGRES and not TEST_DB_MODE:
        warnings.append("Defaulting to PostgreSQL but ML_USE_POSTGRES not explicitly set")
    
    return warnings