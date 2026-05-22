from alembic import op
import sqlalchemy as sa
from geoalchemy2 import Geometry

revision = "d2e3f4a5b6c7"
down_revision = "c1d2e3f4a5b6"
branch_labels = None
depends_on    = None


def upgrade():
    # Supprimer les anciennes colonnes latitude/longitude
    op.drop_column("alerts", "latitude")
    op.drop_column("alerts", "longitude")

    # Ajouter les nouvelles colonnes
    op.add_column("alerts", sa.Column("incident_lat", sa.Float(), nullable=True))
    op.add_column("alerts", sa.Column("incident_lng", sa.Float(), nullable=True))
    op.add_column("alerts", sa.Column("agent_lat",    sa.Float(), nullable=True))
    op.add_column("alerts", sa.Column("agent_lng",    sa.Float(), nullable=True))
    op.add_column("alerts", sa.Column(
        "location_source",
        sa.Enum("exif", "agent_gps", "forest_only", name="locationsource"),
        nullable=False,
        server_default="forest_only",
    ))

    # geom devient nullable
    op.alter_column("alerts", "geom", nullable=True)


def downgrade():
    op.add_column("alerts", sa.Column("latitude",  sa.Float(), nullable=False, server_default="0"))
    op.add_column("alerts", sa.Column("longitude", sa.Float(), nullable=False, server_default="0"))
    op.drop_column("alerts", "incident_lat")
    op.drop_column("alerts", "incident_lng")
    op.drop_column("alerts", "agent_lat")
    op.drop_column("alerts", "agent_lng")
    op.drop_column("alerts", "location_source")