"""create alerts table

Revision ID: c1d2e3f4a5b6
Revises:
Create Date: 2026-05-12 10:00:00.000000
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from geoalchemy2 import Geometry

revision: str = "c1d2e3f4a5b6"
down_revision: Union[str, None] = None
branch_labels = None
depends_on    = None


def upgrade() -> None:
    op.create_table(
        "alerts",
        sa.Column("id",            sa.UUID(),    primary_key=True),
        sa.Column("type",          sa.Enum(
            "incendie", "vol", "inondation",
            "glissement", "maladie", "autre",
            name="alerttype"
        ), nullable=False),
        sa.Column("status",        sa.Enum(
            "en_cours", "traiter", "rejeter",
            name="alertstatus"
        ), nullable=False, server_default="en_cours"),
        sa.Column("description",   sa.Text(),    nullable=True),
        sa.Column("latitude",      sa.Float(),   nullable=False),
        sa.Column("longitude",     sa.Float(),   nullable=False),
        sa.Column("geom",          Geometry("POINT", srid=4326), nullable=False),
        sa.Column("image_path",    sa.String(512), nullable=True),
        sa.Column("agent_id",      sa.UUID(),    nullable=False),
        sa.Column("forest_id",     sa.UUID(),    nullable=False),
        sa.Column("admin_comment", sa.Text(),    nullable=True),
        sa.Column("admin_id",      sa.UUID(),    nullable=True),
        sa.Column("commented_at",  sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at",    sa.DateTime(timezone=True),
                  server_default=sa.text("now()"), nullable=True),
        sa.Column("updated_at",    sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    # Index spatial pour les requêtes map
    op.create_index("idx_alerts_geom",      "alerts", ["geom"],      postgresql_using="gist", if_not_exists=True)
    op.create_index("idx_alerts_forest_id", "alerts", ["forest_id"], if_not_exists=True)
    op.create_index("idx_alerts_agent_id",  "alerts", ["agent_id"],  if_not_exists=True)
    op.create_index("idx_alerts_status",    "alerts", ["status"],    if_not_exists=True)


def downgrade() -> None:
    op.drop_index("idx_alerts_status",    table_name="alerts")
    op.drop_index("idx_alerts_agent_id",  table_name="alerts")
    op.drop_index("idx_alerts_forest_id", table_name="alerts")
    op.drop_index("idx_alerts_geom",      table_name="alerts")
    op.drop_table("alerts")