"""persist onboarding progress for reliable resume

Revision ID: 0021_onboarding_step
Revises: 0020_outfit_roles
"""

from alembic import op
import sqlalchemy as sa

revision = "0021_onboarding_step"
down_revision = "0020_outfit_roles"
branch_labels = None
depends_on = None


def upgrade() -> None:
    columns = {
        column["name"]
        for column in sa.inspect(op.get_bind()).get_columns("user_preferences")
    }
    if "onboarding_step" not in columns:
        op.add_column(
            "user_preferences",
            sa.Column(
                "onboarding_step",
                sa.Integer(),
                nullable=False,
                server_default="0",
            ),
        )
    op.execute(
        """
        UPDATE user_preferences
        SET onboarding_step = CASE
            WHEN preferred_categories IS NULL THEN 1
            WHEN preferred_styles IS NULL THEN 2
            WHEN budget_max IS NULL OR shopping_priorities IS NULL THEN 3
            ELSE 5
        END
        """
    )


def downgrade() -> None:
    op.drop_column("user_preferences", "onboarding_step")
