"""create alert_facts table

Revision ID: 0001_create_alert_facts
Revises:
Create Date: 2026-07-23 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0001_create_alert_facts"
down_revision: Union[str, None] = None
branch_labels = None
depends_on    = None


def upgrade() -> None:
    op.create_table(
        "alert_facts",
        sa.Column("id",         sa.UUID(),      primary_key=True),
        sa.Column("type",       sa.String(50),  nullable=False),
        sa.Column("status",     sa.String(50),  nullable=False),
        sa.Column("forest_id",  sa.UUID(),      nullable=False),
        sa.Column("agent_id",   sa.UUID(),      nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("idx_alert_facts_forest_id", "alert_facts", ["forest_id"])
    op.create_index("idx_alert_facts_agent_id",  "alert_facts", ["agent_id"])


def downgrade() -> None:
    op.drop_index("idx_alert_facts_agent_id",  table_name="alert_facts")
    op.drop_index("idx_alert_facts_forest_id", table_name="alert_facts")
    op.drop_table("alert_facts")