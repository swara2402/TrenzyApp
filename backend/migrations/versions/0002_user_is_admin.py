"""users.is_admin — server-side admin flag (RBAC)

Revision ID: 0002_user_is_admin
Revises: 0001_baseline
Create Date: 2026-08-24

Adds a deny-by-default admin flag to users. All existing users default to
FALSE. Promote an operator after deployment:

    UPDATE users SET is_admin = TRUE WHERE firebase_uid = '<uid>';

Or grant admin via Firebase custom claim (checked first at request time):

    firebase auth:set-custom-user-claims <uid> '{"admin": true}'
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0002_user_is_admin"
down_revision: Union[str, None] = "0001_baseline"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _column_exists(conn, table: str, column: str) -> bool:
    from sqlalchemy import text

    row = conn.execute(
        text(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_name = :table AND column_name = :column"
        ),
        {"table": table, "column": column},
    ).first()
    return row is not None


def _table_exists(conn, table: str) -> bool:
    from sqlalchemy import inspect

    return table in inspect(conn).get_table_names()


def upgrade() -> None:
    conn = op.get_bind()
    if _table_exists(conn, "users") and not _column_exists(conn, "users", "is_admin"):
        op.add_column(
            "users",
            sa.Column("is_admin", sa.Boolean(), nullable=False, server_default=sa.false()),
        )


def downgrade() -> None:
    conn = op.get_bind()
    if _column_exists(conn, "users", "is_admin"):
        op.drop_column("users", "is_admin")
