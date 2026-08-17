"""
Routes appelées par citizen_ms, jamais par un navigateur ni par Flutter.

IMPORTANT — ce préfixe /api/internal ne doit PAS être déclaré dans la gateway.
C'est ça, et seulement ça, qui protège ces routes : elles ne sont joignables
que par le nom de service Docker (http://auth_ms:8001), qui n'existe pas
depuis Internet. Si un jour j'ajoute cette route au nginx, n'importe qui peut
créer un compte citoyen sans dossier ni pièce justificative.

Conséquence assumée : pas de Depends(get_current_active_user) ici. L'appelant
est un service, pas un humain — il n'a pas de JWT à présenter.
"""

from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db
from app.schemas.internal import (
    InternalCitizenCreate,
    InternalCitizenCreated,
    InternalStatusUpdate,
)
from app.services import internal_service

router = APIRouter(prefix="/api/internal", tags=["Internal"])


# ── POST /api/internal/users ──────────────────────────────
@router.post(
    "/users",
    response_model=InternalCitizenCreated,
    status_code=status.HTTP_201_CREATED,
    summary="[interne] Créer un compte citoyen en attente de validation",
)
async def creer_compte_citoyen(
    data: InternalCitizenCreate,
    db:   AsyncSession = Depends(get_db),
):
    user = await internal_service.creer_compte_citoyen(data, db)
    return user


# ── PATCH /api/internal/users/{user_id}/status ────────────
@router.patch(
    "/users/{user_id}/status",
    response_model=InternalCitizenCreated,
    summary="[interne] Appliquer la décision de l'admin sur un compte citoyen",
)
async def changer_statut(
    user_id: UUID,
    data:    InternalStatusUpdate,
    db:      AsyncSession = Depends(get_db),
):
    user = await internal_service.changer_statut_citoyen(user_id, data.status, db)
    return user