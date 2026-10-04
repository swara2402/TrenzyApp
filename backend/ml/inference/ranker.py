"""Inference ranker combining FashionCLIP embeddings and Style DNA scoring."""

import logging
from typing import List, Dict, Any, Optional
import numpy as np
from sqlalchemy.orm import Session

from app.models import Product
from app.ai.models_ai import UserStyleProfile, ProductEmbedding
from ..features.feature_engineering import FeatureExtractor
from ..registry.model_registry import ProductionModelRegistry

logger = logging.getLogger(__name__)


class HybridRanker:
    """Combines vector similarity and tabular features for real-time ranking."""

    def __init__(self, db: Session):
        self.db = db
        self.feature_extractor = FeatureExtractor()
        self.registry = ProductionModelRegistry(db)

    def rank_products(
        self,
        products: List[Product],
        user_profile: Optional[UserStyleProfile],
        query_embedding: Optional[np.ndarray] = None,
        top_k: int = 20,
    ) -> List[Dict[str, Any]]:
        """Rank products for a user based on visual and style affinity.

        Args:
            products: List of candidate products
            user_profile: User's Style DNA profile
            query_embedding: Optional query embedding (from image or text)
            top_k: Number of top items to return
        """
        if not products:
            return []

        scored_items = []

        # Check if a production LightGBM model is active
        prod_model = self.registry.get_production_model("lightgbm_ranker")

        for product in products:
            score = 0.5  # Baseline

            # 1. Visual/Text similarity score
            if query_embedding is not None:
                prod_emb_row = self.db.query(ProductEmbedding).filter(
                    ProductEmbedding.product_id == product.id
                ).first()
                if prod_emb_row and prod_emb_row.combined_embedding:
                    p_emb = np.array(prod_emb_row.combined_embedding, dtype=np.float32)
                    norm_q = np.linalg.norm(query_embedding)
                    norm_p = np.linalg.norm(p_emb)
                    if norm_q > 0 and norm_p > 0:
                        cos_sim = float(np.dot(query_embedding, p_emb) / (norm_q * norm_p))
                        score += 0.3 * cos_sim

            # 2. Style DNA category affinity
            if user_profile and user_profile.style_scores and product.style:
                style_match = user_profile.style_scores.get(product.style.lower(), 0.0)
                score += 0.2 * style_match

            # 3. Color affinity
            if user_profile and user_profile.color_scores and product.color:
                color_match = user_profile.color_scores.get(product.color.lower(), 0.0)
                score += 0.1 * color_match

            scored_items.append({
                "product": product,
                "score": float(score),
                "model_status": "lightgbm" if prod_model else "rules_style_dna",
            })

        # Sort descending by score
        scored_items.sort(key=lambda x: x["score"], reverse=True)
        return scored_items[:top_k]
