"""Add uniqueness constraints for collaborative blend data.

Revision ID: 0016_add_blend_unique_constraints
Revises: 0004_product_provenance
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0016_blend_unique"
down_revision: Union[str, None] = "0004_product_provenance"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


_CONSTRAINTS = (
    (
        "uq_blend_members_blend_user",
        "blend_members",
        ("blend_id", "user_firebase_uid"),
    ),
    (
        "uq_blend_swipes_blend_user_product",
        "blend_swipes",
        ("blend_id", "user_firebase_uid", "product_id"),
    ),
)


def _constraint_exists(connection: sa.Connection, name: str) -> bool:
    inspector = sa.inspect(connection)
    return any(
        constraint.get("name") == name
        for table in ("blend_members", "blend_swipes")
        for constraint in inspector.get_unique_constraints(table)
    )


def upgrade() -> None:
    connection = op.get_bind()
    for name, table, columns in _CONSTRAINTS:
        if not _constraint_exists(connection, name):
            op.create_unique_constraint(name, table, list(columns))


def downgrade() -> None:
    connection = op.get_bind()
    for name, table, _ in reversed(_CONSTRAINTS):
        if _constraint_exists(connection, name):
            op.drop_constraint(name, table, type_="unique")
