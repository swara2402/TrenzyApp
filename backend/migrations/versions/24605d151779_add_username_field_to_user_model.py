"""Add username field to User model

Revision ID: 24605d151779
Revises: 0021_onboarding_step
Create Date: 2026-10-14 02:11:17.756058
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = '24605d151779'
down_revision: Union[str, None] = '0021_onboarding_step'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add username column as nullable first
    op.add_column('users', sa.Column('username', sa.String(), nullable=True))
    
    # Populate existing users with default usernames based on their firebase_uid
    # This ensures no null values before we make the column non-nullable
    connection = op.get_bind()
    users = connection.execute(sa.text("SELECT id, firebase_uid, name FROM users")).fetchall()
    
    for user in users:
        user_id = user[0]
        firebase_uid = user[1]
        name = user[2] or f"user_{user_id}"
        # Create a simple username from firebase_uid to ensure uniqueness
        default_username = f"{name.lower().replace(' ', '_')}_{firebase_uid[:8]}"
        connection.execute(
            sa.text("UPDATE users SET username = :username WHERE id = :id"),
            {"username": default_username, "id": user_id}
        )
    
    # Now make the column non-nullable and add unique index
    op.alter_column('users', 'username', nullable=False)
    op.create_index(op.f('ix_users_username'), 'users', ['username'], unique=True)


def downgrade() -> None:
    pass