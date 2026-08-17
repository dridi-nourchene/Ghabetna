import uuid
import enum

from sqlalchemy import (
    Column, String, Text, Integer, Float, Date, DateTime,
    Enum, ForeignKey, Boolean, CheckConstraint
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.db.database import Base


# ── Enums ─────────────────────────────────────────────────

class Specialite(str, enum.Enum):
    chasseur   = "chasseur"
    campeur    = "campeur"
    apiculteur = "apiculteur"


class StatutDossier(str, enum.Enum):
    en_attente = "en_attente"
    approuve   = "approuve"
    rejete     = "rejete"


class TypeDocument(str, enum.Enum):
    # Communs aux trois spécialités
    cin_recto              = "cin_recto"
    cin_verso              = "cin_verso"
    # Chasseur — loi 88-20 et loi 69-33 sur les armes
    permis_chasse          = "permis_chasse"
    permis_detention       = "permis_detention"
    permis_port_transport  = "permis_port_transport"
    # Apiculteur — arrêté du 31 décembre 2015, annexe 19
    certificat_colonies    = "certificat_colonies"


# ── Profil commun ─────────────────────────────────────────

class ProfilCitoyen(Base):
    """
    Le dossier d'inscription. Contient uniquement ce qui relève du domaine
    citoyen : adresse, statut du dossier, décision de l'admin.

    Nom, email, CIN et mot de passe ne sont PAS ici : ils appartiennent à
    auth_ms. Les dupliquer créerait deux sources de vérité qui divergeraient.
    """
    __tablename__ = "profils_citoyens"

    profil_id      = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    # Référence LOGIQUE vers auth_ms. Pas de ForeignKey : les deux services
    # ont des bases séparées, PostgreSQL ne peut rien garantir entre elles.
    # C'est exactement pour ça que le rollback à l'inscription est vital.
    user_id        = Column(UUID(as_uuid=True), nullable=False, unique=True, index=True)

    specialite     = Column(Enum(Specialite), nullable=False)
    statut_dossier = Column(Enum(StatutDossier), nullable=False,
                            default=StatutDossier.en_attente)

    # Adresse — annexe 17 du registre national des apiculteurs, mais demandée
    # à tous : l'admin en a besoin pour situer le demandeur.
    gouvernorat    = Column(String(100), nullable=False)
    delegation     = Column(String(100), nullable=False)
    secteur        = Column(String(100))
    adresse        = Column(Text)
    telephone      = Column(String(20))

    # Décision de l'admin
    motif_rejet    = Column(Text)
    soumis_le      = Column(DateTime(timezone=True), server_default=func.now())
    traite_le      = Column(DateTime(timezone=True))
    traite_par     = Column(UUID(as_uuid=True))   # user_id de l'admin

    pieces      = relationship("PieceJointe", back_populates="profil",
                               cascade="all, delete-orphan")
    chasseur    = relationship("ProfilChasseur", back_populates="profil",
                               uselist=False, cascade="all, delete-orphan")
    apiculteur  = relationship("ProfilApiculteur", back_populates="profil",
                               uselist=False, cascade="all, delete-orphan")

    __table_args__ = (
        # Un motif est obligatoire pour un rejet : sans lui, le citoyen ne
        # sait pas quoi corriger et l'admin n'a aucune trace de sa décision.
        CheckConstraint(
            "statut_dossier::text <> 'rejete' OR motif_rejet IS NOT NULL",
            name="ck_profil_motif_si_rejete"
        ),
    )


# ── Pièces jointes ────────────────────────────────────────

class PieceJointe(Base):
    """
    Table générique plutôt qu'une colonne _path par document.

    Raison : le nombre de pièces varie selon la spécialité et selon que le
    chasseur possède une arme ou non. Des colonnes fixes donneraient six
    champs dont quatre toujours vides, et il faudrait migrer la table à
    chaque nouveau type de document.

    Le fichier lui-même n'est PAS en base — seulement son chemin. Même
    principe que image_path dans alert_ms.
    """
    __tablename__ = "pieces_jointes"

    piece_id      = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    profil_id     = Column(UUID(as_uuid=True),
                           ForeignKey("profils_citoyens.profil_id", ondelete="CASCADE"),
                           nullable=False, index=True)

    type_document = Column(Enum(TypeDocument), nullable=False)
    chemin        = Column(String(500), nullable=False)   # ex: citoyens/<user_id>/cin_recto.jpg

    # Sert à renvoyer le bon Content-Type quand l'admin ouvre la pièce, et à
    # refuser un exécutable renommé en .pdf. L'extension du nom de fichier
    # n'est pas fiable.
    mime_type     = Column(String(100), nullable=False)
    taille_octets = Column(Integer, nullable=False)

    # Traçabilité : quand la pièce a été déposée. Indispensable si le citoyen
    # renvoie un document plus lisible après un rejet, et pour purger un jour
    # les fichiers des dossiers refusés.
    televerse_le  = Column(DateTime(timezone=True), server_default=func.now())

    profil = relationship("ProfilCitoyen", back_populates="pieces")


# ── Sous-profil chasseur ──────────────────────────────────

class ProfilChasseur(Base):
    """
    Loi 88-20 : le permis de chasse est obligatoire.
    Loi 69-33 : détention et port/transport si le chasseur possède une arme.
    Les deux vont ensemble — une arme qu'on ne peut pas transporter reste
    immobilisée, donc les deux permis sont exigés dès que possede_arme.
    """
    __tablename__ = "profils_chasseurs"

    profil_id                    = Column(UUID(as_uuid=True),
                                          ForeignKey("profils_citoyens.profil_id",
                                                     ondelete="CASCADE"),
                                          primary_key=True)

    numero_permis_chasse         = Column(String(50), nullable=False)
    date_delivrance              = Column(Date)
    date_expiration              = Column(Date)
    gouvernorat_delivrance       = Column(String(100))

    possede_arme                 = Column(Boolean, nullable=False, default=False)
    numero_permis_detention      = Column(String(50))
    numero_permis_port_transport = Column(String(50))

    profil = relationship("ProfilCitoyen", back_populates="chasseur")

    __table_args__ = (
        CheckConstraint(
            "possede_arme = false OR ("
            " numero_permis_detention IS NOT NULL AND"
            " numero_permis_port_transport IS NOT NULL)",
            name="ck_chasseur_permis_arme"
        ),
    )


# ── Sous-profil apiculteur ────────────────────────────────

class ProfilApiculteur(Base):
    """
    Il n'existe pas de « permis d'apiculteur » en droit tunisien : l'arrêté du
    31 décembre 2015 ne crée aucune autorisation préalable. Ce qui prouve la
    qualité d'apiculteur, c'est l'inscription au registre national (annexe 17)
    et le certificat collectif d'identification des colonies (annexe 19).

    Personnes physiques uniquement pour l'instant. L'annexe 17 prévoit aussi
    les personnes morales avec un numéro I.F. — limite assumée du projet.
    """
    __tablename__ = "profils_apiculteurs"

    profil_id               = Column(UUID(as_uuid=True),
                                     ForeignKey("profils_citoyens.profil_id",
                                                ondelete="CASCADE"),
                                     primary_key=True)

    # Annexe 16 : code à 8 chiffres apposé sur la façade de la ruche,
    # découpé en 4 + 2 + 2. Je le stocke en trois morceaux parce que le texte
    # précise que le domicile détermine gouvernorat et délégation : je peux
    # donc vérifier la cohérence avec l'adresse déclarée du profil.
    code_apiculteur         = Column(String(4), nullable=False)
    code_delegation         = Column(String(2), nullable=False)
    code_gouvernorat        = Column(String(2), nullable=False)

    nombre_colonies_declare = Column(Integer, nullable=False, default=0)
    date_certificat         = Column(Date)

    profil  = relationship("ProfilCitoyen", back_populates="apiculteur")
    ruchers = relationship("Rucher", back_populates="apiculteur",
                           cascade="all, delete-orphan")

    __table_args__ = (
        CheckConstraint("code_apiculteur  ~ '^[0-9]{4}$'", name="ck_api_code_apiculteur"),
        CheckConstraint("code_delegation  ~ '^[0-9]{2}$'", name="ck_api_code_delegation"),
        CheckConstraint("code_gouvernorat ~ '^[0-9]{2}$'", name="ck_api_code_gouvernorat"),
    )


class Rucher(Base):
    """
    Annexes 18 et 19 : emplacement et nombre de colonies par rucher.

    emplacement est le champ officiel, en texte libre — c'est ce que demande
    l'arrêté. latitude/longitude sont un ajout applicatif, nullable : ils
    permettront de croiser les ruchers avec les parcelles de forest_ms et
    d'alerter un apiculteur quand un incendie se déclare près de son rucher.
    """
    __tablename__ = "ruchers"

    rucher_id       = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    profil_id       = Column(UUID(as_uuid=True),
                             ForeignKey("profils_apiculteurs.profil_id",
                                        ondelete="CASCADE"),
                             nullable=False, index=True)

    numero_rucher   = Column(Integer, nullable=False)     # « Rucher n° 1 » de l'annexe
    emplacement     = Column(String(255), nullable=False)
    latitude        = Column(Float)
    longitude       = Column(Float)
    nombre_colonies = Column(Integer, nullable=False, default=0)

    apiculteur = relationship("ProfilApiculteur", back_populates="ruchers")
