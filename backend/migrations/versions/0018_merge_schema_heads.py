"""Merge the remaining Alembic branch into the authoritative schema head.

Revision ID: 0018_merge_schema_heads
Revises: 0002_user_is_admin, 0017_schema_sync
"""

from typing import Sequence, Union

from alembic import op


revision: str = "0018_merge_schema_heads"
down_revision: Union[str, Sequence[str], None] = (
    "0002_user_is_admin",
    "0017_schema_sync",
)
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
