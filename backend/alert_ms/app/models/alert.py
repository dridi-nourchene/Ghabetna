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
    depot_dechets     = "depot_dechets"       
    chasse_illegale   = "chasse_illegale"    
    activite_suspecte = "activite_suspecte"    
    autre             = "autre"


class AlertStatus(str, enum.Enum):
    en_cours = "en_cours"
    traiter  = "traiter"
    rejeter  = "rejeter"


class LocationSource(str, enum.Enum):
    exif        = "exif"
    agent_gps   = "agent_gps"
    forest_only = "forest_only"


class AlertSource(str, enum.Enum):
    """Qui a émis le signalement. Ne remplace pas agent_id (qui reste
    l'identifiant du créateur, agent ou citoyen) : distingue seulement la
    provenance pour l'affichage superviseur, sans toucher au nom de colonne
    existant — voir la note sur Alert.agent_id ci-dessous."""
    agent   = "agent"
    citoyen = "citoyen"


class Alert(Base):
    __tablename__ = "alerts"

    id          = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    type        = Column(SAEnum(AlertType),   nullable=False)
    status      = Column(SAEnum(AlertStatus), nullable=False,
                         default=AlertStatus.en_cours,
                         server_default="en_cours")
    description = Column(Text, nullable=True)

    # ── Localisation incident (EXIF) ──────────────────────
    incident_lat = Column(Float, nullable=True)
    incident_lng = Column(Float, nullable=True)

    # ── Localisation agent ────────────────────────────────
    agent_lat    = Column(Float, nullable=True)
    agent_lng    = Column(Float, nullable=True)

    location_source = Column(
        SAEnum(LocationSource),
        nullable=False,
        default=LocationSource.forest_only,
        server_default="forest_only",
    )

    geom        = Column(Geometry("POINT", srid=4326), nullable=True)
    image_path  = Column(String(512), nullable=True)

    # NOTE : "agent_id" garde son nom d'origine bien qu'il contienne
    # aujourd'hui aussi bien l'id d'un agent que celui d'un citoyen — c'est
    # le créateur du signalement, quel que soit son rôle. Le renommer en
    # "auteur_id" toucherait alert_ms, agent_app, forest_app et
    # analytics_ms pour un bénéfice cosmétique ; la colonne "source"
    # ci-dessous suffit à distinguer la provenance sans casser
    # /api/alerts/mine ni les lignes déjà en base.
    agent_id    = Column(UUID(as_uuid=True), nullable=False)
    forest_id   = Column(UUID(as_uuid=True), nullable=False)

    source = Column(
        SAEnum(AlertSource),
        nullable=False,
        default=AlertSource.agent,
        server_default="agent",
    )

    # ── Superviseur (remplace admin) ──────────────────────
    supervisor_comment = Column(Text,                    nullable=True)
    supervisor_id      = Column(UUID(as_uuid=True),      nullable=True)
    commented_at       = Column(DateTime(timezone=True), nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now(), nullable=True)