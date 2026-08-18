"""
Cœur de citizen_ms : l'inscription et la décision de l'admin.

ORDRE DES OPÉRATIONS À L'INSCRIPTION — c'est le point délicat du service.

    1. Lire et valider les fichiers EN MÉMOIRE (type, taille, présence)
    2. Appeler auth_ms pour créer le compte  →  user_id
    3. Écrire les fichiers sur disque
    4. Enregistrer profil + pièces + sous-profil en base, commit

L'appel à auth_ms passe AVANT l'écriture disque, volontairement. Le cas
d'échec le plus fréquent, de très loin, c'est « CIN ou email déjà utilisé ».
En le détectant à l'étape 2, il n'y a strictement rien à nettoyer : aucun
fichier écrit, aucune ligne insérée.

Si l'étape 4 échoue malgré tout — rare, c'est notre base locale — on
compense : suppression des fichiers et passage du compte en 'rejete' chez
auth_ms. Il n'existe pas de transaction distribuée entre deux bases
séparées ; c'est le principe du Saga avec compensation.
"""

import logging
import shutil
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
from uuid import UUID

from fastapi import HTTPException, UploadFile
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core import auth_client
from app.core.auth_client import AuthIndisponible
from app.core.config import settings
from app.models.citizen import (
    PieceJointe, ProfilApiculteur, ProfilChasseur, ProfilCitoyen,
    Rucher, Specialite, StatutDossier, TypeDocument,
)

logger = logging.getLogger(__name__)

UPLOAD_DIR = Path("uploads/citoyens")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp", "application/pdf"}
MAX_SIZE_MB   = 10

# Documents exigés par spécialité. Les permis d'arme s'ajoutent seulement si
# le chasseur déclare en posséder une — voir _documents_requis().
DOCS_COMMUNS = [TypeDocument.cin_recto, TypeDocument.cin_verso]


def _documents_requis(specialite: Specialite, possede_arme: bool) -> list[TypeDocument]:
    if specialite == Specialite.chasseur:
        requis = DOCS_COMMUNS + [TypeDocument.permis_chasse]
        if possede_arme:
            # Détention ET port/transport : une arme détenue sans droit de
            # transport ne peut pas servir à la chasse.
            requis += [TypeDocument.permis_detention,
                       TypeDocument.permis_port_transport]
        return requis

    if specialite == Specialite.apiculteur:
        # Pas de « permis d'apiculteur » en droit tunisien : le certificat
        # collectif d'identification des colonies (annexe 19) fait foi.
        return DOCS_COMMUNS + [TypeDocument.certificat_colonies]

    # Campeur : aucune pièce spécifique exigée par la loi, seulement l'identité.
    return list(DOCS_COMMUNS)


def _url(chemin: Optional[str]) -> Optional[str]:
    if not chemin:
        return None
    return f"{settings.BASE_URL.rstrip('/')}/uploads/{chemin}"


# ── Étape 1 : lecture et validation en mémoire ────────────

async def _lire_et_valider(
    fichiers: dict[TypeDocument, Optional[UploadFile]],
    requis:   list[TypeDocument],
) -> dict[TypeDocument, tuple[bytes, str, str]]:
    """
    Renvoie {type_document: (contenu, mime_type, extension)}.

    Rien n'est écrit sur disque à ce stade : si une pièce est absente ou
    invalide, on refuse avant d'avoir touché au système de fichiers.
    """
    contenus: dict[TypeDocument, tuple[bytes, str, str]] = {}

    for type_doc in requis:
        fichier = fichiers.get(type_doc)
        if not fichier or not fichier.filename:
            raise HTTPException(
                status_code=400,
                detail=f"Document manquant : {type_doc.value}",
            )

        if fichier.content_type not in ALLOWED_TYPES:
            raise HTTPException(
                status_code=400,
                detail=f"{type_doc.value} : format non supporté. "
                       f"Utilisez JPEG, PNG, WebP ou PDF.",
            )

        contenu = await fichier.read()
        if len(contenu) > MAX_SIZE_MB * 1024 * 1024:
            raise HTTPException(
                status_code=400,
                detail=f"{type_doc.value} : fichier trop lourd (max {MAX_SIZE_MB} Mo)",
            )
        if len(contenu) == 0:
            raise HTTPException(
                status_code=400,
                detail=f"{type_doc.value} : fichier vide",
            )

        ext = (fichier.filename.rsplit(".", 1)[-1].lower()
               if "." in fichier.filename else "bin")
        contenus[type_doc] = (contenu, fichier.content_type, ext)

    return contenus


# ── Étape 3 : écriture disque ─────────────────────────────

def _ecrire_fichiers(
    user_id:  UUID,
    contenus: dict[TypeDocument, tuple[bytes, str, str]],
) -> dict[TypeDocument, str]:
    """
    Un dossier par citoyen, nommé par son user_id. Nom de fichier = type de
    document : pas de collision possible, et le contenu est lisible au premier
    coup d'œil quand on inspecte le volume.
    """
    dossier = UPLOAD_DIR / str(user_id)
    dossier.mkdir(parents=True, exist_ok=True)

    chemins = {}
    for type_doc, (contenu, _mime, ext) in contenus.items():
        nom = f"{type_doc.value}.{ext}"
        (dossier / nom).write_bytes(contenu)
        chemins[type_doc] = f"citoyens/{user_id}/{nom}"

    return chemins


def _supprimer_fichiers(user_id: UUID) -> None:
    """Nettoyage en cas d'échec après écriture. Ne lève jamais."""
    try:
        shutil.rmtree(UPLOAD_DIR / str(user_id), ignore_errors=True)
    except Exception as e:
        logger.warning("[CITIZEN MS] Nettoyage fichiers échoué : %s", e)


# ── INSCRIPTION ───────────────────────────────────────────

async def inscrire_citoyen(
    db:            AsyncSession,
    compte:        dict,                     # champs destinés à auth_ms
    profil_data:   dict,                     # adresse, téléphone
    specialite:    Specialite,
    fichiers:      dict[TypeDocument, Optional[UploadFile]],
    chasseur_data: Optional[dict] = None,
    apiculteur_data: Optional[dict] = None,
    ruchers_data:  Optional[list[dict]] = None,
) -> ProfilCitoyen:

    possede_arme = bool(chasseur_data and chasseur_data.get("possede_arme"))
    requis = _documents_requis(specialite, possede_arme)

    # ── 1. Validation en mémoire ──────────────────────────
    contenus = await _lire_et_valider(fichiers, requis)

    # ── 2. Création du compte chez auth_ms ────────────────
    # Rien n'a encore été écrit : un 409 ici ne laisse aucune trace.
    try:
        user_id = await auth_client.creer_compte({
            **compte,
            "specialite": specialite.value,
        })
    except AuthIndisponible:
        raise HTTPException(
            status_code=503,
            detail="Service d'authentification indisponible, réessayez dans un instant",
        )

    # ── 3. Écriture des fichiers ──────────────────────────
    try:
        chemins = _ecrire_fichiers(user_id, contenus)
    except OSError as e:
        logger.error("[CITIZEN MS] Écriture disque échouée : %s", e)
        await _compenser(user_id)
        raise HTTPException(status_code=500,
                            detail="Impossible d'enregistrer les documents")

    # ── 4. Enregistrement en base ─────────────────────────
    try:
        profil = ProfilCitoyen(
            user_id        = user_id,
            specialite     = specialite,
            statut_dossier = StatutDossier.en_attente,
            **profil_data,
        )
        db.add(profil)
        await db.flush()          # obtient profil_id sans committer

        for type_doc, chemin in chemins.items():
            contenu, mime, _ext = contenus[type_doc]
            db.add(PieceJointe(
                profil_id     = profil.profil_id,
                type_document = type_doc,
                chemin        = chemin,
                mime_type     = mime,
                taille_octets = len(contenu),
            ))

        if specialite == Specialite.chasseur:
            db.add(ProfilChasseur(profil_id=profil.profil_id, **chasseur_data))

        elif specialite == Specialite.apiculteur:
            db.add(ProfilApiculteur(profil_id=profil.profil_id, **apiculteur_data))
            for r in (ruchers_data or []):
                db.add(Rucher(profil_id=profil.profil_id, **r))

        await db.commit()

    except Exception as e:
        # Cas rare : notre propre base a refusé l'écriture. Le compte existe
        # déjà chez auth_ms, il faut le neutraliser pour ne pas laisser un
        # compte fantôme sans dossier.
        logger.critical("[CITIZEN MS] Échec enregistrement local : %s", e)
        await db.rollback()
        _supprimer_fichiers(user_id)
        await _compenser(user_id)
        raise HTTPException(status_code=500,
                            detail="Échec de l'inscription, veuillez réessayer")

    return profil


async def _compenser(user_id: UUID) -> None:
    """
    Neutralise un compte créé chez auth_ms alors que notre côté a échoué.

    Si cet appel échoue aussi, on ne peut rien faire de plus automatiquement :
    on journalise en CRITICAL pour que l'incohérence soit retrouvable à la
    main. C'est la limite honnête d'une architecture sans transaction
    distribuée.
    """
    try:
        await auth_client.changer_statut(user_id, "rejete")
    except Exception as e:
        logger.critical(
            "[CITIZEN MS] COMPTE ORPHELIN user_id=%s — compensation échouée : %s",
            user_id, e,
        )


# ── DÉCISION DE L'ADMIN ───────────────────────────────────

async def decider_dossier(
    db:          AsyncSession,
    profil_id:   UUID,
    approuve:    bool,
    motif_rejet: Optional[str],
    admin_id:    UUID,
) -> ProfilCitoyen:
    """
    L'ordre compte ici aussi : on appelle auth_ms AVANT de committer.

    Si l'activation du compte échoue, le rollback annule notre mise à jour et
    le dossier reste en_attente. L'admin retentera. L'inverse — committer
    puis appeler — laisserait un dossier « approuvé » chez nous et un compte
    toujours bloqué chez auth_ms.
    """
    profil = await _charger_profil(db, profil_id)

    if profil.statut_dossier != StatutDossier.en_attente:
        raise HTTPException(
            status_code=409,
            detail=f"Dossier déjà traité ({profil.statut_dossier.value})",
        )

    profil.statut_dossier = StatutDossier.approuve if approuve else StatutDossier.rejete
    profil.motif_rejet    = None if approuve else motif_rejet
    profil.traite_le      = datetime.now(timezone.utc)
    profil.traite_par     = admin_id

    try:
        await auth_client.changer_statut(
            profil.user_id,
            "active" if approuve else "rejete",
        )
    except AuthIndisponible:
        await db.rollback()
        raise HTTPException(
            status_code=503,
            detail="Service d'authentification indisponible, décision non enregistrée",
        )
    except HTTPException:
        # auth_ms a répondu mais a refusé la transition (compte déjà rejeté
        # ou déjà actif). Notre modification ne doit pas survivre : on annule
        # ici plutôt que de compter sur le rollback de get_db.
        await db.rollback()
        raise

    await db.commit()
    return profil


# ── LECTURE ───────────────────────────────────────────────

async def _charger_profil(db: AsyncSession, profil_id: UUID) -> ProfilCitoyen:
    result = await db.execute(
        select(ProfilCitoyen)
        .where(ProfilCitoyen.profil_id == profil_id)
        .options(
            selectinload(ProfilCitoyen.pieces),
            selectinload(ProfilCitoyen.chasseur),
            selectinload(ProfilCitoyen.apiculteur).selectinload(ProfilApiculteur.ruchers),
        )
    )
    profil = result.scalar_one_or_none()
    if not profil:
        raise HTTPException(status_code=404, detail="Dossier introuvable")
    return profil


async def lister_dossiers(
    db:     AsyncSession,
    statut: Optional[StatutDossier] = None,
) -> list[ProfilCitoyen]:
    query = (
        select(ProfilCitoyen)
        .options(
            selectinload(ProfilCitoyen.pieces),
            selectinload(ProfilCitoyen.chasseur),
            selectinload(ProfilCitoyen.apiculteur).selectinload(ProfilApiculteur.ruchers),
        )
        .order_by(ProfilCitoyen.soumis_le.desc())
    )
    if statut:
        query = query.where(ProfilCitoyen.statut_dossier == statut)

    result = await db.execute(query)
    return list(result.scalars().all())


async def get_dossier(db: AsyncSession, profil_id: UUID) -> ProfilCitoyen:
    return await _charger_profil(db, profil_id)


async def get_mon_profil(db: AsyncSession, user_id: UUID) -> ProfilCitoyen:
    result = await db.execute(
        select(ProfilCitoyen)
        .where(ProfilCitoyen.user_id == user_id)
        .options(
            selectinload(ProfilCitoyen.pieces),
            selectinload(ProfilCitoyen.chasseur),
            selectinload(ProfilCitoyen.apiculteur).selectinload(ProfilApiculteur.ruchers),
        )
    )
    profil = result.scalar_one_or_none()
    if not profil:
        raise HTTPException(status_code=404, detail="Aucun dossier pour ce compte")
    return profil


# ── ALERTES DE COHÉRENCE ──────────────────────────────────

def calculer_alertes(profil: ProfilCitoyen) -> list[str]:
    """
    Signale à l'admin ce qui semble incohérent. Ne bloque JAMAIS : la
    décision reste humaine, le système ne fait que présenter l'information.
    """
    alertes: list[str] = []

    if profil.apiculteur:
        # Annexe 16 : « Il est tenu compte du domicile de l'apiculteur pour
        # fixer le gouvernorat et la délégation. » Le code de la ruche doit
        # donc concorder avec l'adresse déclarée.
        api = profil.apiculteur
        total_ruchers = sum(r.nombre_colonies for r in api.ruchers)
        if api.ruchers and total_ruchers != api.nombre_colonies_declare:
            alertes.append(
                f"Nombre de colonies incohérent : {api.nombre_colonies_declare} "
                f"déclarées, {total_ruchers} réparties dans les ruchers"
            )

    if profil.chasseur:
        c = profil.chasseur
        if c.date_expiration and c.date_expiration < datetime.now(timezone.utc).date():
            alertes.append(
                f"Permis de chasse expiré le {c.date_expiration.isoformat()}"
            )

    return alertes


def serialiser_dossier(profil: ProfilCitoyen) -> dict:
    """Ajoute les URL des pièces et les alertes au dossier renvoyé."""
    return {
        "profil_id":      profil.profil_id,
        "user_id":        profil.user_id,
        "specialite":     profil.specialite,
        "statut_dossier": profil.statut_dossier,
        "gouvernorat":    profil.gouvernorat,
        "delegation":     profil.delegation,
        "secteur":        profil.secteur,
        "adresse":        profil.adresse,
        "telephone":      profil.telephone,
        "motif_rejet":    profil.motif_rejet,
        "soumis_le":      profil.soumis_le,
        "traite_le":      profil.traite_le,
        "pieces": [
            {
                "piece_id":      p.piece_id,
                "type_document": p.type_document,
                "url":           _url(p.chemin),
                "mime_type":     p.mime_type,
                "taille_octets": p.taille_octets,
                "televerse_le":  p.televerse_le,
            }
            for p in profil.pieces
        ],
        "chasseur":   profil.chasseur,
        "apiculteur": profil.apiculteur,
        "alertes":    calculer_alertes(profil),
    }
