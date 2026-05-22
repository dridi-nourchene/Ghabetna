import uuid
import enum
from sqlalchemy import Column, String, Float, DateTime, Text, Enum as SAEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from geoalchemy2 import Geometry
from app.db.database import Base


class AlertType(str, enum.Enum):
    incendie   = "incendie"
    vol        = "vol"
    inondation = "inondation"
    glissement = "glissement"
    maladie    = "maladie"
    autre      = "autre"


class AlertStatus(str, enum.Enum):
    en_cours = "en_cours"
    traiter  = "traiter"
    rejeter  = "rejeter"


class LocationSource(str, enum.Enum):
    exif        = "exif"        # GPS depuis EXIF photo
    agent_gps   = "agent_gps"  # GPS téléphone agent
    forest_only = "forest_only" # Pas de coordonnées précises


class Alert(Base):
    __tablename__ = "alerts"

    id          = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    type        = Column(SAEnum(AlertType),   nullable=False)
    status      = Column(SAEnum(AlertStatus), nullable=False,
                         default=AlertStatus.en_cours,
                         server_default="en_cours")
    description = Column(Text, nullable=True)

    # ── Localisation incident (EXIF) — peut être null ─────
    incident_lat = Column(Float, nullable=True)
    incident_lng = Column(Float, nullable=True)

    # ── Localisation agent au moment du submit ────────────
    agent_lat    = Column(Float, nullable=True)
    agent_lng    = Column(Float, nullable=True)

    # ── Source de la localisation ─────────────────────────
    location_source = Column(
        SAEnum(LocationSource),
        nullable=False,
        default=LocationSource.forest_only,
        server_default="forest_only",
    )

    # ── Géométrie PostGIS — uniquement si EXIF présent ────
    geom        = Column(Geometry("POINT", srid=4326), nullable=True)

    image_path  = Column(String(512), nullable=True)
    agent_id    = Column(UUID(as_uuid=True), nullable=False)
    forest_id   = Column(UUID(as_uuid=True), nullable=False)

    admin_comment = Column(Text,                    nullable=True)
    admin_id      = Column(UUID(as_uuid=True),      nullable=True)
    commented_at  = Column(DateTime(timezone=True), nullable=True)
    created_at    = Column(DateTime(timezone=True), server_default=func.now())
    updated_at    = Column(DateTime(timezone=True), onupdate=func.now(),
                           nullable=True)