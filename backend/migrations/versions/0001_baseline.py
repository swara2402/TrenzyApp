"""empty message.

Revision ID: 0001_baseline
Revises: 
Create Date: 2025-04-01 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '0001_baseline'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Original empty baseline - let SQLAlchemy's Base.metadata.create_all() handle table creation
    pass


def downgrade() -> None:
    # Original empty baseline
    pass