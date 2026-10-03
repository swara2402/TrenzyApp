"""Add optional user date of birth for age verification.

Revision ID: 0002_user_date_of_birth
Revises: 0001_baseline
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision: str = "0002_user_date_of_birth"
down_revision: Union[str, None] = "0001_baseline"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)
    tables = inspector.get_table_names()

    # Existing deployments already have the users table. Fresh environments
    # bootstrap tables through Base.metadata.create_all(), so this revision is
    # intentionally a no-op when the table does not exist yet.
    if "users" not in tables:
        return

    columns = {column["name"] for column in inspector.get_columns("users")}
    if "date_of_birth" not in columns:
        op.add_column(
            "users",
            sa.Column("date_of_birth", sa.Date(), nullable=True),
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)
    if "users" not in inspector.get_table_names():
        return

    columns = {column["name"] for column in inspector.get_columns("users")}
    if "date_of_birth" in columns:
        op.drop_column("users", "date_of_birth")
