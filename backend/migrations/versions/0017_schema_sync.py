"""Sync database schema with the current models (idempotent).

Revision ID: 0017_schema_sync
Revises: 0016_blend_unique

The migration history drifted from the models: several columns and tables
added over time (e.g. blends.deck_json) had no corresponding migration, so
databases created from migrations alone could not boot the current app.

This migration diffs Base.metadata against the live schema and:
  * creates any missing tables,
  * adds any missing columns (with a temporary server_default when the
    column is NOT NULL, so existing rows can be backfilled safely).

It is intentionally a no-op on databases that are already in sync, and is
safe to run on fresh and existing databases alike.
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0017_schema_sync"
down_revision: Union[str, None] = "0016_blend_unique"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    from app.models import Base

    bind = op.get_bind()
    insp = sa.inspect(bind)
    existing_tables = set(insp.get_table_names())

    # 1. Missing tables
    for table in Base.metadata.sorted_tables:
        if table.name in existing_tables:
            continue
        table.create(bind=bind, checkfirst=True)

    # 2. Missing columns on existing tables (re-inspect: step 1 may have
    # just created more tables).
    for table in Base.metadata.sorted_tables:
        if table.name not in set(sa.inspect(bind).get_table_names()):
            continue
        live_cols = {c["name"] for c in insp.get_columns(table.name)}
        for col in table.columns:
            if col.name in live_cols:
                continue
            server_default = None
            if not col.nullable:
                # Backfill existing rows before enforcing NOT NULL.
                if col.default is not None and col.default.is_scalar:
                    server_default = col.default.arg
                elif col.server_default is not None:
                    arg = getattr(col.server_default, "arg", None)
                    server_default = arg if isinstance(arg, str) else None
                if server_default is None:
                    ddl_type = col.type.compile(bind.dialect)
                    if "bool" in ddl_type:
                        server_default = "false"
                    elif any(
                        t in ddl_type.upper()
                        for t in ("INT", "NUM", "FLOAT", "DECIMAL")
                    ):
                        server_default = "0"
                    else:
                        server_default = ""
            with op.batch_alter_table(table.name) as batch_op:
                batch_op.add_column(
                    sa.Column(
                        col.name,
                        col.type,
                        nullable=col.nullable,
                        server_default=server_default,
                    )
                )


def downgrade() -> None:
    # Schema sync is additive-only; reversing it would drop data. No-op.
    pass
