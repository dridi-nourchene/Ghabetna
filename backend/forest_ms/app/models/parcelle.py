import uuid
import enum
from sqlalchemy import Column, String, Float, DateTime, Enum, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from geoalchemy2 import Geometry
from app.db.database import Base




class Parcelle(Base):
    __tablename__ = "parcelles"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    name = Column(String(255), nullable=False)

    # ── FK vers Forest ────────────────────────────────────
    forest_id = Column(UUID(as_uuid=True),ForeignKey("forests.id", ondelete="CASCADE"),nullable=False,)

    # ── Géométrie PostGIS ─────────────────────────────────
    geom = Column(Geometry(geometry_type="POLYGON", srid=4326),nullable=False,)
    area_hectares = Column(Float, nullable=True)
    centroid_lat  = Column(Float, nullable=True)
    centroid_lng  = Column(Float, nullable=True)


    created_by = Column(UUID(as_uuid=True), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now(), nullable=True)

    # ── Relation vers Forest ──────────────────────────────
    forest = relationship("Forest", back_populates="parcelles")

    def __repr__(self):
        return f"<Parcelle {self.name} — forêt {self.forest_id}>"