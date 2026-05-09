import uuid
from datetime import datetime
from sqlalchemy import Column, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.db.database import Base


class AgentParcelle(Base):
    #Table d'affectation agent ↔ parcelle
    __tablename__ = "agent_parcelle"

    # agent_id comme PK → contrainte : 1 agent = 1 seule parcelle
    agent_id    = Column(UUID(as_uuid=True), primary_key=True)

    # FK locale vers parcelles (même DB → intégrité OK)
    parcelle_id = Column(
        UUID(as_uuid=True),
        ForeignKey("parcelles.id", ondelete="CASCADE"),
        nullable=False,
    )

    assigned_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relation vers Parcelle pour les jointures
    parcelle = relationship("Parcelle", back_populates="agents")

    def __repr__(self):
        return f"<AgentParcelle agent={self.agent_id} parcelle={self.parcelle_id}>"