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

logger = logging.getLogger("assignment_consumer")

STREAMS = {
    "stream:agent.assigned":   "_handle_assigned",
    "stream:agent.reassigned": "_handle_reassigned",
    "stream:agent.removed":    "_handle_removed",
    "stream:parcelle.deleted": "_handle_parcelle_deleted",
    "stream:forest.deleted":   "_handle_forest_deleted",
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
        cached.parcelle_id = parcelle_id
        cached.forest_id   = forest_id
        cached.agent_nom   = data.get("agent_nom")
        cached.agent_phone = data.get("agent_phone")
    else:
        session.add(AssignmentCache(
            agent_id    = agent_id,
            parcelle_id = parcelle_id,
            forest_id   = forest_id,
            agent_nom   = data.get("agent_nom"),
            agent_phone = data.get("agent_phone"),
        ))
    logger.info(f"[CONSUMER] Agent assigné : {data.get('agent_nom')}")


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


HANDLERS = {
    "stream:agent.assigned":   _handle_assigned,
    "stream:agent.reassigned": _handle_reassigned,
    "stream:agent.removed":    _handle_removed,
    "stream:parcelle.deleted": _handle_parcelle_deleted,
    "stream:forest.deleted":   _handle_forest_deleted,
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