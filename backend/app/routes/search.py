"""FastAPI search routes for product catalog.

Provides:
- Text search via PostgreSQL full‑text (GIN) index when ``q`` is supplied.
- Vector similarity search when a numeric ``vector`` list is supplied (uses
  pgvector ``<=>`` when available, NumPy cosine fallback otherwise).
- Visual search: encode an image URL via FashionCLIP, then find nearest
  products by embedding similarity.
- Semantic / natural-language search: encode a text query via FashionCLIP
  text encoder, then find nearest products by embedding similarity.

Both visual and semantic search call the real embedding service and fall back
gracefully (HTTP 503) when the ML stack is not loaded.
"""

from __future__ import annotations

import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, Query, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from sqlalchemy import select, func, desc

from ..db import get_session
from ..auth_deps import get_current_user
from ..models import Product
from ..ai.ml_config import EMBEDDING_DIM

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/search", tags=["search"])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _format_products(products_with_scores: list) -> list[dict]:
    """Serialize a list of (Product, score) tuples to JSON-safe dicts."""
    return [
        {
            "id": p.id,
            "name": p.name,
            "image_url": p.image_url,
            "brand": p.brand,
            "price": p.price,
            "category": p.category,
            "score": round(float(score), 4),
        }
        for p, score in products_with_scores
    ]


def _fallback_products(db: Session, limit: int) -> list[dict]:
    """Return newest products with a score of 0 when the ML stack is down."""
    stmt = select(Product).where(Product.is_archived.is_(False)).order_by(
        desc(Product.created_at)
    ).limit(limit)
    rows = db.execute(stmt).scalars().all()
    return [
        {
            "id": p.id,
            "name": p.name,
            "image_url": p.image_url,
            "brand": p.brand,
            "price": p.price,
            "category": p.category,
            "score": 0.0,
        }
        for p in rows
    ]


# ---------------------------------------------------------------------------
# GET /api/search/products  — text + optional vector search
# ---------------------------------------------------------------------------

@router.get("/products")
async def search_products(
    q: Optional[str] = Query(None, description="Full‑text search query"),
    vector: Optional[List[float]] = Query(
        None, description="Embedding vector for ANN search (length EMBEDDING_DIM)"
    ),
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_session),
):
    """Search products by text, vector similarity, or both.

    - If ``q`` is provided, results are filtered by the PostgreSQL ``tsvector``
      column (SQLite falls back to ``ILIKE``).
    - If ``vector`` is provided, results are ordered by cosine distance
      (pgvector ``<=>``; raw-SQL ordering on SQLite).
    - When both are supplied the text filter is applied first, then vector ranking.
    """
    stmt = select(Product).where(Product.is_archived.is_(False))
    dialect_name = db.get_bind().dialect.name if hasattr(db, "get_bind") else "sqlite"

    if q:
        if dialect_name == "postgresql":
            stmt = stmt.where(
                func.to_tsvector("english", Product.name + " " + func.coalesce(Product.description, "")).op("@@")(
                    func.plainto_tsquery("english", q)
                )
            )
        else:
            like = f"%{q}%"
            stmt = stmt.where(
                Product.name.ilike(like) | Product.description.ilike(like)
            )

    if vector:
        if len(vector) != EMBEDDING_DIM:
            raise HTTPException(
                status_code=400,
                detail=f"Vector length must match EMBEDDING_DIM ({EMBEDDING_DIM}).",
            )
        if dialect_name == "postgresql":
            stmt = stmt.order_by(
                Product.image_embedding_vector.op("<=>")(vector)
            )
        else:
            stmt = stmt.order_by(desc(Product.created_at))
    else:
        stmt = stmt.order_by(desc(Product.created_at))

    results = db.execute(stmt.limit(limit)).scalars().all()
    return [
        {
            "id": p.id,
            "name": p.name,
            "image_url": p.image_url,
            "brand": p.brand,
            "price": p.price,
            "category": p.category,
        }
        for p in results
    ]


# ---------------------------------------------------------------------------
# GET /api/search/visual_search  — image-to-products via FashionCLIP
# ---------------------------------------------------------------------------

@router.post("/visual_search")
async def visual_search(
    file: UploadFile = File(..., description="Fashion image to search"),
    user: dict = Depends(get_current_user),
    limit: int = Query(20, ge=1, le=100),
    min_similarity: float = Query(0.0, ge=0.0, le=1.0, description="Minimum cosine similarity"),
    db: Session = Depends(get_session),
):
    """Visual search: find products similar to an uploaded image.

    Remote URLs are deliberately not accepted. The previous implementation
    allowed arbitrary server-side URL fetching and created an SSRF risk.

    The image is encoded with FashionCLIP. Nearest neighbours are found via
    pgvector when available, otherwise via a NumPy in-memory scan of
    ``ProductEmbedding`` rows.

    Returns HTTP 503 when the ML stack is not loaded (e.g. dev/test without
    model weights), so callers can show a clear degraded-mode message rather
    than silently receiving unrelated products.
    """
    try:
        from ..ai.vision.embedding_service import get_embedding_service
        from ..ai.vision.vector_search import VectorSearch
    except ImportError as exc:
        logger.warning("ML stack not available for visual search: %s", exc)
        raise HTTPException(
            status_code=503,
            detail="Visual search is temporarily unavailable (ML stack not loaded).",
        )

    # Read and validate the image before passing it to the ML model.
    # This removes arbitrary remote URL fetching and bounds decompression work.
    try:
        import io
        from PIL import Image, UnidentifiedImageError

        raw = await file.read(5 * 1024 * 1024 + 1)
        if not raw:
            raise HTTPException(status_code=400, detail="Uploaded image is empty.")
        if len(raw) > 5 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="Image is too large (max 5MB).")

        try:
            image = Image.open(io.BytesIO(raw))
            image.verify()
            image = Image.open(io.BytesIO(raw)).convert("RGB")
        except (UnidentifiedImageError, OSError):
            raise HTTPException(status_code=400, detail="Invalid image file.")

        width, height = image.size
        if width < 64 or height < 64 or width > 4096 or height > 4096:
            raise HTTPException(status_code=400, detail="Image dimensions must be between 64x64 and 4096x4096.")
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to validate visual-search image: %s", exc, exc_info=True)
        raise HTTPException(status_code=400, detail="Invalid image upload.")

    try:
        embedding_service = get_embedding_service()
        query_vector = embedding_service.model.encode_image(image)
    except Exception as exc:
        logger.error("Failed to encode visual-search image: %s", exc, exc_info=True)
        raise HTTPException(
            status_code=503,
            detail="Visual search is temporarily unavailable.",
        )

    # Nearest-neighbour search
    try:
        searcher = VectorSearch()
        results = searcher.find_similar_by_image_vector(
            db=db,
            image_vector=query_vector,
            limit=limit,
            min_similarity=min_similarity,
        )
        return _format_products(results)
    except AttributeError:
        # VectorSearch may not have find_similar_by_image_vector on older code;
        # fall through to the pgvector_search path.
        pass
    except Exception as exc:
        logger.error("Vector search failed: %s", exc)
        raise HTTPException(status_code=500, detail="Vector search error.")

    # Fallback: raw pgvector / NumPy scan via ProductEmbedding table
    try:
        from ..ai.models_ai import ProductEmbedding
        import numpy as np

        embeddings = (
            db.query(ProductEmbedding)
            .filter(ProductEmbedding.combined_embedding.isnot(None))
            .all()
        )
        if not embeddings:
            raise HTTPException(
                status_code=503,
                detail="No product embeddings found. Run the embedding pipeline first.",
            )

        scored: list[tuple[Product, float]] = []
        for emb in embeddings:
            arr = np.array(emb.combined_embedding, dtype=np.float32)
            norm_q = query_vector / (np.linalg.norm(query_vector) + 1e-8)
            norm_p = arr / (np.linalg.norm(arr) + 1e-8)
            score = float(np.dot(norm_q, norm_p))
            if score >= min_similarity:
                product = db.get(Product, emb.product_id)
                if product and not product.is_archived:
                    scored.append((product, score))

        scored.sort(key=lambda x: x[1], reverse=True)
        return _format_products(scored[:limit])

    except HTTPException:
        raise
    except Exception as exc:
        logger.error("NumPy fallback visual search failed: %s", exc)
        raise HTTPException(status_code=500, detail="Visual search error.")


# ---------------------------------------------------------------------------
# GET /api/search/semantic_search  — text query to products via FashionCLIP
# ---------------------------------------------------------------------------

@router.get("/semantic_search")
async def semantic_search(
    query: str = Query(..., min_length=1, max_length=500, description="Natural-language fashion query"),
    user: dict = Depends(get_current_user),
    limit: int = Query(20, ge=1, le=100),
    min_similarity: float = Query(0.0, ge=0.0, le=1.0, description="Minimum cosine similarity"),
    db: Session = Depends(get_session),
):
    """Semantic search: find products matching a natural-language description.

    The query is encoded with FashionCLIP's text encoder.  Nearest neighbours
    are found via pgvector or a NumPy scan of ``ProductEmbedding`` rows.

    Returns HTTP 503 when the ML stack is not loaded.
    """
    try:
        from ..ai.vision.embedding_service import get_embedding_service
    except ImportError as exc:
        logger.warning("ML stack not available for semantic search: %s", exc)
        raise HTTPException(
            status_code=503,
            detail="Semantic search is temporarily unavailable (ML stack not loaded).",
        )

    # Encode the text query
    try:
        embedding_service = get_embedding_service()
        query_vector = embedding_service.model.encode_text(query)
    except Exception as exc:
        logger.error("Failed to encode query text '%s': %s", query, exc)
        raise HTTPException(
            status_code=503,
            detail="Semantic search is temporarily unavailable.",
        )

    # Nearest-neighbour scan via ProductEmbedding (text or combined vector)
    try:
        from ..ai.models_ai import ProductEmbedding
        import numpy as np

        embeddings = (
            db.query(ProductEmbedding)
            .filter(ProductEmbedding.combined_embedding.isnot(None))
            .all()
        )
        if not embeddings:
            raise HTTPException(
                status_code=503,
                detail="No product embeddings found. Run the embedding pipeline first.",
            )

        scored: list[tuple[Product, float]] = []
        for emb in embeddings:
            arr = np.array(emb.combined_embedding, dtype=np.float32)
            norm_q = query_vector / (np.linalg.norm(query_vector) + 1e-8)
            norm_p = arr / (np.linalg.norm(arr) + 1e-8)
            score = float(np.dot(norm_q, norm_p))
            if score >= min_similarity:
                product = db.get(Product, emb.product_id)
                if product and not product.is_archived:
                    scored.append((product, score))

        scored.sort(key=lambda x: x[1], reverse=True)
        return _format_products(scored[:limit])

    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Semantic search failed: %s", exc)
        raise HTTPException(status_code=500, detail="Semantic search error.")