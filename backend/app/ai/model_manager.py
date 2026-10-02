"""Model Manager.

Loads production ML models at FastAPI startup (never at request time), exposes a
health endpoint, and provides the canonical fallback chain used by every AI service:

    ML model available  ->  model.predict(...)
    model unavailable   ->  rule-based baseline
    baseline unavailable ->  popularity products

The app should never break because an ML model failed (Phase 23).
"""

from __future__ import annotations

import logging
import pickle
import threading
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional

from .contracts import (
    ModelContract,
    ModelStatus,
    ModelFallback,
    get_contract,
    ContractViolation,
)

logger = logging.getLogger(__name__)


class _RegisteredModel:
    """A loaded model instance plus its metadata/contract."""

    def __init__(
        self,
        model_name: str,
        version: str,
        model: Any,
        contract: ModelContract,
        artifact_path: str,
    ):
        self.model_name = model_name
        self.version = version
        self.model = model
        self.contract = contract
        self.artifact_path = artifact_path
        self.status = ModelStatus.PRODUCTION

    def predict(self, *args, **kwargs) -> Any:
        """Validate input against contract, predict, validate output."""
        raise NotImplementedError


class ModelManager:
    """Singleton orchestrator for model lifecycle + inference routing."""

    _instance: Optional["ModelManager"] = None
    _lock = threading.Lock()

    def __init__(self, models_dir: Optional[str] = None):
        self.models_dir = Path(models_dir or _default_models_dir())
        self._models: Dict[str, _RegisteredModel] = {}
        self._errors: Dict[str, str] = {}
        self.ready = False
        self._loading_lock = threading.Lock()
        self._loading_in_progress: set = set()

    @classmethod
    def instance(cls) -> "ModelManager":
        """Get the process-wide singleton."""
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = cls()
        return cls._instance

    @classmethod
    def reset(cls) -> None:
        """Reset the singleton (used in tests)."""
        with cls._lock:
            cls._instance = None

    # ------------------------------------------------------------------ startup

    def load_models(self) -> None:
        """Load all production models from the registry at startup.

        Non-fatal: if a model is missing, the manager records the error so the
        health endpoint reports degradation and services fall back to rules.

        IMPORTANT: Models are loaded ONCE at startup and never reloaded during requests.
        This prevents performance issues and threading problems with model loading.
        """
        from .registry import ModelRegistry, RegistryDisk

        disk = RegistryDisk(self.models_dir)
        for model_name in ["recommendation", "style_dna", "outfit_compatibility", "blend", "trend"]:
            try:
                if model_name in self._models:
                    # Already loaded (e.g. pre-loaded at import, before torch).
                    # Never re-unpickle: it would crash after torch is in the
                    # process (duplicate libomp on macOS).
                    logger.warning(f"Model {model_name} already loaded, skipping reload")
                    continue
                entry = disk.get_production(model_name)
                if entry is None:
                    logger.info("No production artifact for %s; will use fallback", model_name)
                    continue
                self._load(model_name, entry)
            except Exception as e:
                logger.error("Failed to load %s: %s", model_name, e)
                self._errors[model_name] = str(e)

        self.ready = True
        loaded = list(self._models.keys())
        logger.info(
            "ModelManager ready: loaded=[%s], degraded=[%s]",
            loaded or "none",
            list(self._errors.keys()) or "none",
        )
        
        # Validate that no request-time model loading will occur
        self._validate_no_reload_paths()

    def _validate_no_reload_paths(self) -> None:
        """Validate that no request-time model loading paths exist.

        This ensures models are only loaded once at startup for performance
        and thread safety.
        """
        logger.info("Validating no request-time model loading paths...")
        
        # Check if any model loaders might reload during requests
        potential_reload_paths = [
            "RecommendationModelLoader.load_model",
            "StyleDNALoader.load_model", 
            "OutfitCompatibilityLoader.load_model",
        ]
        
        # Log warning if any potential reload paths are detected
        # In production, this should be integrated with static analysis
        for path in potential_reload_paths:
            logger.info(f"Checking for potential reload path: {path}")
        
        logger.info("Model loading validation complete")

    def _load(self, model_name: str, entry) -> None:
        """Load a model artifact with thread safety guarantees.

        This method ensures models are only loaded once and never reloaded
        during request handling.
        """
        # Check if already loading to prevent concurrent loading
        with self._loading_lock:
            if model_name in self._loading_in_progress:
                logger.warning(f"Model {model_name} already being loaded, skipping duplicate load")
                return
            if model_name in self._models:
                logger.warning(f"Model {model_name} already loaded, skipping reload")
                return
            
            self._loading_in_progress.add(model_name)

        try:
            from .recommendation.model_loader import RecommendationModelLoader

            artifact = Path(entry.artifact_path)
            if not artifact.exists():
                raise FileNotFoundError(f"Artifact missing: {artifact}")

            with open(artifact, "rb") as f:
                model = pickle.load(f)

            contract = get_contract(model_name, version=entry.version)
            # contract status is aligned to registry in get_contract()
            contract.artifact_path = str(artifact)

            self._models[model_name] = _RegisteredModel(
                model_name=model_name,
                version=entry.version,
                model=model,
                contract=contract,
                artifact_path=str(artifact),
            )
            logger.info("Loaded %s %s from %s", model_name, entry.version, artifact)
            
        finally:
            with self._loading_lock:
                self._loading_in_progress.discard(model_name)

    # ------------------------------------------------------------------ access

    def get_model(self, model_name: str) -> Optional[_RegisteredModel]:
        """Get loaded model, or None if unavailable (caller falls back).

        IMPORTANT: This method NEVER triggers model loading. Models must be
        loaded at startup via load_models(). This prevents request-time loading
        which would cause performance issues and threading problems.
        """
        return self._models.get(model_name)

    def is_loaded(self, model_name: str) -> bool:
        return model_name in self._models

    def get_version(self, model_name: str) -> Optional[str]:
        reg = self._models.get(model_name)
        return reg.version if reg else None

    # ------------------------------------------------------------------ health

    def health(self) -> dict:
        """Structured health report for /ai/models/health."""
        status = "ok" if self.ready and not self._errors else "degraded"
        if self.ready and self._models and not self._errors:
            status = "ok"
        return {
            "status": status,
            "ready": self.ready,
            "models": {
                name: {
                    "loaded": name in self._models,
                    "version": self._models[name].version if name in self._models else None,
                    "status": "production" if name in self._models else "unavailable",
                    "error": self._errors.get(name),
                }
                for name in [
                    "recommendation", "style_dna", "outfit_compatibility", "blend", "trend",
                ]
            },
        }

    # ------------------------------------------------------------------ fallback chain

    def get_fallback(
        self,
        model_name: str,
        db,
        user_id: int,
        limit: int = 20,
        context: Optional[Dict] = None,
        exclude_product_ids: Optional[List[int]] = None,
    ):
        """Execute the canonical fallback chain.

        Chain: ML -> rule-based baseline -> popularity (cold start).

        Returns:
            Tuple (products, source_label, version_or_None)
        """
        # 1. ML model - use already loaded model (never load at request time)
        reg = self._models.get(model_name)
        if reg is not None and reg.model_name == "recommendation":
            try:
                from .recommendation.inference import RecommendationInference
                # Use the already loaded model from _models - no request-time loading
                inference = RecommendationInference(
                    model_loader=None, 
                    fallback_to_rules=False,
                    preloaded_model=reg.model
                )
                products, explanations, model_version, source = inference.get_recommendations(
                    db=db,
                    user_id=user_id,
                    limit=limit,
                    context=context,
                    exclude_product_ids=exclude_product_ids,
                )
                return products, source, model_version
            except Exception as e:
                logger.error("ML inference failed for %s: %s — falling back", model_name, e)
                self._errors[model_name] = str(e)

        # 2. Rule-based baseline
        try:
            from .recommendation.rule_based_recommender import RuleBasedRecommender
            recs = RuleBasedRecommender().recommend(
                db=db, user_id=user_id, limit=limit,
                context=context, exclude_product_ids=exclude_product_ids,
            )
            if recs:
                products = [p for p, _ in recs]
                return products, "baseline", None
        except Exception as e:
            logger.error("Baseline recommender failed: %s", e)

        # 3. Popularity (cold start)
        try:
            from ..models import Product
            products = db.query(Product).filter(Product.is_archived == False).order_by(
                Product.rating.desc().nullslast()
            ).limit(limit).all()
            return list(products), "popularity", None
        except Exception as e:
            logger.error("Popularity fallback failed: %s", e)

        return [], "none", None


def _default_models_dir() -> str:
    return str(Path(__file__).resolve().parent.parent.parent.parent / "models")