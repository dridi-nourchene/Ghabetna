from datetime import datetime
from sqlalchemy import Column, String, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from app.database import Base


class AlertFact(Base):
    """
    Local, aggregation-only copy of alert lifecycle facts, fed by
    stream:alert.created / stream:alert.status_updated from alert_ms.
    """
    __tablename__ = "alert_facts"

    # Same UUID as the source alert in alert_ms — not a local PK we invent.
    id = Column(UUID(as_uuid=True), primary_key=True)

    type      = Column(String(50), nullable=False)
    status    = Column(String(50), nullable=False)
    forest_id = Column(UUID(as_uuid=True), nullable=False, index=True)
    agent_id  = Column(UUID(as_uuid=True), nullable=False, index=True)

    # Provenance du signalement : "agent" ou "citoyen". Stockee en String et
    # non en Enum, comme type et status : analytics_ms ne fait qu'agreger, il
    # n'a pas a repliquer les enums d'alert_ms ni a migrer quand ils changent.
    # Sans cette colonne, un citoyen est cherche dans users_cache — annuaire
    # du seul personnel — et ressort "Inconnu".
    source    = Column(String(20), nullable=False, server_default="agent")

    created_at = Column(DateTime(timezone=True), nullable=False)
    updated_at = Column(DateTime(timezone=True), nullable=True, onupdate=func.now())

    def __repr__(self):
        return f"<AlertFact {self.id} {self.type}/{self.status}>"