import uuid
import enum
from sqlalchemy import Column, String, Float, DateTime, Enum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from geoalchemy2 import Geometry
from app.db.database import Base


class Forest(Base):
    __tablename__ = "forests"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    name = Column(String(255), nullable=False)

    # ── Géométrie PostGIS ─────────────────────────────────
    # POLYGON srid=4326 → WGS84 (GPS standard / OpenStreetMap)
    geom = Column(
        Geometry(geometry_type="POLYGON", srid=4326),
        nullable=False,
    )

    area_hectares = Column(Float, nullable=True)
    centroid_lat  = Column(Float, nullable=True)
    centroid_lng  = Column(Float, nullable=True)

    created_by = Column(UUID(as_uuid=True), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now(), nullable=True)

    # ── Relation vers Parcelles ───────────────────────────
    parcelles = relationship(
        "Parcelle",
        back_populates="forest",
        cascade="all, delete-orphan",
    )

    def __repr__(self):
        return f"<Forest {self.name} >"