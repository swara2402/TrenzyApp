"""Unit and integration tests for Trenzy AI/ML foundation."""

import pytest
import numpy as np
from datetime import datetime, timezone

from ml.contracts.data_contracts import (
    CatalogItemContract,
    EmbeddingContract,
    InteractionEventContract,
    StyleDNAContract,
    FeatureRowContract,
    validate_catalog_item,
    validate_embedding,
    validate_interaction,
)
from ml.evaluation.gates import ModelQualityGates
from ml.features.feature_engineering import FeatureExtractor
from ml.config.settings import EMBEDDING_DIM, FEATURE_NAMES
from app.models import Product
from app.ai.models_ai import UserStyleProfile


def test_catalog_contract_valid():
    item = {
        "id": "prod_test_001",
        "name": "Classic Linen Shirt",
        "category": "tops",
        "price": 1499.0,
        "image_url": "https://upload.wikimedia.org/wikipedia/commons/test.jpg",
        "image_sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        "image_phash": "c4b4e3ebb85f3003",
        "source": "Wikimedia Commons",
        "license_attribution": "CC BY-SA 4.0",
        "author": "Fashion Contributor",
        "currency": "INR",
    }
    res = validate_catalog_item(item)
    assert res.is_valid is True
    assert len(res.errors) == 0


def test_catalog_contract_rejects_missing_image():
    item = {
        "id": "prod_test_002",
        "name": "No Image Dress",
        "category": "dresses",
        "price": 2499.0,
        "image_url": "",
    }
    res = validate_catalog_item(item)
    assert res.is_valid is False
    assert any("image_url" in err for err in res.errors)


def test_catalog_contract_rejects_invalid_sha256():
    item = {
        "id": "prod_test_003",
        "name": "Bad Hash Jacket",
        "category": "outerwear",
        "price": 4999.0,
        "image_url": "https://example.com/jacket.jpg",
        "image_sha256": "not-a-valid-sha256",
    }
    res = validate_catalog_item(item)
    assert res.is_valid is False
    assert any("image_sha256" in err for err in res.errors)


def test_embedding_contract_valid():
    # Construct an L2 normalized 512-dim vector
    raw = [0.1] * EMBEDDING_DIM
    norm = np.linalg.norm(raw)
    normalized = (np.array(raw) / norm).tolist()

    res = validate_embedding(normalized)
    assert res.is_valid is True
    assert len(res.errors) == 0


def test_embedding_contract_rejects_nan():
    vec = [0.0] * EMBEDDING_DIM
    vec[min(10, EMBEDDING_DIM - 1)] = float("nan")
    res = validate_embedding(vec)
    assert res.is_valid is False
    assert any("NaN" in err for err in res.errors)


def test_embedding_contract_rejects_wrong_dimension():
    vec = [0.1] * 256  # Expected EMBEDDING_DIM (512)
    res = validate_embedding(vec)
    assert res.is_valid is False
    assert any("dimension mismatch" in err for err in res.errors)


def test_interaction_contract_rejects_synthetic_in_production():
    evt = {
        "id": 1,
        "user_id": 42,
        "product_id": "prod_001",
        "event_type": "like_product",
        "is_synthetic": True,
    }
    res = validate_interaction(evt, allow_synthetic=False)
    assert res.is_valid is False
    assert any("Synthetic interaction" in err for err in res.errors)


def test_model_quality_gates_blocks_insufficient_data():
    gates = ModelQualityGates()
    metrics = {
        "precision_at_10": 0.20,
        "recall_at_10": 0.30,
        "ndcg_at_10": 0.35,
        "hit_rate_at_10": 0.40,
        "catalog_coverage": 0.15,
    }
    # Evaluated on only 50 real interactions (threshold is 1,000)
    res = gates.evaluate(metrics, model_version="candidate_v1", total_interactions=50)
    assert res.passed is False
    assert any("INSUFFICIENT REAL DATA" in f for f in res.failures)


def test_feature_extractor_shape():
    extractor = FeatureExtractor()
    product = Product(
        id="prod_feat_01",
        name="Urban Bomber Jacket",
        category="outerwear",
        price=3499.0,
        style="streetwear",
        color="black",
        currency="INR",
    )
    user_profile = UserStyleProfile(
        user_id=1,
        style_scores={"streetwear": 0.8, "minimal": 0.2},
        color_scores={"black": 0.9, "gray": 0.5},
        fit_scores={"oversized": 0.7},
        price_sensitivity=0.4,
    )
    features = extractor.extract(user_profile, product)
    assert isinstance(features, np.ndarray)
    assert len(features) == len(FEATURE_NAMES)
    assert not np.isnan(features).any()
    assert not np.isinf(features).any()
