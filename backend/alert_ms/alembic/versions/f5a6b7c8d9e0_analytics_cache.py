"""add agent_email + forest_supervisor_cache

Revision ID: f5a6b7c8d9e0
Revises: e4f5a6b7c8d9
Create Date: 2026-07-23 10:00:00
"""
from alembic import op
import sqlalchemy as sa

revision      = "f5a6b7c8d9e0"
down_revision = "e4f5a6b7c8d9"


def upgrade() -> None:
    op.add_column("assignments_cache", sa.Column("agent_email", sa.String(255), nullable=True))

    op.create_table(
        "forest_supervisor_cache",
        sa.Column("forest_id",        sa.UUID(),      primary_key=True),
        sa.Column("forest_name",      sa.String(255), nullable=True),
        sa.Column("supervisor_id",    sa.UUID(),      nullable=False),
        sa.Column("supervisor_nom",   sa.String(255), nullable=True),
        sa.Column("supervisor_phone", sa.String(30),  nullable=True),
        sa.Column("supervisor_email", sa.String(255), nullable=True),
        sa.Column("synced_at",        sa.DateTime(timezone=True),
                  server_default=sa.text("now()"), nullable=True),
        sa.PrimaryKeyConstraint("forest_id"),
    )
    op.create_index(
        "idx_forest_supervisor_cache_supervisor_id",
        "forest_supervisor_cache",
        ["supervisor_id"],
    )


def downgrade() -> None:
    op.drop_index("idx_forest_supervisor_cache_supervisor_id", table_name="forest_supervisor_cache")
    op.drop_table("forest_supervisor_cache")
    op.drop_column("assignments_cache", "agent_email")