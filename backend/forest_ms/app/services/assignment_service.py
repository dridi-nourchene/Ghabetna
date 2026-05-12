import uuid
from uuid import UUID
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.forest import Forest
from app.models.parcelle import Parcelle
from app.models.user_cahe import UserCache
from app.models.agent_parcelle import AgentParcelle


# ────────────────────────────────────────────────────────────
# HELPERS
# ────────────────────────────────────────────────────────────

async def _get_user_from_cache(
    db: AsyncSession,
    user_id: UUID,
    expected_role: str,
) -> UserCache:
    """Vérifie qu'un utilisateur existe dans le cache local et a le bon rôle."""
    result = await db.execute(
        select(UserCache).where(UserCache.user_id == user_id)
    )
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(
            status_code=404,
            detail=f"Utilisateur introuvable dans le cache local — "
                   f"l'utilisateur doit d'abord activer son compte",
        )
    if user.role != expected_role:
        raise HTTPException(
            status_code=400,
            detail=f"Rôle incorrect : attendu '{expected_role}', trouvé '{user.role}'",
        )
    if not user.is_active:
        raise HTTPException(
            status_code=400,
            detail="Utilisateur inactif",
        )
    return user


async def _get_forest(db: AsyncSession, forest_id: UUID) -> Forest:
    result = await db.execute(select(Forest).where(Forest.id == forest_id))
    forest = result.scalar_one_or_none()
    if not forest:
        raise HTTPException(status_code=404, detail="Forêt introuvable")
    return forest


async def _get_parcelle(db: AsyncSession, parcelle_id: UUID) -> Parcelle:
    result = await db.execute(select(Parcelle).where(Parcelle.id == parcelle_id))
    parcelle = result.scalar_one_or_none()
    if not parcelle:
        raise HTTPException(status_code=404, detail="Parcelle introuvable")
    return parcelle


# ────────────────────────────────────────────────────────────
# SUPERVISEUR ↔ FORÊT
# ────────────────────────────────────────────────────────────

async def assign_superviseur(
    db:              AsyncSession,
    forest_id:       UUID,
    superviseur_id:  UUID,
) -> dict:
    """Affecte un superviseur à une forêt (remplace l'ancien si existant)."""
    # Vérifier superviseur dans le cache
    await _get_user_from_cache(db, superviseur_id, "supervisor")

    # Vérifier forêt
    forest = await _get_forest(db, forest_id)

    # Affecter (upsert simple — on remplace)
    forest.superviseur_id = superviseur_id
    await db.commit()

    return await get_forest_with_superviseur(db, forest_id)


async def remove_superviseur(db: AsyncSession, forest_id: UUID) -> dict:
    """Retire le superviseur d'une forêt."""
    forest = await _get_forest(db, forest_id)
    forest.superviseur_id = None
    await db.commit()
    return {"message": "Superviseur retiré avec succès"}


async def get_forest_with_superviseur(db: AsyncSession, forest_id: UUID) -> dict:
    """Retourne la forêt avec les infos du superviseur (jointure locale)."""

    result = await db.execute(
        select(Forest).where(Forest.id == forest_id)
    )
    forest = result.scalar_one_or_none()
    if not forest:
        raise HTTPException(status_code=404, detail="Forêt introuvable")

    # Jointure locale vers users_cache
    superviseur_info = None
    if forest.superviseur_id:
        sup_result = await db.execute(
            select(UserCache).where(UserCache.user_id == forest.superviseur_id)
        )
        sup = sup_result.scalar_one_or_none()
        if sup:
            superviseur_info = {
                "user_id": str(sup.user_id),
                "nom":     sup.nom,
                "email":   sup.email,
            }

    return {
        "forest_id":     str(forest.id),
        "forest_name":   forest.name,
        "superviseur_id": str(forest.superviseur_id) if forest.superviseur_id else None,
        "superviseur":   superviseur_info,
    }


# ────────────────────────────────────────────────────────────
# AGENT ↔ PARCELLE
# ────────────────────────────────────────────────────────────

async def assign_agent(
    db:          AsyncSession,
    parcelle_id: UUID,
    agent_id:    UUID,
) -> dict:
    # Vérifier agent + parcelle — on récupère les objets AVANT le commit
    agent    = await _get_user_from_cache(db, agent_id, "agent")
    parcelle = await _get_parcelle(db, parcelle_id)

    # Vérifier si déjà affecté
    existing = await db.execute(
        select(AgentParcelle).where(AgentParcelle.agent_id == agent_id)
    )
    existing_assignment = existing.scalar_one_or_none()

    if existing_assignment:
        old_parcelle = await _get_parcelle(db, existing_assignment.parcelle_id)
        return {
            "conflict":              True,
            "agent_id":              str(agent_id),
            "current_parcelle_id":   str(existing_assignment.parcelle_id),
            "current_parcelle_name": old_parcelle.name,
            "message": f"L'agent est déjà affecté à la parcelle « {old_parcelle.name} »",
        }

    # Collecter les données de réponse AVANT le commit
    agent_nom   = agent.nom
    agent_email = agent.email
    agent_phone = agent.phone or ""
    parc_name   = parcelle.name

    # Commit
    db.add(AgentParcelle(agent_id=agent_id, parcelle_id=parcelle_id))
    await db.commit()

    # Retourner avec les données déjà collectées — pas de query après commit
    return {
        "conflict":      False,
        "agent_id":      str(agent_id),
        "agent_nom":     agent_nom,
        "agent_email":   agent_email,
        "agent_phone":   agent_phone,
        "parcelle_id":   str(parcelle_id),
        "parcelle_name": parc_name,
    }

async def reassign_agent(
    db:          AsyncSession,
    parcelle_id: UUID,
    agent_id:    UUID,
) -> dict:
    # Collecter AVANT le commit
    agent    = await _get_user_from_cache(db, agent_id, "agent")
    parcelle = await _get_parcelle(db, parcelle_id)

    agent_nom   = agent.nom
    agent_email = agent.email
    agent_phone = agent.phone or ""
    parc_name   = parcelle.name

    result = await db.execute(
        select(AgentParcelle).where(AgentParcelle.agent_id == agent_id)
    )
    assignment = result.scalar_one_or_none()

    if assignment:
        assignment.parcelle_id = parcelle_id
    else:
        db.add(AgentParcelle(agent_id=agent_id, parcelle_id=parcelle_id))

    await db.commit()

    return {
        "conflict":      False,
        "agent_id":      str(agent_id),
        "agent_nom":     agent_nom,
        "agent_email":   agent_email,
        "agent_phone":   agent_phone,
        "parcelle_id":   str(parcelle_id),
        "parcelle_name": parc_name,
    }


async def remove_agent(db: AsyncSession, agent_id: UUID) -> dict:
    """Retire un agent de sa parcelle."""
    result = await db.execute(
        select(AgentParcelle).where(AgentParcelle.agent_id == agent_id)
    )
    assignment = result.scalar_one_or_none()
    if not assignment:
        raise HTTPException(status_code=404, detail="Affectation introuvable")

    await db.delete(assignment)
    await db.commit()
    return {"message": "Agent retiré avec succès"}


async def _agent_assignment_response(
    db: AsyncSession,
    agent_id: UUID,
    parcelle_id: UUID,
) -> dict:
    """Construit la réponse d'affectation avec les infos enrichies."""
    agent_result = await db.execute(
        select(UserCache).where(UserCache.user_id == agent_id)
    )
    agent = agent_result.scalar_one_or_none()

    parcelle_result = await db.execute(
        select(Parcelle).where(Parcelle.id == parcelle_id)
    )
    parcelle = parcelle_result.scalar_one_or_none()

    return {
        "conflict":      False,
        "agent_id":      str(agent_id),
        "agent_nom":     agent.nom if agent else "Inconnu",
        "agent_email":   agent.email if agent else "",
        "parcelle_id":   str(parcelle_id),
        "parcelle_name": parcelle.name if parcelle else "Inconnue",
    }


# ────────────────────────────────────────────────────────────
# LISTEs
# ────────────────────────────────────────────────────────────

async def list_agents_with_status(db: AsyncSession) -> list[dict]:
    """
    Retourne tous les agents du cache avec leur statut d'affectation.
    Utilisé pour le dropdown de l'UI (afficher si déjà affecté ou non).
    """
    agents_result = await db.execute(
        select(UserCache).where(UserCache.role == "agent", UserCache.is_active == True)
    )
    agents = agents_result.scalars().all()

    # Récupérer toutes les affectations actuelles
    assignments_result = await db.execute(select(AgentParcelle))
    assignments = {str(a.agent_id): a for a in assignments_result.scalars().all()}

    result = []
    for agent in agents:
        agent_id_str = str(agent.user_id)
        assignment   = assignments.get(agent_id_str)

        parcelle_info = None
        if assignment:
            parc_result = await db.execute(
                select(Parcelle).where(Parcelle.id == assignment.parcelle_id)
            )
            parc = parc_result.scalar_one_or_none()
            if parc:
                parcelle_info = {
                    "parcelle_id":   str(parc.id),
                    "parcelle_name": parc.name,
                }

        result.append({
            "user_id":        agent_id_str,
            "nom":            agent.nom,
            "email":          agent.email,
            "is_assigned":    assignment is not None,
            "current_parcelle": parcelle_info,
        })

    return result


async def list_superviseurs_with_status(db: AsyncSession) -> list[dict]:
    """
    Retourne tous les superviseurs du cache avec leur statut d'affectation.
    """
    sup_result = await db.execute(
        select(UserCache).where(UserCache.role == "supervisor", UserCache.is_active == True)
    )
    superviseurs = sup_result.scalars().all()

    # Récupérer toutes les forêts avec superviseur_id
    forests_result = await db.execute(
        select(Forest).where(Forest.superviseur_id.isnot(None))
    )
    forests_by_sup: dict[str, list[dict]] = {}
    for f in forests_result.scalars().all():
        sid = str(f.superviseur_id)
        if sid not in forests_by_sup:
            forests_by_sup[sid] = []
        forests_by_sup[sid].append({"forest_id": str(f.id), "forest_name": f.name})

    result = []
    for sup in superviseurs:
        sup_id_str = str(sup.user_id)
        forests    = forests_by_sup.get(sup_id_str, [])
        result.append({
            "user_id":         sup_id_str,
            "nom":             sup.nom,
            "email":           sup.email,
            "is_assigned":     len(forests) > 0,
            "current_forests": forests,
        })

    return result


async def get_parcelle_agents(db: AsyncSession, parcelle_id: UUID) -> list[dict]:
    """Retourne les agents affectés à une parcelle."""
    result = await db.execute(
        select(AgentParcelle).where(AgentParcelle.parcelle_id == parcelle_id)
    )
    assignments = result.scalars().all()

    agents = []
    for a in assignments:
        agent_result = await db.execute(
            select(UserCache).where(UserCache.user_id == a.agent_id)
        )
        agent = agent_result.scalar_one_or_none()
        if agent:
            agents.append({
                "user_id":     str(agent.user_id),
                "nom":         agent.nom,
                "email":       agent.email,
                "assigned_at": a.assigned_at.isoformat() if a.assigned_at else None,
            })
    return agents