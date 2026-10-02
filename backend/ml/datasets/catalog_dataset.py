"""Dataset loader for validated product catalog."""

import json
import logging
from pathlib import Path
from typing import List, Dict, Any, Optional
import pandas as pd
from sqlalchemy.orm import Session
from app.models import Product

from ..contracts.data_contracts import CatalogItemContract, ValidationResult

logger = logging.getLogger(__name__)

# Static catalog fallback path (matches audit.py's fallback)
STATIC_CATALOG_PATH = Path("/Users/sam/Downloads/trenzy_production/backend/data/products.json")


class CatalogDatasetLoader:
    """Loads and validates the active product catalog for ML pipelines.
    Supports database-first loading with static file fallback for local development.
    """

    def __init__(self, db: Optional[Session] = None):
        self.db = db

    def load_catalog(self, exclude_archived: bool = True) -> pd.DataFrame:
        """Load catalog products and validate data contracts.

        First attempts to load from database, falls back to static products.json if database is unavailable.
        
        Returns:
            DataFrame containing validated catalog records
        """
        valid_records: List[Dict[str, Any]] = []
        validation_failures = 0
        
        # Try database first
        if self.db is not None:
            try:
                query = self.db.query(Product)
                if exclude_archived:
                    query = query.filter(Product.is_archived == False)  # noqa: E712

                products = query.all()
                for p in products:
                    contract = CatalogItemContract(
                        id=str(p.id),
                        name=p.name or "",
                        category=p.category or "",
                        price=float(p.price or 0.0),
                        image_url=p.image_url or "",
                        image_sha256=getattr(p, "image_sha256", None),
                        image_phash=getattr(p, "image_phash", None),
                        source_page=getattr(p, "source_page", None),
                        license_attribution=getattr(p, "license_attribution", None),
                        author=getattr(p, "author", None),
                        currency=getattr(p, "currency", "INR") or "INR",
                        is_archived=bool(p.is_archived),
                    )
                    res = contract.validate()
                    if not res.is_valid:
                        validation_failures += 1
                        logger.debug("Product %s failed catalog contract: %s", p.id, res.errors)
                        continue

                    valid_records.append({
                        "id": str(p.id),
                        "name": p.name,
                        "category": p.category,
                        "price": float(p.price or 0.0),
                        "image_url": p.image_url,
                        "image_sha256": getattr(p, "image_sha256", None),
                        "image_phash": getattr(p, "image_phash", None),
                        "source_page": getattr(p, "source_page", None),
                        "license_attribution": getattr(p, "license_attribution", None),
                        "author": getattr(p, "author", None),
                        "currency": getattr(p, "currency", "INR") or "INR",
                        "brand": p.brand,
                        "style": p.style,
                        "color": p.color,
                    })

                logger.info(
                    "Catalog loaded from database: %d valid products (%d rejected by contract)",
                    len(valid_records), validation_failures
                )
                return pd.DataFrame(valid_records)
            except Exception as e:
                logger.warning(f"Database catalog load failed: {e}, falling back to static catalog file")
        
        # Fallback to static file if database is unavailable or failed
        if STATIC_CATALOG_PATH.exists():
            with open(STATIC_CATALOG_PATH, 'r') as f:
                static_products = json.load(f)
            
            for p in static_products:
                # Skip archived if requested
                if exclude_archived and p.get("catalog_status") == "ARCHIVED":
                    continue
                    
                contract = CatalogItemContract(
                    id=str(p.get("id", "")),
                    name=p.get("name", "") or "",
                    category=p.get("category", "") or "",
                    price=float(p.get("price", 0.0) or 0.0),
                    image_url=p.get("image_url", "") or "",
                    image_sha256=p.get("image_sha256", None),
                    image_phash=p.get("image_phash", None),
                    source_page=p.get("source_page", None),
                    license_attribution=p.get("license_attribution", None),
                    author=p.get("author", None),
                    currency=p.get("currency", "INR") or "INR",
                    is_archived=bool(p.get("catalog_status") == "ARCHIVED"),
                )
                res = contract.validate()
                if not res.is_valid:
                    validation_failures += 1
                    logger.debug("Product %s failed catalog contract: %s", p.get("id"), res.errors)
                    continue

                valid_records.append({
                    "id": str(p.get("id", "")),
                    "name": p.get("name", ""),
                    "category": p.get("category", ""),
                    "price": float(p.get("price", 0.0) or 0.0),
                    "image_url": p.get("image_url", ""),
                    "image_sha256": p.get("image_sha256", None),
                    "image_phash": p.get("image_phash", None),
                    "source_page": p.get("source_page", None),
                    "license_attribution": p.get("license_attribution", None),
                    "author": p.get("author", None),
                    "currency": p.get("currency", "INR") or "INR",
                    "brand": p.get("brand", ""),
                    "style": p.get("style", ""),
                    "color": p.get("color", ""),
                })

            logger.info(
                "Catalog loaded from static file: %d valid products (%d rejected by contract)",
                len(valid_records), validation_failures
            )
            return pd.DataFrame(valid_records)
        else:
            raise FileNotFoundError(f"Neither database nor static catalog file found at {STATIC_CATALOG_PATH}")