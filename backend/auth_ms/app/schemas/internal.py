"""
Contrat d'échange entre citizen_ms et auth_ms.

Ces schémas ne sont JAMAIS exposés au public : ils décrivent uniquement ce que
citizen_ms envoie quand il commande la création d'un compte citoyen.
Je les mets dans un fichier à part (et pas dans schemas/user.py) pour que la
frontière interne / public reste visible d'un coup d'œil.
"""

import re
from typing import Optional
from uuid import UUID
from datetime import date
from pydantic import BaseModel, EmailStr, field_validator

from app.models.user import Specialite, UserStatus
from app.schemas.user import validate_strong_password


# ────────────────────────────────────────────────────────────
# ENTRÉE — ce que citizen_ms envoie
# ────────────────────────────────────────────────────────────
class InternalCitizenCreate(BaseModel):
    """
    Volontairement SANS champ `role`.

    Si j'acceptais le rôle depuis le corps de la requête, un bug dans
    citizen_ms — ou une future route mal protégée — pourrait créer un compte
    admin. Le rôle est imposé en dur dans le service : citoyen, toujours.
    Même logique pour `status` : c'est auth_ms qui décide, pas l'appelant.
    """

    full_name:  str
    email:      EmailStr
    cin:        str
    phone:      Optional[str] = None
    birth_date: Optional[date] = None

    # Le citoyen choisit son mot de passe lui-même à l'inscription.
    # C'est la grosse différence avec le personnel, qui le définit après coup
    # via le lien d'activation envoyé par email.
    password:   str

    specialite: Specialite

    @field_validator("cin")
    @classmethod
    def validate_cin(cls, v):
        if not re.match(r'^\d{8}$', v):
            raise ValueError("Le CIN doit contenir exactement 8 chiffres")
        return v

    @field_validator("password")
    @classmethod
    def validate_password(cls, v):
        # Même règle de robustesse que pour le personnel : je réutilise le
        # validateur existant au lieu de le recopier, sinon les deux règles
        # divergeront le jour où j'en modifie une.
        return validate_strong_password(v)


# ────────────────────────────────────────────────────────────
# SORTIE — ce que citizen_ms récupère
# ────────────────────────────────────────────────────────────
class InternalCitizenCreated(BaseModel):
    """
    Réponse minimale : citizen_ms n'a besoin que du user_id pour rattacher son
    profil. Je ne renvoie ni l'email ni le nom — ils sont déjà chez lui, les
    redonner l'encouragerait à les dupliquer en base.
    """

    user_id: UUID
    status:  UserStatus

    model_config = {"from_attributes": True}


# ────────────────────────────────────────────────────────────
# CHANGEMENT DE STATUT — décision de l'admin
# ────────────────────────────────────────────────────────────
class InternalStatusUpdate(BaseModel):
    """
    Envoyé quand l'admin tranche un dossier dans citizen_ms.
    Les transitions autorisées sont vérifiées côté service, pas ici : Pydantic
    valide la forme, le service valide la règle métier.
    """

    status: UserStatus