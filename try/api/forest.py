import uuid
import enum
from sqlalchemy import Column, String, Float, DateTime, Text, Enum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from geoalchemy2 import Geometry
from app.db.database import Base


# ── Status de la forêt ────────────────────────────────────
class ForestStatus(str, enum.Enum):
    active    = "active"
    inactive  = "inactive"
    protected = "protected"

class Forest(Base):
    __tablename__ = "forests"

    id = Column(UUID(as_uuid=True),primary_key=True,default=uuid.uuid4,)

    name        = Column(String(255), nullable=False)

    # ── Géométrie PostGIS ─────────────────────────────────
    # POLYGON   → forme dessinée par l'admin sur flutter_map
    # srid=4326 → système GPS standard (WGS84) utilisé par OpenStreetMap
    geom = Column(Geometry(geometry_type="POLYGON", srid=4326),nullable=False,)

    area_hectares = Column(Float, nullable=True)
    centroid_lat  = Column(Float, nullable=True)
    centroid_lng  = Column(Float, nullable=True)

    # ── Superviseur assigné ───────────────────────────────
    # référence vers user-service bech ne5dhou ma3louma men user-service there is no foreign key possible between 2 databases
    supervisor_cin   = Column(UUID(as_uuid=True), nullable=True)
    supervisor_name = Column(String(255), nullable=True)

    status = Column(
        Enum(ForestStatus),
        default=ForestStatus.active,
        nullable=False,
    )

 
    created_by = Column(UUID(as_uuid=True), nullable=False)
    created_at = Column(DateTime(timezone=True),server_default=func.now(),)
    updated_at = Column(DateTime(timezone=True),onupdate=func.now(),nullable=True,)

    def __repr__(self):
        return f"<Forest {self.name} — {self.status}>"


