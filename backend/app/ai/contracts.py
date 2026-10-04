"""ML Model Contracts.

Defines the interface, input/output schema, and behavior contracts for all Trenzy ML models.

Every model in the registry must satisfy the contract defined here. Contracts are the
source of truth for:

- What fields a model's input must contain (and their types / ranges).
- What shape a model's output must have.
- Expected value ranges (e.g. probabilities in [0, 1]).
- Fallback behavior when the model is unavailable.

``validate_input`` / ``validate_output`` actually enforce the schema at runtime so a
misbehaving model or feed is caught immediately instead of silently corrupting
recommendations.
"""

from __future__ import annotations

from typing import List, Dict, Any, Optional, Type
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum


class ModelStatus(str, Enum):
    """Model deployment status."""
    DEVELOPMENT = "development"
    STAGING = "staging"
    PRODUCTION = "production"
    DEPRECATED = "deprecated"
    FAILED = "failed"


class ModelFallback(str, Enum):
    """Fallback behavior when model is unavailable."""
    RULE_BASED = "rule_based"
    POPULARITY = "popularity"
    RANDOM = "random"
    NONE = "none"


class ContractViolation(ValueError):
    """Raised when input/output data violates a model contract."""


@dataclass
class FieldSpec:
    """Specification of a single field in a model's input/output schema.

    Attributes:
        required: Field must be present.
        types: Acceptable Python types (checked with isinstance).
        range: Optional (min, max) tuple for numeric fields.
        nullable: Whether None is acceptable.
    """
    required: bool = True
    types: tuple = (int,)
    range: Optional[tuple] = None
    nullable: bool = False

    def validate(self, value: Any, path: str) -> None:
        """Validate a value against this field spec, raising ContractViolation."""
        if value is None:
            if self.nullable:
                return
            raise ContractViolation(f"{path}: missing required value (None)")
        if not isinstance(value, self.types):
            raise ContractViolation(
                f"{path}: expected one of {[t.__name__ for t in self.types]}, "
                f"got {type(value).__name__}"
            )
        if self.range is not None and isinstance(value, (int, float)):
            lo, hi = self.range
            if not (lo <= value <= hi):
                raise ContractViolation(
                    f"{path}: value {value} out of range [{lo}, {hi}]"
                )


@dataclass
class ModelContract:
    """Base contract for all ML models."""

    model_name: str
    version: str
    status: ModelStatus
    input_schema: Dict[str, FieldSpec]
    output_schema: Dict[str, FieldSpec]
    expected_ranges: Dict[str, tuple]
    fallback: ModelFallback
    artifact_path: Optional[str] = None
    training_date: Optional[datetime] = None
    dataset_version: Optional[str] = None

    def validate_input(self, data: Dict[str, Any]) -> bool:
        """Validate input data against schema.

        Args:
            data: Input payload.

        Returns:
            True if valid.

        Raises:
            ContractViolation: if any field violates the schema.
        """
        data = data or {}
        for key, spec in self.input_schema.items():
            if key not in data and spec.required:
                raise ContractViolation(f"model input missing required field: {key}")
            if key in data:
                spec.validate(data[key], f"input.{key}")
        return True

    def validate_output(self, data: Dict[str, Any]) -> bool:
        """Validate output data against schema.

        Args:
            data: Output payload.

        Returns:
            True if valid.

        Raises:
            ContractViolation: if any field violates the schema.
        """
        data = data or {}
        for key, spec in self.output_schema.items():
            if key not in data and spec.required:
                raise ContractViolation(f"model output missing required field: {key}")
            if key in data:
                spec.validate(data[key], f"output.{key}")
        return True


# ----------------------------------------------------------------------------
# Named field specs (reused across contracts)
# ----------------------------------------------------------------------------

_INT = FieldSpec(types=(int,))
_INT_NULLABLE = FieldSpec(types=(int,), nullable=True)
_FLOAT01 = FieldSpec(types=(int, float), range=(0.0, 1.0))
_FLOAT01_NULLABLE = FieldSpec(types=(int, float), range=(0.0, 1.0), nullable=True)
_STR = FieldSpec(types=(str,))
_DICT = FieldSpec(types=(dict, tuple))
_DICT_OPT = FieldSpec(types=(dict, tuple), nullable=True)
_LIST = FieldSpec(types=(list, tuple))
_LIST_OPT = FieldSpec(types=(list, tuple), nullable=True)


class RecommenderContract(ModelContract):
    """Contract for recommendation model."""

    def __init__(self, version: str = "v1.0"):
        super().__init__(
            model_name="recommendation",
            version=version,
            status=ModelStatus.DEVELOPMENT,
            input_schema={
                "user_id": _INT,
                "limit": FieldSpec(types=(int,), range=(1, 100)),
                "context": _DICT_OPT,
                "exclude_product_ids": _LIST_OPT,
            },
            output_schema={
                "products": _LIST,
                "explanations": _LIST,
                "model_version": _STR,
                "fallback": _STR,
            },
            expected_ranges={
                "limit": (1, 100),
                "score": (0.0, 1.0),
            },
            fallback=ModelFallback.RULE_BASED,
        )


class StyleDNAContract(ModelContract):
    """Contract for Style DNA model."""

    def __init__(self, version: str = "v1.0"):
        super().__init__(
            model_name="style_dna",
            version=version,
            status=ModelStatus.DEVELOPMENT,
            input_schema={
                "user_id": _INT,
            },
            output_schema={
                "style_scores": _DICT,
                "color_scores": _DICT,
                "fit_scores": _DICT,
                "confidence": _FLOAT01,
                "model_version": _STR,
                "fallback": _STR,
            },
            expected_ranges={
                "style_score": (0.0, 1.0),
                "confidence": (0.0, 1.0),
            },
            fallback=ModelFallback.RULE_BASED,
        )


class OutfitCompatibilityContract(ModelContract):
    """Contract for outfit compatibility model."""

    def __init__(self, version: str = "v1.0"):
        super().__init__(
            model_name="outfit_compatibility",
            version=version,
            status=ModelStatus.DEVELOPMENT,
            input_schema={
                "product_ids": _LIST,
            },
            output_schema={
                "compatibility_score": _FLOAT01,
                "explanation": _STR,
                "model_version": _STR,
                "fallback": _STR,
            },
            expected_ranges={
                "compatibility_score": (0.0, 1.0),
            },
            fallback=ModelFallback.RULE_BASED,
        )


class BlendContract(ModelContract):
    """Contract for Blend model."""

    def __init__(self, version: str = "v1.0"):
        super().__init__(
            model_name="blend",
            version=version,
            status=ModelStatus.DEVELOPMENT,
            input_schema={
                "blend_id": _INT,
                "strategy": _STR,
                "limit": FieldSpec(types=(int,), range=(1, 50)),
            },
            output_schema={
                "products": _LIST,
                "strategy": _STR,
                "model_version": _STR,
                "fallback": _STR,
            },
            expected_ranges={
                "score": (0.0, 1.0),
                "limit": (1, 50),
            },
            fallback=ModelFallback.RULE_BASED,
        )


class TrendContract(ModelContract):
    """Contract for trend prediction model."""

    def __init__(self, version: str = "v1.0"):
        super().__init__(
            model_name="trend",
            version=version,
            status=ModelStatus.DEVELOPMENT,
            input_schema={
                "product_id": _INT_NULLABLE,
                "category_id": _INT_NULLABLE,
                "style": _STR,
                "horizon_days": FieldSpec(types=(int,), range=(1, 90)),
            },
            output_schema={
                "trend_score": _FLOAT01,
                "momentum": FieldSpec(types=(int, float), range=(-1.0, 1.0)),
                "confidence": _FLOAT01,
                "model_version": _STR,
                "fallback": _STR,
            },
            expected_ranges={
                "trend_score": (0.0, 1.0),
                "momentum": (-1.0, 1.0),
                "confidence": (0.0, 1.0),
            },
            fallback=ModelFallback.RULE_BASED,
        )


# Model Registry
MODEL_CONTRACTS = {
    "recommendation": RecommenderContract,
    "style_dna": StyleDNAContract,
    "outfit_compatibility": OutfitCompatibilityContract,
    "blend": BlendContract,
    "trend": TrendContract,
}


def get_contract(model_name: str, version: str = "v1.0") -> ModelContract:
    """Get contract for a model.

    Args:
        model_name: Model identifier (e.g. "recommendation").
        version: Contract version to instantiate.

    Returns:
        A ModelContract instance.

    Raises:
        ValueError: if the model name is unknown.
    """
    contract_class = MODEL_CONTRACTS.get(model_name)
    if not contract_class:
        raise ValueError(f"Unknown model: {model_name}")
    contract = contract_class(version=version)

    # Align contract status with the model registry if available. This keeps the
    # contract reflectively reporting what the registry says (e.g. PRODUCTION).
    try:
        from .registry import ModelRegistry
        entry = ModelRegistry.get(model_name)
        if entry is not None and entry.status is not None:
            try:
                contract.status = ModelStatus(entry.status)
                contract.version = entry.version
                contract.artifact_path = entry.artifact_path
                contract.training_date = entry.training_date
                contract.dataset_version = entry.dataset_version
            except ValueError:
                pass  # keep contract defaults for unknown statuses
    except ImportError:
        pass  # registry not importable in this context (e.g. offline training)

    return contract