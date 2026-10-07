"""Add provenance, hashing, attribution, and currency columns to products table.

Revision ID: 0004_product_provenance
Revises: 0003_model_versions
Create Date: 2026-09-13
"""

from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "0004_product_provenance"
down_revision: Union[str, None] = "0003_model_versions"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _column_exists(conn, table: str, column: str) -> bool:
    from sqlalchemy import text
    row = conn.execute(
        text(
            "SELECT 1 FROM information_schema.columns "
            "WHERE table_name = :table AND column_name = :column"
        ),
        {"table": table, "column": column},
    ).first()
    return row is not None


def _index_exists(conn, name: str) -> bool:
    from sqlalchemy import text
    row = conn.execute(
        text("SELECT 1 FROM pg_indexes WHERE indexname = :name"),
        {"name": name},
    ).first()
    return row is not None


def upgrade() -> None:
    conn = op.get_bind()

    # Fresh databases start from the historical empty baseline. The full
    # current schema is created later by 0017_schema_sync, so this legacy
    # provenance migration must be a no-op until the products table exists.
    if not _table_exists(conn, "products"):
        return

    columns_to_add = [
        ("source_page", sa.Column("source_page", sa.String(), nullable=True)),
        ("license_attribution", sa.Column("license_attribution", sa.String(), nullable=True)),
        ("author", sa.Column("author", sa.String(), nullable=True)),
        ("image_sha256", sa.Column("image_sha256", sa.String(length=64), nullable=True)),
        ("image_phash", sa.Column("image_phash", sa.String(length=64), nullable=True)),
        ("currency", sa.Column("currency", sa.String(length=10), nullable=False, server_default="INR")),
    ]

    for col_name, col_def in columns_to_add:
        if not _column_exists(conn, "products", col_name):
            op.add_column("products", col_def)

    # Add indexes on hash columns for fast deduplication lookups.
    # Guard with existence checks — swallowing a PostgreSQL error with
    # try/except would abort the surrounding transaction and break the
    # version stamp that alembic writes afterwards.
    if not _index_exists(conn, "ix_products_image_sha256"):
        op.create_index("ix_products_image_sha256", "products", ["image_sha256"])

    if not _index_exists(conn, "ix_products_image_phash"):
        op.create_index("ix_products_image_phash", "products", ["image_phash"])


def downgrade() -> None:
    conn = op.get_bind()

    try:
        op.drop_index("ix_products_image_phash", table_name="products")
    except Exception:
        pass

    try:
        op.drop_index("ix_products_image_sha256", table_name="products")
    except Exception:
        pass

    columns_to_drop = [
        "currency",
        "image_phash",
        "image_sha256",
        "author",
        "license_attribution",
        "source_page",
    ]

    for col_name in columns_to_drop:
        if _column_exists(conn, "products", col_name):
            op.drop_column("products", col_name)
