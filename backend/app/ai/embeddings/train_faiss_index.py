"""Build a FAISS index from product embeddings.

The script loads `image_embedding_vector` and `text_embedding_vector` fields from the
`Product` table, concatenates them, builds a FAISS IndexFlatL2, and persists the
index to disk.

Usage:
    APP_ENV=test python -m backend.app.ai.embeddings.train_faiss_index
"""

import logging
from pathlib import Path
from typing import List, Tuple

import numpy as np

# Optional FAISS import – fallback to sklearn if unavailable
try:
    import faiss  # type: ignore
    _FAISS_AVAILABLE = True
except Exception:  # pragma: no cover
    _FAISS_AVAILABLE = False
    from sklearn.neighbors import NearestNeighbors  # type: ignore

from ...db import SessionLocal
from ...models import Product

logger = logging.getLogger(__name__)

INDEX_PATH = Path(__file__).parent / "product_faiss_index.bin"


def _load_embeddings() -> Tuple[np.ndarray, List[int]]:
    """Return an (N, D) matrix of concatenated embeddings and their product IDs.

    Products missing either image or text embeddings are skipped.
    """
    session = SessionLocal()
    records = (
        session.query(Product.id, Product.image_embedding_vector, Product.text_embedding_vector)
        .filter(Product.image_embedding_vector.isnot(None), Product.text_embedding_vector.isnot(None))
        .all()
    )
    session.close()

    vectors: List[np.ndarray] = []
    ids: List[int] = []
    for prod_id, img_vec, txt_vec in records:
        img_arr = np.asarray(img_vec, dtype=np.float32)
        txt_arr = np.asarray(txt_vec, dtype=np.float32)
        combined = np.concatenate([img_arr, txt_arr])
        vectors.append(combined)
        ids.append(prod_id)
    return np.stack(vectors), ids


def _build_faiss_index(embeddings: np.ndarray) -> "faiss.Index":
    """Create a simple flat L2 index and add the embeddings."""
    d = embeddings.shape[1]
    index = faiss.IndexFlatL2(d)
    index.add(embeddings)
    return index


def _save_faiss_index(index) -> None:
    """Persist the FAISS index to ``INDEX_PATH``."""
    faiss.write_index(index, str(INDEX_PATH))
    logger.info("FAISS index written to %s", INDEX_PATH)


def main() -> None:
    if not _FAISS_AVAILABLE:
        logger.error("FAISS library not available – install 'faiss-cpu' or use sklearn fallback.")
        return

    logger.info("Loading product embeddings from DB")
    vectors, ids = _load_embeddings()
    logger.info("Loaded %d vectors (dim=%d)", vectors.shape[0], vectors.shape[1])

    logger.info("Building FAISS index")
    index = _build_faiss_index(vectors)

    _save_faiss_index(index)
    logger.info("FAISS index training complete")


if __name__ == "__main__":
    main()
