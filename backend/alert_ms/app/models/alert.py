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
    en_cours = "en_cours"  # défaut à la création
    traiter  = "traiter"
    rejeter  = "rejeter"


class Alert(Base):
    __tablename__ = "alerts"

    id          = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    # ── Contenu ───────────────────────────────────────────
    type        = Column(SAEnum(AlertType),   nullable=False)
    status      = Column(SAEnum(AlertStatus), nullable=False,
                         default=AlertStatus.en_cours,
                         server_default="en_cours")
    description = Column(Text, nullable=True)

    # ── Localisation (extraite EXIF ou centroïde forêt) ───
    latitude    = Column(Float, nullable=False)
    longitude   = Column(Float, nullable=False)
    geom        = Column(Geometry("POINT", srid=4326), nullable=False)

    # ── Image ─────────────────────────────────────────────
    image_path  = Column(String(512), nullable=True)  # relatif à uploads/

    # ── Références cross-service (pas de FK) ──────────────
    agent_id    = Column(UUID(as_uuid=True), nullable=False)  # auth_ms
    forest_id   = Column(UUID(as_uuid=True), nullable=False)  # forest_ms

    # ── Commentaire admin ─────────────────────────────────
    admin_comment  = Column(Text,                    nullable=True)
    admin_id       = Column(UUID(as_uuid=True),      nullable=True)
    commented_at   = Column(DateTime(timezone=True), nullable=True)

    # ── Timestamps ────────────────────────────────────────
    created_at  = Column(DateTime(timezone=True), server_default=func.now())
    updated_at  = Column(DateTime(timezone=True), onupdate=func.now(), nullable=True)

    def __repr__(self):
        return f"<Alert {self.type} — {self.status} — agent {self.agent_id}>"