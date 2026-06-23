"""add assignments_cache table

Revision ID: e4f5a6b7c8d9
Revises: d2e3f4a5b6c7
Create Date: 2026-06-01 10:00:00
"""
from alembic import op
import sqlalchemy as sa

revision      = "e4f5a6b7c8d9"
down_revision = "d2e3f4a5b6c7"

def upgrade() -> None:
    op.create_table(
        "assignments_cache",
        sa.Column("agent_id",    sa.UUID(), primary_key=True),
        sa.Column("parcelle_id", sa.UUID(), nullable=False),
        sa.Column("forest_id",   sa.UUID(), nullable=False),
        sa.Column("agent_nom",   sa.String(255), nullable=True),
        sa.Column("agent_phone", sa.String(30),  nullable=True),
        sa.Column("synced_at",   sa.DateTime(timezone=True),
                  server_default=sa.text("now()"), nullable=True),
        sa.PrimaryKeyConstraint("agent_id"),
    )
    op.create_index(
        "idx_assignments_cache_forest_id",
        "assignments_cache",
        ["forest_id"]
    )

def downgrade() -> None:
    op.drop_index("idx_assignments_cache_forest_id")
    op.drop_table("assignments_cache")