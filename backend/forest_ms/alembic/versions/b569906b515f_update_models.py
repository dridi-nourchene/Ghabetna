"""update models

Revision ID: b569906b515f
Revises: a1b2c3d4e5f6
Create Date: 2026-05-09 12:30:25.435049

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "b2c3d4e5f6a7"
down_revision: Union[str, None] = "a1b2c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── 1. Table users_cache ──────────────────────────────
    op.create_table(
        "users_cache",
        sa.Column("user_id",   sa.UUID(),          primary_key=True),
        sa.Column("role",      sa.String(50),       nullable=False),
        sa.Column("nom",       sa.String(255),      nullable=False),
        sa.Column("email",     sa.String(255),      nullable=False),
        sa.Column("is_active", sa.Boolean(),        nullable=False, server_default="true"),
        sa.Column(
            "synced_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=True,
        ),
        sa.PrimaryKeyConstraint("user_id"),
    )

    # ── 2. Colonne superviseur_id dans forests ─────────────
    op.add_column(
        "forests",
        sa.Column("superviseur_id", sa.UUID(), nullable=True),
    )

    # ── 3. Table agent_parcelle ───────────────────────────
    op.create_table(
        "agent_parcelle",
        # agent_id PK → 1 agent = 1 seule parcelle
        sa.Column("agent_id",    sa.UUID(), primary_key=True),
        sa.Column(
            "parcelle_id",
            sa.UUID(),
            sa.ForeignKey("parcelles.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "assigned_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=True,
        ),
        sa.PrimaryKeyConstraint("agent_id"),
        sa.ForeignKeyConstraint(["parcelle_id"], ["parcelles.id"], ondelete="CASCADE"),
    )

    # Index pour accélérer les recherches par parcelle
    op.create_index(
        "idx_agent_parcelle_parcelle_id",
        "agent_parcelle",
        ["parcelle_id"],
    )


def downgrade() -> None:
    op.drop_index("idx_agent_parcelle_parcelle_id", table_name="agent_parcelle")
    op.drop_table("agent_parcelle")
    op.drop_column("forests", "superviseur_id")
    op.drop_table("users_cache")