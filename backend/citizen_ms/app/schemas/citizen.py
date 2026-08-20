from datetime import date, datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_validator
from app.models.citizen import Specialite, StatutDossier, TypeDocument

import re


def validate_code_ruche(valeur: str, longueur: int, nom_champ: str) -> str:
    """
    Annexe 16 de l'arrêté du 31 décembre 2015 : le code apposé sur la façade
    de la ruche fait 8 chiffres, découpés en 4 (apiculteur) + 2 (délégation)
    + 2 (gouvernorat).

    La regex reproduit littéralement les CheckConstraint de la table
    profils_apiculteurs ('^[0-9]{4}$' et '^[0-9]{2}$'). Vérifier ici ce que
    PostgreSQL vérifiera de toute façon transforme un 500 après création du
    compte en 400 que le citoyen comprend.

    fullmatch et pas isdigit() : isdigit() accepte les chiffres arabes (٤٢)
    et les exposants (²), que [0-9] refuse. Les deux règles doivent coïncider
    exactement, sinon le 400 laisse passer ce que la base rejettera.
    """
    v = valeur.strip()

    if not re.fullmatch(rf"[0-9]{{{longueur}}}", v):
        raise ValueError(f"{nom_champ} : exactement {longueur} chiffres")

    return v
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


# ── Entrée : rucher déclaré à l'inscription ───────────────

class RucherIn(BaseModel):
    """
    Un rucher envoyé en JSON dans le champ multipart `ruchers`.

    Ce schéma existe pour que les erreurs de saisie soient refusées à l'étape
    0 de l'inscription. Sans lui, le service fait `Rucher(**r)` avec le
    dictionnaire brut du client : une clé inconnue lève un TypeError, un
    champ manquant viole un NOT NULL. Dans les deux cas l'échec arrive à
    l'étape 4, donc APRÈS la création du compte chez auth_ms — une faute de
    frappe déclencherait une compensation.

    Chaque contrainte réplique une colonne de la table `ruchers` :
    max_length=255 pour String(255), ge=0 parce qu'un nombre de colonies
    négatif n'existe pas, les bornes lat/lng parce qu'une coordonnée hors
    plage ne pourra jamais être croisée avec les parcelles de forest_ms.
    """

    numero_rucher:   int = Field(..., ge=1)      # « Rucher n° 1 » de l'annexe 18
    emplacement:     str = Field(..., min_length=1, max_length=255)
    latitude:        Optional[float] = Field(None, ge=-90,  le=90)
    longitude:       Optional[float] = Field(None, ge=-180, le=180)
    nombre_colonies: int = Field(..., ge=0)

    # Une clé inutile signale presque toujours une faute de frappe côté
    # client. La refuser avec un message clair vaut mieux que l'ignorer en
    # silence, ce que Pydantic ferait par défaut.
    model_config = {"extra": "forbid"}