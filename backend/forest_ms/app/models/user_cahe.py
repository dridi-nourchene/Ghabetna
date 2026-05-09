import uuid
from datetime import datetime
from sqlalchemy import Column, String, Boolean, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from app.db.database import Base


class UserCache(Base):
    #Copie locale des utilisateurs venant de auth-service via Redis Streams
   
    __tablename__ = "users_cache"

    user_id   = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    role      = Column(String(50), nullable=False)   # "agent" | "supervisor"
    nom       = Column(String(255), nullable=False)
    email     = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    synced_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    def __repr__(self):
        return f"<UserCache {self.nom} ({self.role})>"