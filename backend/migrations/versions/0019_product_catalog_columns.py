"""Ensure product catalog import columns exist.

Revision ID: 0019_product_catalog_columns
Revises: 0018_merge_schema_heads

This is intentionally explicit and idempotent. Older Trenzy databases may
have reached the merged Alembic head without receiving all catalog metadata
columns expected by the image catalog importer.
"""

from alembic import op
import sqlalchemy as sa


revision = "0019_product_catalog_columns"
down_revision = "0018_merge_schema_heads"
branch_labels = None
depends_on = None


_COLUMNS = {
    "source": sa.String(),
    "source_license": sa.String(),
    "source_page": sa.String(),
    "license_attribution": sa.String(),
    "author": sa.String(),
    "image_sha256": sa.String(64),
    "image_phash": sa.String(64),
    "currency": sa.String(10),
    "image_embedding_status": sa.String(50),
    "image_embedding_model": sa.String(100),
    "image_embedding_version": sa.String(50),
    "image_embedding_created_at": sa.DateTime(timezone=True),
    "text_embedding_status": sa.String(50),
    "text_embedding_model": sa.String(100),
    "text_embedding_version": sa.String(50),
    "text_embedding_created_at": sa.DateTime(timezone=True),
}


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing = {column["name"] for column in inspector.get_columns("products")}

    for name, column_type in _COLUMNS.items():
        if name not in existing:
            op.add_column(
                "products",
                sa.Column(name, column_type, nullable=True),
            )


def downgrade() -> None:
    # Intentionally non-destructive: catalog data and embeddings should not be
    # removed automatically during a downgrade.
    pass
