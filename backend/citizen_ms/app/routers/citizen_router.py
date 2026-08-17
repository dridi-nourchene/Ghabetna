"""
Routes de citizen_ms.

L'inscription est en multipart/form-data : le formulaire porte des champs
texte ET des fichiers dans le même envoi. C'est un seul geste de
l'utilisateur, donc un seul appel — la découper en deux exposerait à des
dossiers à moitié créés.

PIÈGE MULTIPART — corrigé plus bas avec DateOpt / IntOpt / StrOpt :
multipart n'a pas de notion de "champ absent". Un champ laissé vide arrive
comme la chaîne "" et non comme null. Pydantic tente alors de convertir ""
en date ou en int, échoue, et FastAPI renvoie un 422 AVANT que le service ne
s'exécute — donc sans message métier, ce qui rend le bug incompréhensible.
Flutter produira exactement le même comportement que Swagger.
"""

import json
from datetime import date
from typing import Annotated, Optional
from uuid import UUID

from fastapi import (
    APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status
)
from pydantic import BeforeValidator
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user_id, require_admin
from app.db.database import get_db
from app.models.citizen import Specialite, StatutDossier, TypeDocument
from app.schemas.citizen import DecisionIn, DossierOut, InscriptionOut
from app.services import citizen_service

router = APIRouter(prefix="/api/citoyens", tags=["Citoyens"])


# ── Types tolérants au champ vide ─────────────────────────

def _vide_en_none(v):
    """ "" → None. Appliqué AVANT la conversion de type, d'où BeforeValidator."""
    if isinstance(v, str) and v.strip() == "":
        return None
    return v


DateOpt = Annotated[Optional[date], BeforeValidator(_vide_en_none)]
IntOpt  = Annotated[Optional[int],  BeforeValidator(_vide_en_none)]
StrOpt  = Annotated[Optional[str],  BeforeValidator(_vide_en_none)]


def _fichier_ou_none(f: Optional[UploadFile]) -> Optional[UploadFile]:
    """
    Swagger envoie parfois une partie de fichier vide quand aucun fichier
    n'est sélectionné : un UploadFile existe mais son filename est "".
    On le ramène à None pour que _lire_et_valider le traite comme absent.
    """
    if f is None or not f.filename:
        return None
    return f


# ── POST /api/citoyens/inscription ────────────────────────

@router.post(
    "/inscription",
    response_model=InscriptionOut,
    status_code=status.HTTP_201_CREATED,
    summary="Inscription d'un citoyen — publique, sans JWT",
)
async def inscription(
    # ── Compte (transmis à auth_ms, jamais stocké ici) ────
    full_name:  str = Form(...),
    email:      str = Form(...),
    cin:        str = Form(..., min_length=8, max_length=8),
    password:   str = Form(...),
    phone:      StrOpt  = Form(None),
    birth_date: DateOpt = Form(None),

    # ── Profil citoyen ────────────────────────────────────
    specialite:  Specialite = Form(...),
    gouvernorat: str        = Form(...),
    delegation:  str        = Form(...),
    secteur:     StrOpt     = Form(None),
    adresse:     StrOpt     = Form(None),

    # ── Chasseur ──────────────────────────────────────────
    numero_permis_chasse:         StrOpt  = Form(None),
    date_delivrance:              DateOpt = Form(None),
    date_expiration:              DateOpt = Form(None),
    gouvernorat_delivrance:       StrOpt  = Form(None),
    possede_arme:                 bool    = Form(False),
    numero_permis_detention:      StrOpt  = Form(None),
    numero_permis_port_transport: StrOpt  = Form(None),

    # ── Apiculteur ────────────────────────────────────────
    code_apiculteur:         StrOpt  = Form(None),
    code_delegation:         StrOpt  = Form(None),
    code_gouvernorat:        StrOpt  = Form(None),
    nombre_colonies_declare: IntOpt  = Form(None),
    date_certificat:         DateOpt = Form(None),
    # Liste de ruchers en JSON : multipart ne transporte pas de tableau
    # d'objets. Flutter enverra une chaîne JSON dans ce champ.
    ruchers:                 StrOpt  = Form(None),

    # ── Pièces jointes ────────────────────────────────────
    cin_recto:             UploadFile           = File(...),
    cin_verso:             UploadFile           = File(...),
    permis_chasse:         Optional[UploadFile] = File(None),
    permis_detention:      Optional[UploadFile] = File(None),
    permis_port_transport: Optional[UploadFile] = File(None),
    certificat_colonies:   Optional[UploadFile] = File(None),

    db: AsyncSession = Depends(get_db),
):
    # ── Assemblage des données spécifiques ────────────────
    chasseur_data   = None
    apiculteur_data = None
    ruchers_data    = None

    if specialite == Specialite.chasseur:
        if not numero_permis_chasse:
            raise HTTPException(400, "Le numéro de permis de chasse est obligatoire")

        if possede_arme and not (numero_permis_detention and numero_permis_port_transport):
            raise HTTPException(
                400,
                "Les permis de détention et de port/transport sont obligatoires "
                "pour un chasseur possédant une arme",
            )

        chasseur_data = {
            "numero_permis_chasse":         numero_permis_chasse,
            "date_delivrance":              date_delivrance,
            "date_expiration":              date_expiration,
            "gouvernorat_delivrance":       gouvernorat_delivrance,
            "possede_arme":                 possede_arme,
            "numero_permis_detention":      numero_permis_detention,
            "numero_permis_port_transport": numero_permis_port_transport,
        }

    elif specialite == Specialite.apiculteur:
        if not (code_apiculteur and code_delegation and code_gouvernorat):
            raise HTTPException(400, "Le code d'identification des ruches est obligatoire")

        apiculteur_data = {
            "code_apiculteur":         code_apiculteur,
            "code_delegation":         code_delegation,
            "code_gouvernorat":        code_gouvernorat,
            "nombre_colonies_declare": nombre_colonies_declare or 0,
            "date_certificat":         date_certificat,
        }

        if ruchers:
            try:
                ruchers_data = json.loads(ruchers)
            except json.JSONDecodeError:
                raise HTTPException(400, "Le champ ruchers doit être un JSON valide")

    # ── Appel du service ──────────────────────────────────
    profil = await citizen_service.inscrire_citoyen(
        db = db,
        compte = {
            "full_name":  full_name,
            "email":      email,
            "cin":        cin,
            "phone":      phone,
            "birth_date": birth_date.isoformat() if birth_date else None,
            "password":   password,
        },
        profil_data = {
            "gouvernorat": gouvernorat,
            "delegation":  delegation,
            "secteur":     secteur,
            "adresse":     adresse,
            "telephone":   phone,
        },
        specialite = specialite,
        fichiers = {
            TypeDocument.cin_recto:             _fichier_ou_none(cin_recto),
            TypeDocument.cin_verso:             _fichier_ou_none(cin_verso),
            TypeDocument.permis_chasse:         _fichier_ou_none(permis_chasse),
            TypeDocument.permis_detention:      _fichier_ou_none(permis_detention),
            TypeDocument.permis_port_transport: _fichier_ou_none(permis_port_transport),
            TypeDocument.certificat_colonies:   _fichier_ou_none(certificat_colonies),
        },
        chasseur_data   = chasseur_data,
        apiculteur_data = apiculteur_data,
        ruchers_data    = ruchers_data,
    )

    return InscriptionOut(
        profil_id      = profil.profil_id,
        user_id        = profil.user_id,
        statut_dossier = profil.statut_dossier,
        message        = "Dossier soumis. Vous serez informé après examen par l'administration.",
    )


# ── GET /api/citoyens/mon-dossier ─────────────────────────

@router.get(
    "/mon-dossier",
    response_model=DossierOut,
    summary="Le citoyen consulte l'état de son propre dossier",
)
async def mon_dossier(
    db:      AsyncSession = Depends(get_db),
    user_id: UUID         = Depends(get_current_user_id),
):
    profil = await citizen_service.get_mon_profil(db, user_id)
    return citizen_service.serialiser_dossier(profil)


# ── GET /api/citoyens/dossiers (admin) ────────────────────

@router.get(
    "/dossiers",
    response_model=list[DossierOut],
    summary="File des dossiers à traiter (admin)",
)
async def lister_dossiers(
    statut:   Optional[StatutDossier] = Query(None),
    db:       AsyncSession = Depends(get_db),
    admin_id: UUID         = Depends(require_admin),
):
    profils = await citizen_service.lister_dossiers(db, statut)
    return [citizen_service.serialiser_dossier(p) for p in profils]


# ── GET /api/citoyens/dossiers/{profil_id} (admin) ────────

@router.get(
    "/dossiers/{profil_id}",
    response_model=DossierOut,
    summary="Détail d'un dossier avec ses pièces (admin)",
)
async def detail_dossier(
    profil_id: UUID,
    db:        AsyncSession = Depends(get_db),
    admin_id:  UUID         = Depends(require_admin),
):
    profil = await citizen_service.get_dossier(db, profil_id)
    return citizen_service.serialiser_dossier(profil)


# ── PATCH /api/citoyens/dossiers/{profil_id}/decision ─────

@router.patch(
    "/dossiers/{profil_id}/decision",
    response_model=DossierOut,
    summary="Approuver ou rejeter un dossier (admin)",
)
async def decider(
    profil_id: UUID,
    data:      DecisionIn,
    db:        AsyncSession = Depends(get_db),
    admin_id:  UUID         = Depends(require_admin),
):
    profil = await citizen_service.decider_dossier(
        db          = db,
        profil_id   = profil_id,
        approuve    = data.approuve,
        motif_rejet = data.motif_rejet,
        admin_id    = admin_id,
    )
    return citizen_service.serialiser_dossier(profil)