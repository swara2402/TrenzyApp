"""Add product source metadata required by the catalog importer.

Revision ID: 0003_product_source_metadata
Revises: 0002_user_date_of_birth
"""
from alembic import op
import sqlalchemy as sa

revision = "0003_product_source_metadata"
down_revision = "0002_user_date_of_birth"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "products" not in inspector.get_table_names():
        return
    columns = {c["name"] for c in inspector.get_columns("products")}
    if "source" not in columns:
        op.add_column("products", sa.Column("source", sa.String(), nullable=True))


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "products" not in inspector.get_table_names():
        return
    columns = {c["name"] for c in inspector.get_columns("products")}
    if "source" in columns:
        op.drop_column("products", "source")
