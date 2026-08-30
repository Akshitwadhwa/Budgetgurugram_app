"""Public guest count on events.

Revision ID: 0002_summary
Revises: 0001_initial
Create Date: 2026-08-30
"""

import sqlalchemy as sa
from alembic import op

revision = "0002_summary"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("events", sa.Column("guest_count", sa.Integer(), nullable=True))
    op.add_column("events", sa.Column("guest_count_source", sa.Text(), nullable=True))
    op.add_column("events", sa.Column("guest_count_at", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    op.drop_column("events", "guest_count_at")
    op.drop_column("events", "guest_count_source")
    op.drop_column("events", "guest_count")
