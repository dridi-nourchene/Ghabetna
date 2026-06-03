"""rename admin_id to supervisor_id in alerts

Revision ID: c3d4e5f6a7b8
Revises: 
Create Date: 2026-05-24 10:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "c3d4e5f6a7b8"
down_revision: Union[str, None] = "c1d2e3f4a5b6"

branch_labels = None
depends_on    = None


def upgrade() -> None:
    # Renommer admin_id → supervisor_id
    op.alter_column("alerts", "admin_id",
                    new_column_name="supervisor_id",
                    existing_type=sa.UUID(),
                    nullable=True)

    # Renommer admin_comment → supervisor_comment
    op.alter_column("alerts", "admin_comment",
                    new_column_name="supervisor_comment",
                    existing_type=sa.Text(),
                    nullable=True)


def downgrade() -> None:
    op.alter_column("alerts", "supervisor_id",
                    new_column_name="admin_id",
                    existing_type=sa.UUID(),
                    nullable=True)
    op.alter_column("alerts", "supervisor_comment",
                    new_column_name="admin_comment",
                    existing_type=sa.Text(),
                    nullable=True)