"""
Écoute les streams d'affectation depuis forest_ms
"""
import asyncio
import uuid
import logging
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker
import redis.asyncio as aioredis
from app.models.assignment_cache import AssignmentCache
from app.models.forest_supervisor_cache import ForestSupervisorCache 

logger = logging.getLogger("assignment_consumer")

STREAMS = {
    "stream:agent.assigned":   "_handle_assigned",
    "stream:agent.reassigned": "_handle_reassigned",
    "stream:agent.removed":    "_handle_removed",
    "stream:parcelle.deleted": "_handle_parcelle_deleted",
    "stream:forest.deleted":   "_handle_forest_deleted",
    "stream:superviseur.assigned": "_handle_superviseur_assigned",  
    "stream:superviseur.removed":  "_handle_superviseur_removed",
}

CONSUMER_GROUP = "alert-service-group"
CONSUMER_NAME  = "alert-consumer-1"
BLOCK_MS       = 5_000
RETRY_SLEEP_S  = 5


async def _ensure_groups(redis: aioredis.Redis) -> None:
    for stream in STREAMS.keys():
        try:
            await redis.xgroup_create(
                name=stream,
                groupname=CONSUMER_GROUP,
                id="$",
                mkstream=True,
            )
        except Exception as e:
            if "BUSYGROUP" not in str(e):
                raise


async def _handle_assigned(
    data: dict,
    session: AsyncSession
) -> None:
    agent_id    = uuid.UUID(data["agent_id"])
    parcelle_id = uuid.UUID(data["parcelle_id"])
    forest_id   = uuid.UUID(data["forest_id"])

    result = await session.execute(
        select(AssignmentCache).where(
            AssignmentCache.agent_id == agent_id
        )
    )
    cached = result.scalar_one_or_none()

    if cached:
        cached.parcelle_id  = parcelle_id
        cached.forest_id    = forest_id
        cached.agent_nom    = data.get("agent_nom")
        cached.agent_phone  = data.get("agent_phone")
        cached.agent_email  = data.get("agent_email")
        cached.forest_name  = data.get("forest_name")        
        cached.parcelle_name = data.get("parcelle_name")     
    else:
        session.add(AssignmentCache(
            agent_id     = agent_id,
            parcelle_id  = parcelle_id,
            forest_id    = forest_id,
            agent_nom    = data.get("agent_nom"),
            agent_phone  = data.get("agent_phone"),
            agent_email  = data.get("agent_email"),
            forest_name  = data.get("forest_name"),
            parcelle_name = data.get("parcelle_name"),
        ))
    logger.info(
        f"[CONSUMER] Agent assigné : {data.get('agent_nom')} "
        f"@ {data.get('parcelle_name')}"
    )

async def _handle_reassigned(
    data: dict,
    session: AsyncSession
) -> None:
    # même logique que assigned
    await _handle_assigned(data, session)


async def _handle_removed(
    data: dict,
    session: AsyncSession
) -> None:
    agent_id = uuid.UUID(data["agent_id"])
    await session.execute(
        delete(AssignmentCache).where(
            AssignmentCache.agent_id == agent_id
        )
    )
    logger.info(f"[CONSUMER] Agent retiré : {data.get('agent_id')}")


async def _handle_parcelle_deleted(
    data: dict,
    session: AsyncSession
) -> None:
    parcelle_id = uuid.UUID(data["parcelle_id"])
    await session.execute(
        delete(AssignmentCache).where(
            AssignmentCache.parcelle_id == parcelle_id
        )
    )
    logger.info(f"[CONSUMER] Parcelle supprimée : {data.get('parcelle_id')}")


async def _handle_forest_deleted(
    data: dict,
    session: AsyncSession
) -> None:
    forest_id = uuid.UUID(data["forest_id"])
    await session.execute(
        delete(AssignmentCache).where(
            AssignmentCache.forest_id == forest_id
        )
    )
    logger.info(f"[CONSUMER] Forêt supprimée : {data.get('forest_id')}")

async def _handle_superviseur_assigned(data: dict, session: AsyncSession) -> None:
    forest_id     = uuid.UUID(data["forest_id"])
    supervisor_id = uuid.UUID(data["superviseur_id"])

    result = await session.execute(
        select(ForestSupervisorCache).where(ForestSupervisorCache.forest_id == forest_id)
    )
    cached = result.scalar_one_or_none()

    if cached:
        cached.forest_name      = data.get("forest_name")
        cached.supervisor_id    = supervisor_id
        cached.supervisor_nom   = data.get("superviseur_nom")
        cached.supervisor_phone = data.get("superviseur_phone")
        cached.supervisor_email = data.get("superviseur_email")
    else:
        session.add(ForestSupervisorCache(
            forest_id        = forest_id,
            forest_name      = data.get("forest_name"),
            supervisor_id    = supervisor_id,
            supervisor_nom   = data.get("superviseur_nom"),
            supervisor_phone = data.get("superviseur_phone"),
            supervisor_email = data.get("superviseur_email"),
        ))
    logger.info(f"[CONSUMER] Superviseur affecté : {data.get('superviseur_nom')} → {data.get('forest_name')}")


async def _handle_superviseur_removed(data: dict, session: AsyncSession) -> None:
    forest_id = uuid.UUID(data["forest_id"])
    await session.execute(
        delete(ForestSupervisorCache).where(ForestSupervisorCache.forest_id == forest_id)
    )
    logger.info(f"[CONSUMER] Superviseur retiré de la forêt : {data.get('forest_id')}")



    
HANDLERS = {
    "stream:agent.assigned":   _handle_assigned,
    "stream:agent.reassigned": _handle_reassigned,
    "stream:agent.removed":    _handle_removed,
    "stream:parcelle.deleted": _handle_parcelle_deleted,
    "stream:forest.deleted":   _handle_forest_deleted,
    "stream:superviseur.assigned": _handle_superviseur_assigned,   # ← ajouté
    "stream:superviseur.removed":  _handle_superviseur_removed,    # ← ajouté
}




async def run_assignment_consumer(
    redis: aioredis.Redis,
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    logger.info("[CONSUMER] Démarrage assignment consumer")
    await _ensure_groups(redis)

    while True:
        try:
            results = await redis.xreadgroup(
                groupname=CONSUMER_GROUP,
                consumername=CONSUMER_NAME,
                streams={s: ">" for s in STREAMS.keys()},
                count=10,
                block=BLOCK_MS,
            )

            if not results:
                continue

            for stream_name, messages in results:
                handler = HANDLERS.get(stream_name)
                if not handler:
                    continue

                for msg_id, data in messages:
                    try:
                        async with session_factory() as session:
                            async with session.begin():
                                await handler(data, session)
                        await redis.xack(
                            stream_name,
                            CONSUMER_GROUP,
                            msg_id
                        )
                    except Exception as e:
                        logger.error(
                            f"[CONSUMER] Erreur {stream_name} "
                            f"{msg_id} : {e}"
                        )

        except asyncio.CancelledError:
            logger.info("[CONSUMER] Arrêt propre")
            break
        except Exception as e:
            logger.error(f"[CONSUMER] Redis error : {e}")
            await asyncio.sleep(RETRY_SLEEP_S)