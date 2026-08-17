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
# en_attente : ajouté pour le citoyen. Son compte existe, son mot de passe
#              est déjà haché, mais il ne peut pas se connecter tant que
#              l'admin n'a pas validé son dossier dans citizen_ms.
# rejete     : dossier refusé par l'admin. Différent de banned : banned = un
#              compte qui a été actif puis sanctionné. rejete = un compte qui
#              n'a jamais été autorisé à démarrer. Je garde les deux séparés
#              pour pouvoir afficher un message correct au citoyen.
class UserStatus(str, enum.Enum):
    en_attente = "en_attente"
    active     = "active"
    inactive   = "inactive"
    rejete     = "rejete"
    banned     = "banned"


# ── Enum rôle ─────────────────────────────────────────────
# citoyen = utilisateur de public_user_app (chasseur / campeur / apiculteur).
# Les trois autres rôles sont le personnel qui utilise forest_app.
class UserRole(str, enum.Enum):
    admin      = "admin"
    supervisor = "supervisor"
    agent      = "agent"
    citoyen    = "citoyen"


# ── Enum spécialité ───────────────────────────────────────
# La spécialité reste ici, dans auth_ms, alors que le profil métier est dans
# citizen_ms. Raison : elle part dans le JWT, donc chatbot_ms sait quel
# domaine réglementaire interroger sans appeler citizen_ms à chaque question.
class Specialite(str, enum.Enum):
    chasseur   = "chasseur"
    campeur    = "campeur"
    apiculteur = "apiculteur"


class User(Base):
    __tablename__ = "users"

    user_id       = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    full_name     = Column(String(255), nullable=False)
    email         = Column(String(255), nullable=False, unique=True)
    cin           = Column(String(8),  nullable=False, unique=True)
    phone         = Column(String(20))
    password_hash = Column(String(255), nullable=True)

    birth_date    = Column(Date, nullable=True)
    role          = Column(Enum(UserRole), nullable=False)

    # Nullable : le personnel (admin / supervisor / agent) n'a pas de
    # spécialité. La contrainte plus bas garantit qu'un citoyen en a une.
    specialite    = Column(Enum(Specialite), nullable=True)

    status        = Column(Enum(UserStatus), default=UserStatus.inactive, nullable=False)
    created_at    = Column(DateTime(timezone=True), server_default=func.now())
    updated_at    = Column(DateTime(timezone=True), onupdate=func.now())

    # ── Relations ─────────────────────────────────────────
    refresh_tokens    = relationship("RefreshToken", back_populates="user",
                                     cascade="all, delete-orphan")
    activation_tokens = relationship("ActivationToken", back_populates="user",
                                     cascade="all, delete-orphan")

    __table_args__ = (
        CheckConstraint(
            "cin ~ '^[0-9]{8}$'",  # regex PostgreSQL
            name="ck_users_cin_8_digits"
        ),
        # Garde-fou au niveau base : un citoyen DOIT avoir une spécialité.
        # Je valide déjà dans Pydantic, mais la contrainte DB protège contre
        # une insertion faite par un script ou une future route mal écrite.
        CheckConstraint(
                "role::text <> 'citoyen' OR specialite IS NOT NULL",
                name="ck_users_citoyen_specialite"
            ),
    )


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    token_id   = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id    = Column(UUID(as_uuid=True),
                        ForeignKey("users.user_id", ondelete="CASCADE"),
                        nullable=False)

    token      = Column(Text, nullable=False, unique=True)
    expires_at = Column(DateTime(timezone=True), nullable=False)

    # True = déconnecté → token invalide même pas expiré
    revoked    = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="refresh_tokens")


class ActivationToken(Base):
    __tablename__ = "activation_tokens"

    token_id   = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id    = Column(UUID(as_uuid=True),
                        ForeignKey("users.user_id", ondelete="CASCADE"),
                        nullable=False)
    token      = Column(String(255), nullable=False, unique=True)
    expires_at = Column(DateTime(timezone=True), nullable=False)

    used       = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="activation_tokens")