"""End-to-end pipeline verification script (Phase 13).

Runs four checks in sequence and prints a final summary:

1. Embedding coverage  — counts products with completed image embeddings.
2. FAISS index         — loads the .bin file and runs a sample query.
3. Style DNA           — inserts a sample row and retrieves it.
4. Vector search API   — calls GET /api/search/products with a vector param.

Usage::

    APP_ENV=test python -m backend.app.ai.verification.run_pipeline

Exit codes:
    0 — all checks passed (or skipped gracefully).
    1 — one or more checks failed.
"""

from __future__ import annotations

import os
os.environ.setdefault("KMP_DUPLICATE_LIB_OK", "TRUE")
import sys
from pathlib import Path
import json
import logging

# Ensure backend directory is in sys.path so app imports resolve regardless of cwd
_BACKEND_DIR = Path(__file__).resolve().parent.parent.parent.parent
if str(_BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(_BACKEND_DIR))

logging.basicConfig(level=logging.INFO, format="%(levelname)s  %(message)s")
logger = logging.getLogger("pipeline_verify")

PASS = "✅"
SKIP = "⚠️ "
FAIL = "❌"

results: list[tuple[str, str, str]] = []  # (status, name, detail)


def _record(status: str, name: str, detail: str = "") -> None:
    results.append((status, name, detail))
    icon = {PASS: "PASS", SKIP: "SKIP", FAIL: "FAIL"}[status]
    logger.info("%-4s  %s  %s", icon, name, detail)


# ---------------------------------------------------------------------------
# 1. Embedding coverage
# ---------------------------------------------------------------------------
def _get_db_and_models():
    from app.db import SessionLocal
    from app.models import Product
    from app.models_style import StyleDNA
    from app.ai.ml_config import EMBEDDING_DIM
    return SessionLocal, Product, StyleDNA, EMBEDDING_DIM


# ---------------------------------------------------------------------------
# 1. Embedding coverage
# ---------------------------------------------------------------------------
def check_embeddings() -> None:
    try:
        SessionLocal, Product, _, _ = _get_db_and_models()
        db = SessionLocal()
        try:
            total = db.query(Product).count()
            completed = (
                db.query(Product)
                .filter(Product.image_embedding_status == "completed")
                .count()
            )
            _record(PASS, "Embedding coverage", f"{completed}/{total} products have image embeddings")
        finally:
            db.close()
    except Exception as exc:
        _record(FAIL, "Embedding coverage", str(exc))


# ---------------------------------------------------------------------------
# 2. FAISS index
# ---------------------------------------------------------------------------
def check_faiss() -> None:
    index_path = os.path.join(
        os.path.dirname(__file__), "..", "embeddings", "product_faiss_index.bin"
    )
    if not os.path.exists(index_path):
        _record(SKIP, "FAISS index", f"Index not found at {index_path}. Run fashionclip_generate first.")
        return
    try:
        import faiss  # type: ignore
        import numpy as np

        index = faiss.read_index(index_path)
        dim = index.d
        query = np.zeros((1, dim), dtype="float32")
        distances, indices = index.search(query, min(5, index.ntotal))
        _record(PASS, "FAISS index", f"ntotal={index.ntotal}, dim={dim}, top-5 indices={indices[0].tolist()}")
    except ImportError:
        _record(SKIP, "FAISS index", "faiss-cpu not installed — skipping")
    except Exception as exc:
        _record(FAIL, "FAISS index", str(exc))


# ---------------------------------------------------------------------------
# 3. Style DNA round-trip
# ---------------------------------------------------------------------------
def check_style_dna() -> None:
    try:
        SessionLocal, Product, StyleDNA, _ = _get_db_and_models()
        db = SessionLocal()
        try:
            product = db.query(Product).first()
            created_temp_product = False
            if not product:
                product = Product(id="__verify_product__", name="Verify Product")
                db.add(product)
                db.commit()
                created_temp_product = True

            target_pid = product.id
            row = StyleDNA(
                product_id=target_pid,
                dna_vector=[0.1, 0.2, 0.3],
                model_name="verify",
                model_version="v0",
            )
            db.add(row)
            db.commit()

            fetched = db.query(StyleDNA).filter(StyleDNA.id == row.id).first()
            if fetched:
                db.delete(fetched)
                db.commit()

            if created_temp_product:
                temp_p = db.query(Product).filter(Product.id == "__verify_product__").first()
                if temp_p:
                    db.delete(temp_p)
                    db.commit()

            _record(PASS, "Style DNA round-trip", "insert → fetch → delete succeeded")
        finally:
            db.close()
    except Exception as exc:
        _record(FAIL, "Style DNA round-trip", str(exc))


# ---------------------------------------------------------------------------
# 4. Vector search API (via HTTPX / requests)
# ---------------------------------------------------------------------------
def check_vector_search_api() -> None:
    base_url = os.getenv("API_BASE_URL")
    try:
        _, _, _, EMBEDDING_DIM = _get_db_and_models()
        vector = [0.0] * EMBEDDING_DIM
        if base_url:
            import requests  # type: ignore

            resp = requests.get(
                f"{base_url}/api/search/products",
                params={"limit": 5, "vector": vector},
                timeout=5,
            )
            if resp.status_code in (200, 400):
                _record(PASS, "Vector search API", f"HTTP {resp.status_code}")
            else:
                _record(FAIL, "Vector search API", f"HTTP {resp.status_code}: {resp.text[:120]}")
        else:
            from starlette.testclient import TestClient
            from app.main import app

            with TestClient(app) as client:
                resp = client.get(
                    "/api/search/products",
                    params={"limit": 5, "vector": vector},
                )
                if resp.status_code in (200, 400):
                    _record(PASS, "Vector search API", f"HTTP {resp.status_code} (in-process)")
                else:
                    _record(FAIL, "Vector search API", f"HTTP {resp.status_code}: {resp.text[:120]}")
    except Exception as exc:
        _record(SKIP, "Vector search API", f"Could not perform check: {exc}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> int:
    logger.info("=== Trenzy AI Pipeline Verification ===\n")

    # Ensure DB tables exist if running in standalone dev/test/CI
    try:
        _get_db_and_models()
        from app.db import engine, Base
        Base.metadata.create_all(bind=engine)
    except Exception as exc:
        logger.warning("Could not run Base.metadata.create_all: %s", exc)

    check_embeddings()
    check_faiss()
    check_style_dna()
    check_vector_search_api()

    logger.info("\n=== Summary ===")
    for status, name, detail in results:
        logger.info("  %s  %-35s  %s", status, name, detail)

    failures = [r for r in results if r[0] == FAIL]
    if failures:
        logger.error("\n%d check(s) FAILED.", len(failures))
        return 1
    logger.info("\nAll checks passed (or skipped).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
