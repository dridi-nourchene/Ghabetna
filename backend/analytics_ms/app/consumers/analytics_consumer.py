"""
Redis Streams Consumer — analytics-service
Écoute stream:alert.created et stream:alert.status_updated depuis alert_ms.
Alimente une copie locale, allégée (AlertFact), utilisée uniquement pour
des requêtes agrégées (GROUP BY / COUNT / AVG).
"""
import asyncio
import uuid
import logging
from datetime import datetime

import redis.asyncio as aioredis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.alert_fact import AlertFact

logger = logging.getLogger("analytics_consumer")

STREAMS = {
    "stream:alert.created":        "created",
    "stream:alert.status_updated": "status_updated",
}

CONSUMER_GROUP = "analytics-service-group"
CONSUMER_NAME  = "analytics-consumer-1"
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


def _parse_dt(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None


async def _handle_created(data: dict, session: AsyncSession) -> None:
    alert_id = uuid.UUID(data["id"])

    result = await session.execute(
        select(AlertFact).where(AlertFact.id == alert_id)
    )
    existing = result.scalar_one_or_none()
    if existing:
        # Already recorded (e.g. redelivery) — nothing to do.
        return

    session.add(AlertFact(
        id         = alert_id,
        type       = data["type"],
        status     = data["status"],
        forest_id  = uuid.UUID(data["forest_id"]),
        agent_id   = uuid.UUID(data["agent_id"]),
        created_at = _parse_dt(data.get("created_at")) or datetime.utcnow(),
    ))
    logger.info(f"[CONSUMER] AlertFact créé : {alert_id} ({data.get('type')})")


async def _handle_status_updated(data: dict, session: AsyncSession) -> None:
    alert_id = uuid.UUID(data["id"])

    result = await session.execute(
        select(AlertFact).where(AlertFact.id == alert_id)
    )
    fact = result.scalar_one_or_none()

    if not fact:
        # Status update arrived before creation (out-of-order delivery,
        # or the fact was created before analytics_ms existed) — raise so
        # this message is retried until the created event lands too.
        raise RuntimeError(f"AlertFact {alert_id} introuvable pour status_updated")

    fact.status = data["status"]
    logger.info(f"[CONSUMER] AlertFact mis à jour : {alert_id} → {data.get('status')}")


HANDLERS = {
    "created":        _handle_created,
    "status_updated": _handle_status_updated,
}


async def run_alert_consumer(
    redis: aioredis.Redis,
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    logger.info("[CONSUMER] Démarrage alert consumer (analytics)")
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
                kind = STREAMS.get(stream_name)
                handler = HANDLERS.get(kind)
                if not handler:
                    continue

                for msg_id, data in messages:
                    try:
                        async with session_factory() as session:
                            async with session.begin():
                                await handler(data, session)
                        await redis.xack(stream_name, CONSUMER_GROUP, msg_id)
                    except Exception as e:
                        logger.error(f"[CONSUMER] Erreur {stream_name} {msg_id} : {e}")

        except asyncio.CancelledError:
            logger.info("[CONSUMER] Arrêt propre")
            break
        except Exception as e:
            logger.error(f"[CONSUMER] Redis error : {e}")
            await asyncio.sleep(RETRY_SLEEP_S)