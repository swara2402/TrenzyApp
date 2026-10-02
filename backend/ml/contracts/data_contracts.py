"""Strict data contracts and runtime validators for Trenzy ML pipelines."""

import re
import math
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any
from datetime import datetime

from ..config.settings import EMBEDDING_DIM


@dataclass
class ValidationResult:
    """Result of data contract validation."""
    is_valid: bool
    errors: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)

    def raise_if_invalid(self, context: str = "") -> None:
        if not self.is_valid:
            err_msg = f"Data contract violation [{context}]: " + "; ".join(self.errors)
            raise ValueError(err_msg)


@dataclass
class CatalogItemContract:
    """Contract for a product catalog record entering the ML pipeline."""
    id: str
    name: str
    category: str
    price: float
    image_url: str
    image_sha256: Optional[str] = None
    image_phash: Optional[str] = None
    source_page: Optional[str] = None
    license_attribution: Optional[str] = None
    author: Optional[str] = None
    currency: str = "INR"
    is_archived: bool = False

    def validate(self) -> ValidationResult:
        errors = []
        warnings = []

        if not self.id or not str(self.id).strip():
            errors.append("Product id cannot be empty")

        if not self.name or not str(self.name).strip():
            errors.append("Product name cannot be empty")

        if not self.category or not str(self.category).strip():
            errors.append("Product category cannot be empty")

        if self.price is None or self.price < 0:
            errors.append(f"Price must be non-negative, got {self.price}")

        if not self.image_url or not self.image_url.startswith(("http://", "https://", "file://", "/")):
            errors.append(f"Invalid image_url: {self.image_url}")

        if self.image_sha256:
            if not re.match(r"^[0-9a-fA-F]{64}$", self.image_sha256):
                errors.append(f"image_sha256 must be 64-char hex, got '{self.image_sha256}'")
        else:
            warnings.append("image_sha256 is missing")

        if not self.license_attribution and not self.source_page:
            warnings.append("No license attribution or source page documented")

        if self.currency not in ("INR", "USD", "EUR", "GBP"):
            warnings.append(f"Unusual currency code: '{self.currency}'")

        return ValidationResult(is_valid=len(errors) == 0, errors=errors, warnings=warnings)


@dataclass
class InteractionEventContract:
    """Contract for an interaction event used in training or evaluation."""
    id: Optional[int]
    user_id: int
    product_id: str
    event_type: str
    created_at: datetime
    is_synthetic: bool = False

    VALID_EVENT_TYPES = {
        "view",
        "like_product",
        "unlike_product",
        "save_outfit",
        "add_to_cart",
        "purchase",
        "share",
        "click",
    }

    def validate(self, allow_synthetic: bool = False) -> ValidationResult:
        errors = []
        warnings = []

        if not self.user_id:
            errors.append("user_id must be provided")

        if not self.product_id:
            errors.append("product_id must be provided")

        if self.event_type not in self.VALID_EVENT_TYPES:
            errors.append(f"Invalid event_type: '{self.event_type}'")

        if self.is_synthetic and not allow_synthetic:
            errors.append("Synthetic interaction event rejected: production requires real user events")

        return ValidationResult(is_valid=len(errors) == 0, errors=errors, warnings=warnings)


@dataclass
class EmbeddingContract:
    """Contract for an embedding vector."""
    entity_id: str
    vector: List[float]
    model_version: str = "1.0"
    expected_dim: int = EMBEDDING_DIM

    def validate(self) -> ValidationResult:
        errors = []
        warnings = []

        if not self.vector:
            errors.append("Embedding vector cannot be empty")
            return ValidationResult(is_valid=False, errors=errors)

        if len(self.vector) != self.expected_dim:
            errors.append(
                f"Embedding dimension mismatch: expected {self.expected_dim}, got {len(self.vector)}"
            )

        has_nan = any(math.isnan(x) for x in self.vector)
        if has_nan:
            errors.append("Embedding contains NaN values")

        has_inf = any(math.isinf(x) for x in self.vector)
        if has_inf:
            errors.append("Embedding contains Infinite values")

        # Norm check
        norm_sq = sum(x * x for x in self.vector)
        norm = math.sqrt(norm_sq)
        if norm == 0:
            errors.append("Embedding norm is 0 (all zeros)")
        elif abs(norm - 1.0) > 0.05:
            warnings.append(f"Embedding is not L2 normalized: norm = {norm:.4f}")

        return ValidationResult(is_valid=len(errors) == 0, errors=errors, warnings=warnings)


@dataclass
class StyleDNAContract:
    """Contract for user style DNA profile."""
    user_id: int
    style_scores: Dict[str, float]
    color_scores: Dict[str, float]
    fit_scores: Dict[str, float]
    price_sensitivity: float = 0.5

    def validate(self) -> ValidationResult:
        errors = []
        warnings = []

        if not self.user_id:
            errors.append("user_id must be set")

        for key, val in self.style_scores.items():
            if val < 0.0 or val > 1.0:
                warnings.append(f"Style score for '{key}' out of expected [0, 1] range: {val}")

        if self.price_sensitivity < 0.0 or self.price_sensitivity > 1.0:
            warnings.append(f"price_sensitivity out of [0, 1] range: {self.price_sensitivity}")

        return ValidationResult(is_valid=len(errors) == 0, errors=errors, warnings=warnings)


@dataclass
class FeatureRowContract:
    """Contract for a single feature row fed into the recommendation model."""
    feature_values: List[float]
    label: Optional[int] = None
    expected_dim: Optional[int] = None

    def validate(self) -> ValidationResult:
        errors = []
        warnings = []

        if not self.feature_values:
            errors.append("Feature values list is empty")
            return ValidationResult(is_valid=False, errors=errors)

        if self.expected_dim is not None and len(self.feature_values) != self.expected_dim:
            errors.append(
                f"Feature vector dimension mismatch: expected {self.expected_dim}, got {len(self.feature_values)}"
            )

        if any(math.isnan(x) for x in self.feature_values):
            errors.append("Feature row contains NaN values")

        if any(math.isinf(x) for x in self.feature_values):
            errors.append("Feature row contains Infinite values")

        if self.label is not None and self.label not in (0, 1):
            errors.append(f"Binary classification label must be 0 or 1, got {self.label}")

        return ValidationResult(is_valid=len(errors) == 0, errors=errors, warnings=warnings)


def validate_catalog_item(item: Dict[str, Any]) -> ValidationResult:
    """Helper to validate catalog dictionary."""
    contract = CatalogItemContract(
        id=str(item.get("id", "")),
        name=str(item.get("name", "")),
        category=str(item.get("category", "")),
        price=float(item.get("price", 0.0) or 0.0),
        image_url=str(item.get("image_url", "")),
        image_sha256=item.get("image_sha256"),
        image_phash=item.get("image_phash"),
        source_page=item.get("source_page"),
        license_attribution=item.get("license_attribution"),
        author=item.get("author"),
        currency=str(item.get("currency", "INR")),
        is_archived=bool(item.get("is_archived", False)),
    )
    return contract.validate()


def validate_embedding(vector: List[float], entity_id: str = "test") -> ValidationResult:
    """Helper to validate embedding vector."""
    contract = EmbeddingContract(entity_id=entity_id, vector=vector)
    return contract.validate()


def validate_interaction(event: Dict[str, Any], allow_synthetic: bool = False) -> ValidationResult:
    """Helper to validate interaction event."""
    contract = InteractionEventContract(
        id=event.get("id"),
        user_id=int(event.get("user_id", 0)),
        product_id=str(event.get("product_id", "")),
        event_type=str(event.get("event_type", "")),
        created_at=event.get("created_at") or datetime.utcnow(),
        is_synthetic=bool(event.get("is_synthetic", False)),
    )
    return contract.validate(allow_synthetic=allow_synthetic)
