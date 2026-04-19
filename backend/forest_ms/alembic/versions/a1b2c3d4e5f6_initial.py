"""initial — forests + parcelles

Revision ID: a1b2c3d4e5f6
Revises:
Create Date: 2026-04-16 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
import geoalchemy2

# revision identifiers
revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── 1. Table forests ─────────────────────────────────
    op.create_table(
        "forests",
        sa.Column("id",             sa.UUID(),          primary_key=True),
        sa.Column("name",           sa.String(255),     nullable=False),
        # GeoAlchemy2 crée automatiquement l'index GIST sur geom
        sa.Column(
            "geom",
            geoalchemy2.types.Geometry(geometry_type="POLYGON", srid=4326),
            nullable=False,
        ),
        sa.Column("area_hectares",  sa.Float(),         nullable=True),
        sa.Column("centroid_lat",   sa.Float(),         nullable=True),
        sa.Column("centroid_lng",   sa.Float(),         nullable=True),
        sa.Column("created_by",     sa.UUID(),          nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=True,
        ),
        sa.Column("updated_at",     sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )

    # ── 2. Table parcelles ────────────────────────────────
    op.create_table(
        "parcelles",
        sa.Column("id",             sa.UUID(),          primary_key=True),
        sa.Column("name",           sa.String(255),     nullable=False),
        sa.Column(
            "forest_id",
            sa.UUID(),
            sa.ForeignKey("forests.id", ondelete="CASCADE"),
            nullable=False,
        ),
        # GeoAlchemy2 crée automatiquement l'index GIST sur geom
        sa.Column(
            "geom",
            geoalchemy2.types.Geometry(geometry_type="POLYGON", srid=4326),
            nullable=False,
        ),
        sa.Column("area_hectares",  sa.Float(),         nullable=True),
        sa.Column("centroid_lat",   sa.Float(),         nullable=True),
        sa.Column("centroid_lng",   sa.Float(),         nullable=True),
        sa.Column("created_by",     sa.UUID(),          nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=True,
        ),
        sa.Column("updated_at",     sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(
            ["forest_id"],
            ["forests.id"],
            ondelete="CASCADE",
        ),
    )

    # Index sur forest_id (accélère les JOINs et filtres par forêt)
    op.create_index(
        "idx_parcelles_forest_id",
        "parcelles",
        ["forest_id"],
    )


def downgrade() -> None:
    # Ordre inverse : parcelles d'abord (dépend de forests)
    op.drop_index("idx_parcelles_forest_id", table_name="parcelles")
    op.drop_table("parcelles")
    op.drop_table("forests")