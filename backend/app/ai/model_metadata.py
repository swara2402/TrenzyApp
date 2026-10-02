"""Standardized model metadata schema and utilities.

This module defines the canonical metadata schema for all Trenzy ML models
and provides utilities for generating consistent metadata across training pipelines.

Standard metadata fields:
- model_name: Name of the model
- version: Semantic version (e.g., v2.0)
- model_type: Implementation type (lightgbm, xgboost, etc.)
- training_date: ISO format timestamp
- dataset_version: Dataset version used for training
- feature_version: Feature engineering version
- metrics: Evaluation metrics (dict)
- git_commit: Git commit hash (if available)
- artifact_hash: Hash of the model artifact
- data_source: Source of training data (production_postgresql, demo_sqlite)
- status: Deployment status (development, staging, production)
- embedding_dim: Dimension of embeddings used (if applicable)
- feature_dim: Total feature dimension
- training_samples: Number of training samples
- validation_samples: Number of validation samples
- test_samples: Number of test samples
- training_time_seconds: Time taken to train
"""

from __future__ import annotations

import logging
import json
import hashlib
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional, Any
import subprocess

logger = logging.getLogger(__name__)


class ModelMetadataSchema:
    """Canonical schema for model metadata."""

    REQUIRED_FIELDS = [
        "model_name",
        "version",
        "model_type",
        "training_date",
        "dataset_version",
        "feature_version",
        "data_source",
        "status",
    ]

    RECOMMENDED_FIELDS = [
        "metrics",
        "git_commit",
        "artifact_hash",
        "embedding_dim",
        "feature_dim",
        "training_samples",
        "validation_samples",
        "test_samples",
        "training_time_seconds",
    ]

    OPTIONAL_FIELDS = [
        "author",
        "description",
        "hyperparameters",
        "environment",
        "dependencies",
    ]


def get_git_commit() -> Optional[str]:
    """Get current git commit hash."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except Exception as e:
        logger.warning(f"Failed to get git commit: {e}")
    return None


def compute_artifact_hash(artifact_path: Path) -> str:
    """Compute SHA256 hash of model artifact."""
    hash_sha256 = hashlib.sha256()
    with open(artifact_path, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_sha256.update(chunk)
    return hash_sha256.hexdigest()


def validate_metadata(metadata: Dict[str, Any]) -> tuple[bool, list[str]]:
    """Validate metadata against schema.

    Args:
        metadata: Metadata dict to validate

    Returns:
        Tuple of (is_valid, list_of_errors)
    """
    errors = []

    # Check required fields
    for field in ModelMetadataSchema.REQUIRED_FIELDS:
        if field not in metadata:
            errors.append(f"Missing required field: {field}")

    # Validate data source
    if "data_source" in metadata:
        valid_sources = ["production_postgresql", "demo_sqlite", "synthetic"]
        if metadata["data_source"] not in valid_sources:
            errors.append(f"Invalid data_source: {metadata['data_source']}")

    # Validate status
    if "status" in metadata:
        valid_statuses = ["development", "staging", "production", "deprecated"]
        if metadata["status"] not in valid_statuses:
            errors.append(f"Invalid status: {metadata['status']}")

    # Validate version format
    if "version" in metadata:
        version = metadata["version"]
        if not (version.startswith("v") and len(version.split(".")) >= 2):
            errors.append(f"Invalid version format: {version}")

    # Validate metrics are numeric
    if "metrics" in metadata and isinstance(metadata["metrics"], dict):
        for key, value in metadata["metrics"].items():
            if not isinstance(value, (int, float)):
                errors.append(f"Metric {key} should be numeric, got {type(value)}")

    return len(errors) == 0, errors


def generate_standard_metadata(
    model_name: str,
    version: str,
    model_type: str,
    artifact_path: Path,
    dataset_version: str = "v1",
    feature_version: str = "v1",
    data_source: str = "production_postgresql",
    status: str = "development",
    metrics: Optional[Dict[str, float]] = None,
    embedding_dim: Optional[int] = None,
    feature_dim: Optional[int] = None,
    training_samples: Optional[int] = None,
    validation_samples: Optional[int] = None,
    test_samples: Optional[int] = None,
    training_time_seconds: Optional[float] = None,
    hyperparameters: Optional[Dict[str, Any]] = None,
    description: Optional[str] = None,
) -> Dict[str, Any]:
    """Generate standardized metadata for a trained model.

    Args:
        model_name: Name of the model
        version: Model version (e.g., v2.0)
        model_type: Implementation type
        artifact_path: Path to model artifact
        dataset_version: Dataset version used
        feature_version: Feature engineering version
        data_source: Source of training data
        status: Deployment status
        metrics: Evaluation metrics
        embedding_dim: Embedding dimension
        feature_dim: Total feature dimension
        training_samples: Number of training samples
        validation_samples: Number of validation samples
        test_samples: Number of test samples
        training_time_seconds: Training time
        hyperparameters: Model hyperparameters
        description: Model description

    Returns:
        Standardized metadata dict
    """
    metadata = {
        "model_name": model_name,
        "version": version,
        "model_type": model_type,
        "training_date": datetime.utcnow().isoformat(),
        "dataset_version": dataset_version,
        "feature_version": feature_version,
        "data_source": data_source,
        "status": status,
        "git_commit": get_git_commit(),
        "artifact_path": str(artifact_path),
    }

    # Add artifact hash if file exists
    if artifact_path.exists():
        metadata["artifact_hash"] = compute_artifact_hash(artifact_path)

    # Add optional fields if provided
    if metrics:
        metadata["metrics"] = metrics
    if embedding_dim:
        metadata["embedding_dim"] = embedding_dim
    if feature_dim:
        metadata["feature_dim"] = feature_dim
    if training_samples:
        metadata["training_samples"] = training_samples
    if validation_samples:
        metadata["validation_samples"] = validation_samples
    if test_samples:
        metadata["test_samples"] = test_samples
    if training_time_seconds:
        metadata["training_time_seconds"] = training_time_seconds
    if hyperparameters:
        metadata["hyperparameters"] = hyperparameters
    if description:
        metadata["description"] = description

    # Validate metadata
    is_valid, errors = validate_metadata(metadata)
    if not is_valid:
        logger.warning(f"Generated metadata has validation errors: {errors}")

    return metadata


def save_metadata(metadata: Dict[str, Any], output_path: Path) -> None:
    """Save metadata to JSON file.

    Args:
        metadata: Metadata dict
        output_path: Path to save metadata.json
    """
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, 'w') as f:
        json.dump(metadata, f, indent=2, default=str)
    logger.info(f"Metadata saved to {output_path}")


def load_metadata(metadata_path: Path) -> Optional[Dict[str, Any]]:
    """Load metadata from JSON file.

    Args:
        metadata_path: Path to metadata.json

    Returns:
        Metadata dict or None if file doesn't exist
    """
    if not metadata_path.exists():
        logger.warning(f"Metadata file not found: {metadata_path}")
        return None

    try:
        with open(metadata_path, 'r') as f:
            metadata = json.load(f)
        
        # Validate loaded metadata
        is_valid, errors = validate_metadata(metadata)
        if not is_valid:
            logger.warning(f"Loaded metadata has validation errors: {errors}")
        
        return metadata
    except Exception as e:
        logger.error(f"Failed to load metadata from {metadata_path}: {e}")
        return None


def create_model_card(metadata: Dict[str, Any], output_path: Path) -> None:
    """Create a human-readable model card from metadata.

    Args:
        metadata: Model metadata
        output_path: Path to save model card
    """
    card_content = f"""# Model Card: {metadata['model_name']} {metadata['version']}

## Overview
- **Model Name**: {metadata['model_name']}
- **Version**: {metadata['version']}
- **Type**: {metadata['model_type']}
- **Status**: {metadata['status']}

## Training Information
- **Training Date**: {metadata['training_date']}
- **Data Source**: {metadata['data_source']}
- **Dataset Version**: {metadata['dataset_version']}
- **Feature Version**: {metadata['feature_version']}

## Performance Metrics
"""

    if "metrics" in metadata:
        for metric, value in metadata['metrics'].items():
            card_content += f"- **{metric}**: {value}\n"

    card_content += f"""
## Training Details
- **Training Samples**: {metadata.get('training_samples', 'N/A')}
- **Validation Samples**: {metadata.get('validation_samples', 'N/A')}
- **Test Samples**: {metadata.get('test_samples', 'N/A')}
- **Training Time**: {metadata.get('training_time_seconds', 'N/A')} seconds

## Model Architecture
- **Feature Dimension**: {metadata.get('feature_dim', 'N/A')}
- **Embedding Dimension**: {metadata.get('embedding_dim', 'N/A')}

## Reproducibility
- **Git Commit**: {metadata.get('git_commit', 'N/A')}
- **Artifact Hash**: {metadata.get('artifact_hash', 'N/A')}
- **Artifact Path**: {metadata.get('artifact_path', 'N/A')}

## Usage
```python
from app.ai.model_manager import ModelManager

manager = ModelManager.instance()
model = manager.get_model('{metadata['model_name']}')
```

## Notes
{metadata.get('description', 'No description provided.')}
"""

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, 'w') as f:
        f.write(card_content)
    
    logger.info(f"Model card saved to {output_path}")