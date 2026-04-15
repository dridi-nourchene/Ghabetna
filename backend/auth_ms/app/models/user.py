import uuid
import enum
from datetime import datetime
from sqlalchemy import (
    Column, String, Text, Boolean, DateTime, Date,
    Enum, ForeignKey, CheckConstraint
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.db.database import Base

# ── Enum statut utilisateur ───────────────────────────────
class UserStatus(str, enum.Enum):
    active   = "active"
    inactive = "inactive"
    banned   = "banned"

class UserRole(str, enum.Enum):
    admin = "admin"
    supervisor = "supervisor"
    agent = "agent"


class User(Base):
    __tablename__ = "users"

    user_id       = Column(UUID(as_uuid=True), primary_key=True,default=uuid.uuid4)
    full_name     = Column(String(255), nullable=False)
    email         = Column(String(255), nullable=False, unique=True)
    cin           = Column(String(8),  nullable=False, unique=True)
    phone         = Column(String(20))
    password_hash = Column(String(255), nullable=True )

    # Rôle (FK vers roles) One-to-Many 
    #role_id       = Column(UUID(as_uuid=True),ForeignKey("roles.role_id"),nullable=False)
    birth_date    = Column(Date, nullable=True)
    role          = Column(Enum(UserRole), nullable=False)
    status        = Column(Enum(UserStatus),default=UserStatus.inactive,nullable=False,)
    created_at    = Column(DateTime(timezone=True),server_default=func.now())
    updated_at    = Column(DateTime(timezone=True),onupdate=func.now())

    # ── Relations ─────────────────────────────────────────
    #role           = relationship("Role", back_populates="users")
    refresh_tokens = relationship("RefreshToken", back_populates="user",cascade="all, delete-orphan")
    activation_tokens = relationship("ActivationToken",back_populates="user",cascade="all, delete-orphan")

    __table_args__ = (
        CheckConstraint(
            "cin ~ '^[0-9]{8}$'",  # regex PostgreSQL
            name="ck_users_cin_8_digits"
        ),
    )


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    token_id         = Column(UUID(as_uuid=True), primary_key=True,default=uuid.uuid4)

    #FK vers users
    user_id    = Column(UUID(as_uuid=True),ForeignKey("users.user_id", ondelete="CASCADE"),nullable=False)

    token      = Column(Text, nullable=False, unique=True)
    expires_at = Column(DateTime(timezone=True), nullable=False)

    # True = déconnecté → token invalide même pas expiré
    revoked    = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="refresh_tokens")

class ActivationToken(Base):
    __tablename__ = "activation_tokens"

    token_id   = Column(UUID(as_uuid=True), primary_key=True,default=uuid.uuid4)
    user_id    = Column(UUID(as_uuid=True),ForeignKey("users.user_id",ondelete="CASCADE"),nullable=False)
    token      = Column(String(255), nullable=False, unique=True)
    expires_at = Column(DateTime(timezone=True), nullable=False)

    used       = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime(timezone=True),server_default=func.now())

    user = relationship("User", back_populates="activation_tokens")