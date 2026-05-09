from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import UUID

from app.db.database import get_db
from app.core.dependencies import require_admin, get_current_user_id
from app.services import assignment_service
from app.schemas.assignment import (
    AssignSuperviseurRequest,
    AssignAgentRequest,
    ForestSuperviseurResponse,
    AgentAssignmentResponse,
    AgentStatusItem,
    SuperviseurStatusItem,
    ParcelleAgentItem,
)

router = APIRouter(tags=["Affectations"])


# ══════════════════════════════════════════════════════════════
#  SUPERVISEUR ↔ FORÊT
# ══════════════════════════════════════════════════════════════

@router.put(
    "/api/forests/{forest_id}/superviseur",
    summary="Affecter un superviseur à une forêt",
)
async def assign_superviseur(
    forest_id: UUID,
    body:      AssignSuperviseurRequest,
    db:        AsyncSession = Depends(get_db),
    _:         UUID         = Depends(require_admin),
):
    """
    Affecte un superviseur à une forêt.
    Le superviseur doit être présent dans users_cache (compte activé).
    Si la forêt avait déjà un superviseur, il est remplacé.
    """
    return await assignment_service.assign_superviseur(
        db, forest_id, body.superviseur_id
    )


@router.delete(
    "/api/forests/{forest_id}/superviseur",
    summary="Retirer le superviseur d'une forêt",
)
async def remove_superviseur(
    forest_id: UUID,
    db:        AsyncSession = Depends(get_db),
    _:         UUID         = Depends(require_admin),
):
    return await assignment_service.remove_superviseur(db, forest_id)


@router.get(
    "/api/forests/{forest_id}/superviseur",
    summary="Voir le superviseur d'une forêt",
)
async def get_forest_superviseur(
    forest_id: UUID,
    db:        AsyncSession = Depends(get_db),
    _:         UUID         = Depends(get_current_user_id),
):
    return await assignment_service.get_forest_with_superviseur(db, forest_id)


# ══════════════════════════════════════════════════════════════
#  AGENT ↔ PARCELLE
# ══════════════════════════════════════════════════════════════

@router.put(
    "/api/parcelles/{parcelle_id}/agents",
    summary="Affecter un agent à une parcelle",
)
async def assign_agent(
    parcelle_id: UUID,
    body:        AssignAgentRequest,
    db:          AsyncSession = Depends(get_db),
    _:           UUID         = Depends(require_admin),
):
    """
    Affecte un agent à une parcelle.
    Si l'agent est déjà affecté ailleurs → retourne conflict=true avec les infos.
    L'UI doit alors proposer Modifier / Annuler.
    Pour confirmer le déplacement → appeler PUT /api/parcelles/{id}/agents/reassign.
    """
    return await assignment_service.assign_agent(db, parcelle_id, body.agent_id)


@router.put(
    "/api/parcelles/{parcelle_id}/agents/reassign",
    summary="Déplacer un agent vers cette parcelle (confirmer un conflit)",
)
async def reassign_agent(
    parcelle_id: UUID,
    body:        AssignAgentRequest,
    db:          AsyncSession = Depends(get_db),
    _:           UUID         = Depends(require_admin),
):
    """
    Déplace l'affectation d'un agent (confirmation UI après conflict=true).
    """
    return await assignment_service.reassign_agent(db, parcelle_id, body.agent_id)


@router.delete(
    "/api/parcelles/{parcelle_id}/agents/{agent_id}",
    summary="Retirer un agent d'une parcelle",
)
async def remove_agent(
    parcelle_id: UUID,
    agent_id:    UUID,
    db:          AsyncSession = Depends(get_db),
    _:           UUID         = Depends(require_admin),
):
    return await assignment_service.remove_agent(db, agent_id)


@router.get(
    "/api/parcelles/{parcelle_id}/agents",
    summary="Voir les agents d'une parcelle",
)
async def get_parcelle_agents(
    parcelle_id: UUID,
    db:          AsyncSession = Depends(get_db),
    _:           UUID         = Depends(get_current_user_id),
):
    return await assignment_service.get_parcelle_agents(db, parcelle_id)


# ══════════════════════════════════════════════════════════════
#  LISTES (pour les dropdowns UI)
# ══════════════════════════════════════════════════════════════

@router.get(
    "/api/assignments/agents",
    summary="Liste des agents avec leur statut d'affectation",
)
async def list_agents(
    db: AsyncSession = Depends(get_db),
    _:  UUID         = Depends(require_admin),
):
    """Retourne tous les agents actifs avec leur parcelle courante si affectés."""
    return await assignment_service.list_agents_with_status(db)


@router.get(
    "/api/assignments/superviseurs",
    summary="Liste des superviseurs avec leur statut d'affectation",
)
async def list_superviseurs(
    db: AsyncSession = Depends(get_db),
    _:  UUID         = Depends(require_admin),
):
    """Retourne tous les superviseurs actifs avec leurs forêts courantes si affectés."""
    return await assignment_service.list_superviseurs_with_status(db)