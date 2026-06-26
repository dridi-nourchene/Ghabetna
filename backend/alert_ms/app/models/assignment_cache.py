import uuid
from sqlalchemy import Column, String, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from app.db.database import Base


class AssignmentCache(Base):
    """
    Cache local des affectations agent ↔ parcelle ↔ forêt
    Alimenté par Redis Streams depuis forest_ms
    Lecture seule — jamais modifié directement par alert_ms
    """
    __tablename__ = "assignments_cache"

    agent_id    = Column(UUID(as_uuid=True), primary_key=True)
    parcelle_id = Column(UUID(as_uuid=True), nullable=False)
    forest_id   = Column(UUID(as_uuid=True), nullable=False, index=True)
    agent_nom   = Column(String(255), nullable=True)
    agent_phone = Column(String(30),  nullable=True)
    
    forest_name   = Column(String(255), nullable=True)
    parcelle_name = Column(String(255), nullable=True)
    
    synced_at   = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now()
    )

    def __repr__(self):
        return f"<AssignmentCache {self.agent_nom} @ {self.parcelle_name}>"