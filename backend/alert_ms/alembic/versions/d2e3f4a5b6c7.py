from alembic import op
import sqlalchemy as sa
from geoalchemy2 import Geometry

revision = "d2e3f4a5b6c7"
down_revision = "c3d4e5f6a7b8"
branch_labels = None
depends_on    = None

# Définir l'enum explicitement
location_source_enum = sa.Enum(
    "exif", "agent_gps", "forest_only",
    name="locationsource"
)

def upgrade():
    # 1. Créer le type ENUM dans PostgreSQL EN PREMIER
    location_source_enum.create(op.get_bind(), checkfirst=True)

    # 2. Supprimer les anciennes colonnes
    op.drop_column("alerts", "latitude")
    op.drop_column("alerts", "longitude")

    # 3. Ajouter les nouvelles colonnes
    op.add_column("alerts", sa.Column("incident_lat", sa.Float(), nullable=True))
    op.add_column("alerts", sa.Column("incident_lng", sa.Float(), nullable=True))
    op.add_column("alerts", sa.Column("agent_lat",    sa.Float(), nullable=True))
    op.add_column("alerts", sa.Column("agent_lng",    sa.Float(), nullable=True))
    op.add_column("alerts", sa.Column(
        "location_source",
        location_source_enum,
        nullable=False,
        server_default="forest_only",
    ))

    # 4. geom devient nullable
    op.alter_column("alerts", "geom", nullable=True)


def downgrade():
    op.add_column("alerts", sa.Column("latitude",  sa.Float(), nullable=False, server_default="0"))
    op.add_column("alerts", sa.Column("longitude", sa.Float(), nullable=False, server_default="0"))
    op.drop_column("alerts", "incident_lat")
    op.drop_column("alerts", "incident_lng")
    op.drop_column("alerts", "agent_lat")
    op.drop_column("alerts", "agent_lng")
    op.drop_column("alerts", "location_source")

    # Supprimer le type ENUM après avoir supprimé la colonne
    location_source_enum.drop(op.get_bind(), checkfirst=True)