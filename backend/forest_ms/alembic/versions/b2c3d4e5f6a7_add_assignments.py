"""add users_cache, agent_parcelle, superviseur_id

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
Create Date: 2026-05-09 10:00:00.000000

"""


from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from geoalchemy2 import Geometry

revision: str = "b2c3d4e5f6a7"
down_revision: Union[str, None] = None   # ← plus de dépendance
branch_labels = None
depends_on    = None


def upgrade() -> None:
    # ── 1. forests ────────────────────────────────────────
    op.create_table(
        "forests",
        sa.Column("id",             sa.UUID(),          primary_key=True),
        sa.Column("name",           sa.String(255),     nullable=False),
        sa.Column("geom",           Geometry("POLYGON", srid=4326), nullable=False),
        sa.Column("area_hectares",  sa.Float(),         nullable=True),
        sa.Column("centroid_lat",   sa.Float(),         nullable=True),
        sa.Column("centroid_lng",   sa.Float(),         nullable=True),
        sa.Column("superviseur_id", sa.UUID(),          nullable=True),
        sa.Column("created_by",     sa.UUID(),          nullable=False),
        sa.Column("created_at",     sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=True),
        sa.Column("updated_at",     sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )

    # ── 2. parcelles ──────────────────────────────────────
    op.create_table(
        "parcelles",
        sa.Column("id",             sa.UUID(),          primary_key=True),
        sa.Column("name",           sa.String(255),     nullable=False),
        sa.Column("forest_id",      sa.UUID(),          nullable=False),
        sa.Column("geom",           Geometry("POLYGON", srid=4326), nullable=False),
        sa.Column("area_hectares",  sa.Float(),         nullable=True),
        sa.Column("centroid_lat",   sa.Float(),         nullable=True),
        sa.Column("centroid_lng",   sa.Float(),         nullable=True),
        sa.Column("created_by",     sa.UUID(),          nullable=False),
        sa.Column("created_at",     sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=True),
        sa.Column("updated_at",     sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["forest_id"], ["forests.id"], ondelete="CASCADE"),
    )

    # ── 3. users_cache ────────────────────────────────────
    op.create_table(
        "users_cache",
        sa.Column("user_id",   sa.UUID(),         primary_key=True),
        sa.Column("role",      sa.String(50),      nullable=False),
        sa.Column("nom",       sa.String(255),     nullable=False),
        sa.Column("email",     sa.String(255),     nullable=False),
        sa.Column("phone",     sa.String(30),      nullable=True),
        sa.Column("is_active", sa.Boolean(),       nullable=False, server_default="true"),
        sa.Column("synced_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=True),
        sa.PrimaryKeyConstraint("user_id"),
    )

    # ── 4. agent_parcelle ─────────────────────────────────
    op.create_table(
        "agent_parcelle",
        sa.Column("agent_id",    sa.UUID(), primary_key=True),
        sa.Column("parcelle_id", sa.UUID(), nullable=False),
        sa.Column("assigned_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=True),
        sa.PrimaryKeyConstraint("agent_id"),
        sa.ForeignKeyConstraint(["parcelle_id"], ["parcelles.id"], ondelete="CASCADE"),
    )
    op.create_index("idx_agent_parcelle_parcelle_id", "agent_parcelle", ["parcelle_id"])


def downgrade() -> None:
    op.drop_index("idx_agent_parcelle_parcelle_id", table_name="agent_parcelle")
    op.drop_table("agent_parcelle")
    op.drop_table("users_cache")
    op.drop_table("parcelles")
    op.drop_table("forests")