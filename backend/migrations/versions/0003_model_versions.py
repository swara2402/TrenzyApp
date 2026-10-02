"""Add model_versions registry table.

Revision ID: 0003_model_versions
Revises: 0002_user_is_admin
Create Date: 2026-09-09
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0003_model_versions"
down_revision: Union[str, None] = "0002_user_is_admin"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _table_exists(conn, table: str) -> bool:
    from sqlalchemy import text

    row = conn.execute(
        text(
            "SELECT 1 FROM information_schema.tables "
            "WHERE table_name = :table"
        ),
        {"table": table},
    ).first()
    return row is not None


def upgrade() -> None:
    conn = op.get_bind()
    if _table_exists(conn, "model_versions"):
        return
    op.create_table(
        "model_versions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("model_name", sa.String(length=100), nullable=False),
        sa.Column("version", sa.String(length=50), nullable=False),
        sa.Column("artifact_path", sa.String(length=500), nullable=False),
        sa.Column("model_type", sa.String(length=50), nullable=True),
        sa.Column("training_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("dataset_version", sa.String(length=100), nullable=True),
        sa.Column("feature_version", sa.String(length=100), nullable=True),
        sa.Column("metrics", sa.JSON(), nullable=False, server_default=sa.text("'{}'::json")),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="development"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
        sa.Column("promoted_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_model_versions_model_name", "model_versions", ["model_name"])
    op.create_index(
        "ix_model_versions_model_name_version",
        "model_versions",
        ["model_name", "version"],
    )


def downgrade() -> None:
    conn = op.get_bind()
    if _table_exists(conn, "model_versions"):
        op.drop_index("ix_model_versions_model_name_version", table_name="model_versions")
        op.drop_index("ix_model_versions_model_name", table_name="model_versions")
        op.drop_table("model_versions")