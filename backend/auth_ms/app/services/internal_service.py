"""
Logique appelée par citizen_ms.

Rappel de la répartition : citizen_ms COMMANDE la création du compte, auth_ms
l'EXÉCUTE. Tout le hachage, l'unicité et les règles de statut restent ici —
citizen_ms n'en connaît rien, il ne voit que le user_id qu'on lui renvoie.
"""

from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import select, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.user import RefreshToken, User, UserRole, UserStatus
from app.schemas.internal import InternalCitizenCreate


# ────────────────────────────────────────────────────────────
# CRÉATION D'UN COMPTE CITOYEN
# ────────────────────────────────────────────────────────────
async def creer_compte_citoyen(
    data: InternalCitizenCreate,
    db:   AsyncSession,
) -> User:
    """
    Appelé par citizen_ms APRÈS qu'il ait stocké les pièces jointes sur disque.

    L'ordre est important : si cette fonction lève une erreur, citizen_ms doit
    supprimer les fichiers qu'il vient d'écrire. C'est pour ça que je renvoie
    un 409 explicite sur les doublons — citizen_ms doit pouvoir distinguer
    « le CIN existe déjà » (le citoyen doit corriger) de « auth_ms est tombé »
    (il faut réessayer plus tard).
    """

    # ── Unicité CIN / email ───────────────────────────────
    # C'est auth_ms qui porte la contrainte unique, donc c'est ici qu'on
    # vérifie. citizen_ms ne peut PAS faire ce contrôle : il n'a pas la table.
    result = await db.execute(
        select(User).where(or_(User.cin == data.cin, User.email == data.email))
    )
    existant = result.scalar_one_or_none()

    if existant:
        # Message précis : le citoyen doit savoir quel champ corriger.
        # Pas de risque de fuite d'information ici — contrairement au login,
        # l'appelant est un service de confiance, pas un visiteur anonyme.
        champ = "CIN" if existant.cin == data.cin else "email"
        raise HTTPException(
            status_code=409,
            detail=f"Ce {champ} est déjà utilisé",
        )

    # ── Création ──────────────────────────────────────────
    user = User(
        full_name     = data.full_name,
        email         = data.email,
        cin           = data.cin,
        phone         = data.phone,
        birth_date    = data.birth_date,
        specialite    = data.specialite,

        # Imposé en dur : jamais lu depuis la requête.
        role          = UserRole.citoyen,

        # Le mot de passe est haché tout de suite, contrairement au personnel
        # où password_hash reste NULL jusqu'au clic sur le lien d'activation.
        password_hash = hash_password(data.password),

        # Le compte existe mais la connexion est refusée : c'est le statut qui
        # bloque, pas l'absence de mot de passe.
        status        = UserStatus.en_attente,
    )

    db.add(user)
    await db.commit()
    await db.refresh(user)

    return user


# ────────────────────────────────────────────────────────────
# CHANGEMENT DE STATUT — décision de l'admin
# ────────────────────────────────────────────────────────────

# Transitions autorisées. Sans cette table, une requête mal formée pourrait
# faire passer un dossier rejeté directement en actif sans repasser par
# l'admin. Je préfère refuser explicitement que de subir un état incohérent.
TRANSITIONS_AUTORISEES: dict[UserStatus, set[UserStatus]] = {
    UserStatus.en_attente: {UserStatus.active, UserStatus.rejete},
    UserStatus.active:     {UserStatus.banned, UserStatus.inactive},
    UserStatus.banned:     {UserStatus.active},
    UserStatus.inactive:   {UserStatus.active},
    UserStatus.rejete:     set(),   # terminal : il faut refaire une inscription
}


async def changer_statut_citoyen(
    user_id:        UUID,
    nouveau_statut: UserStatus,
    db:             AsyncSession,
) -> User:
    """
    Appelé quand l'admin approuve ou refuse un dossier dans citizen_ms.

    citizen_ms met d'abord à jour SON statut_dossier, puis appelle cette
    fonction. Si l'appel échoue, il doit annuler sa propre mise à jour :
    sinon on se retrouve avec un dossier « approuvé » côté citizen_ms et un
    compte toujours bloqué côté auth_ms.
    """

    result = await db.execute(select(User).where(User.user_id == user_id))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    # Cette route ne doit jamais servir à débloquer un compte du personnel :
    # eux passent par le flux admin classique.
    if user.role != UserRole.citoyen:
        raise HTTPException(
            status_code=403,
            detail="Cette route ne gère que les comptes citoyens",
        )

    if nouveau_statut not in TRANSITIONS_AUTORISEES[user.status]:
        raise HTTPException(
            status_code=409,
            detail=f"Transition {user.status.value} → {nouveau_statut.value} interdite",
        )

    user.status = nouveau_statut

    # Si le compte est bloqué, ses refresh tokens doivent mourir avec lui.
    # Sinon un citoyen banni continue de renouveler son access token et reste
    # connecté — le refresh ne revérifie le statut qu'au moment de l'appel,
    # mais autant couper la source tout de suite.
    if nouveau_statut in (UserStatus.banned, UserStatus.rejete, UserStatus.inactive):
        tokens = await db.execute(
            select(RefreshToken).where(
                RefreshToken.user_id == user.user_id,
                RefreshToken.revoked.is_(False),
            )
        )
        for t in tokens.scalars().all():
            t.revoked = True

    await db.commit()
    await db.refresh(user)

    return user