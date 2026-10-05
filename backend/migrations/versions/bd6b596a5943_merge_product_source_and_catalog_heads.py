"""merge_product_source_and_catalog_heads

Revision ID: bd6b596a5943
Revises: 0003_product_source_metadata, 0019_product_catalog_columns
Create Date: 2026-10-06 02:39:19.213367
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'bd6b596a5943'
down_revision: Union[str, None] = ('0003_product_source_metadata', '0019_product_catalog_columns')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
