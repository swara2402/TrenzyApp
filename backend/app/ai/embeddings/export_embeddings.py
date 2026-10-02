"""Export product embeddings to CSV and Parquet.

Reads all products from the database, extracts `id`, `image_embedding_vector`
and `text_embedding_vector`, and writes two files:
- `backend/exports/embeddings/embeddings.csv`
- `backend/exports/embeddings/embeddings.parquet`

The script respects the `APP_ENV=test` SQLite dev DB.
"""

import os
from pathlib import Path
import pandas as pd

from ..db import SessionLocal
from ..models import Product

OUTPUT_DIR = Path(os.getenv("EMBEDDING_EXPORT_DIR", "backend/exports/embeddings"))

def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    session = SessionLocal()
    try:
        products = session.query(Product.id, Product.image_embedding_vector, Product.text_embedding_vector).all()
        rows = []
        for pid, img_vec, txt_vec in products:
            rows.append({
                "product_id": pid,
                "image_embedding": img_vec,
                "text_embedding": txt_vec,
            })
        df = pd.DataFrame(rows)
        csv_path = OUTPUT_DIR / "embeddings.csv"
        parquet_path = OUTPUT_DIR / "embeddings.parquet"
        df.to_csv(csv_path, index=False)
        df.to_parquet(parquet_path, index=False)
        print(f"Exported {len(df)} embeddings to {csv_path} and {parquet_path}")
    finally:
        session.close()

if __name__ == "__main__":
    main()
