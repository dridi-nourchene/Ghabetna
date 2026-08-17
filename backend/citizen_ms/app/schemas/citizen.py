from datetime import date, datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

from app.models.citizen import Specialite, StatutDossier, TypeDocument


# ── Sortie : pièce jointe ─────────────────────────────────

class PieceJointeOut(BaseModel):
    piece_id:      UUID
    type_document: TypeDocument
    url:           str            # construit à partir de BASE_URL + chemin
    mime_type:     str
    taille_octets: int
    televerse_le:  datetime

    model_config = {"from_attributes": True}


# ── Sortie : sous-profils ─────────────────────────────────

class ProfilChasseurOut(BaseModel):
    numero_permis_chasse:         str
    date_delivrance:              Optional[date] = None
    date_expiration:              Optional[date] = None
    gouvernorat_delivrance:       Optional[str]  = None
    possede_arme:                 bool
    numero_permis_detention:      Optional[str]  = None
    numero_permis_port_transport: Optional[str]  = None

    model_config = {"from_attributes": True}


class RucherOut(BaseModel):
    numero_rucher:   int
    emplacement:     str
    latitude:        Optional[float] = None
    longitude:       Optional[float] = None
    nombre_colonies: int

    model_config = {"from_attributes": True}


class ProfilApiculteurOut(BaseModel):
    code_apiculteur:         str
    code_delegation:         str
    code_gouvernorat:        str
    nombre_colonies_declare: int
    date_certificat:         Optional[date] = None
    ruchers:                 list[RucherOut] = []

    model_config = {"from_attributes": True}


# ── Sortie : dossier complet vu par l'admin ───────────────

class DossierOut(BaseModel):
    profil_id:      UUID
    user_id:        UUID
    specialite:     Specialite
    statut_dossier: StatutDossier

    gouvernorat:    str
    delegation:     str
    secteur:        Optional[str] = None
    adresse:        Optional[str] = None
    telephone:      Optional[str] = None

    motif_rejet:    Optional[str] = None
    soumis_le:      datetime
    traite_le:      Optional[datetime] = None

    pieces:     list[PieceJointeOut]        = []
    chasseur:   Optional[ProfilChasseurOut]   = None
    apiculteur: Optional[ProfilApiculteurOut] = None

    # Alertes de cohérence calculées à la volée, pas stockées : elles aident
    # l'admin à décider mais ne décident jamais à sa place.
    alertes:    list[str] = []

    model_config = {"from_attributes": True}


class InscriptionOut(BaseModel):
    """Réponse renvoyée au citoyen juste après sa soumission."""
    profil_id:      UUID
    user_id:        UUID
    statut_dossier: StatutDossier
    message:        str


# ── Entrée : décision de l'admin ──────────────────────────

class DecisionIn(BaseModel):
    approuve:    bool
    motif_rejet: Optional[str] = Field(None, max_length=1000)

    @field_validator("motif_rejet")
    @classmethod
    def motif_obligatoire_si_rejet(cls, v, info):
        # Un rejet sans motif est inexploitable : le citoyen ne saurait pas
        # quoi corriger et l'admin ne laisserait aucune trace de sa décision.
        if info.data.get("approuve") is False and not (v and v.strip()):
            raise ValueError("Un motif est obligatoire en cas de rejet")
        return v
