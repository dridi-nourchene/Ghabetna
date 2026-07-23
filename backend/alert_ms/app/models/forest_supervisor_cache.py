from sqlalchemy import Column, String, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from app.db.database import Base


class ForestSupervisorCache(Base):
    """
    Cache local forêt ↔ superviseur.
    Alimenté par Redis Streams (stream:superviseur.assigned/removed) depuis forest_ms.
    Une ligne par forêt ayant un superviseur assigné.
    """
    __tablename__ = "forest_supervisor_cache"

    forest_id        = Column(UUID(as_uuid=True), primary_key=True)
    forest_name      = Column(String(255), nullable=True)
    supervisor_id    = Column(UUID(as_uuid=True), nullable=False, index=True)
    supervisor_nom   = Column(String(255), nullable=True)
    supervisor_phone = Column(String(30),  nullable=True)
    supervisor_email = Column(String(255), nullable=True)
    synced_at        = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    def __repr__(self):
        return f"<ForestSupervisorCache {self.forest_name} → {self.supervisor_nom}>"