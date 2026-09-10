"""
Redis Streams Consumer — forest-service
Écoute stream:user.activated ET stream:user.deleted depuis auth-service.
Le premier insère/met à jour users_cache ; le second retire l'utilisateur
et libère ses affectations (parcelle pour un agent, forêts pour un
superviseur) — sans quoi un compte supprimé restait "affecté" dans le
cache local, visible côté superviseur alors qu'il n'existe plus.
Consumer Group : forest-service-group
"""
import asyncio
import uuid
import logging

import redis.asyncio as aioredis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker
from sqlalchemy.orm import selectinload

from app.models.user_cahe import UserCache
from app.models.forest import Forest
from app.models.parcelle import Parcelle
from app.models.agent_parcelle import AgentParcelle
from app.core.streams import STREAM_AGENT_REMOVED, STREAM_SUPERVISEUR_REMOVED

logger = logging.getLogger("redis_consumer")

STREAM_ACTIVATED = "stream:user.activated"
STREAM_DELETED   = "stream:user.deleted"
CONSUMER_GROUP  = "forest-service-group"
CONSUMER_NAME   = "forest-consumer-1"
BLOCK_MS        = 5_000   # attendre 5s max par xreadgroup
RETRY_SLEEP_S   = 5       # délai en cas d'erreur Redis


# ────────────────────────────────────────────────────────────
# Initialisation du consumer group (idempotent)
# ────────────────────────────────────────────────────────────
async def _ensure_consumer_group(redis: aioredis.Redis, stream: str) -> None:
    """
    Crée le consumer group s'il n'existe pas.
    MKSTREAM : crée le stream si absent.
    $ : ne lire que les nouveaux messages (depuis maintenant).
    """
    try:
        await redis.xgroup_create(
            name=stream,
            groupname=CONSUMER_GROUP,
            id="$",
            mkstream=True,
        )
        logger.info(f"[CONSUMER] Consumer group '{CONSUMER_GROUP}' créé sur {stream}")
    except Exception as e:
        if "BUSYGROUP" in str(e):
            logger.info(f"[CONSUMER] Consumer group '{CONSUMER_GROUP}' déjà existant sur {stream}")
        else:
            raise


# ────────────────────────────────────────────────────────────
# stream:user.activated — upsert dans users_cache
# ────────────────────────────────────────────────────────────
async def _process_activated(
    data: dict,
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    """
    Upsert dans users_cache.
    Si l'utilisateur existe déjà (reconnexion, re-activation) → met à jour.
    """
    try:
        user_id_str = data.get("user_id", "")
        role        = data.get("role", "")
        nom         = data.get("nom", "")
        email       = data.get("email", "")
        phone       = data.get("phone", "") or None
        is_active   = data.get("is_active", "true").lower() == "true"

        if not user_id_str or not role:
            logger.warning(f"[CONSUMER] Message invalide ignoré : {data}")
            return

        user_id = uuid.UUID(user_id_str)

        async with session_factory() as session:
            async with session.begin():
                result = await session.execute(
                    select(UserCache).where(UserCache.user_id == user_id)
                )
                cached = result.scalar_one_or_none()

                if cached:
                    cached.role      = role
                    cached.nom       = nom
                    cached.email     = email
                    cached.phone     = phone
                    cached.is_active = is_active
                    logger.info(f"[CONSUMER] UserCache mis à jour : {nom} ({role})")
                else:
                    session.add(UserCache(
                        user_id   = user_id,
                        role      = role,
                        nom       = nom,
                        email     = email,
                        phone     = phone,
                        is_active = is_active,
                    ))
                    logger.info(f"[CONSUMER] UserCache inséré : {nom} ({role})")

    except Exception as e:
        logger.error(f"[CONSUMER] Erreur traitement user.activated : {e}")
        raise  # reraise pour ne pas ACK → sera retraité


# ────────────────────────────────────────────────────────────
# stream:user.deleted — retire du cache + libère les affectations
# ────────────────────────────────────────────────────────────
async def _process_deleted(
    data:  dict,
    redis: aioredis.Redis,
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    """
    Compte supprimé côté auth_ms :
      1. Retiré de users_cache.
      2. Si agent affecté à une parcelle → affectation supprimée,
         stream:agent.removed republié (alert_ms écoute déjà ce stream,
         rien à changer de son côté).
      3. Si superviseur affecté à une ou plusieurs forêts → chaque forêt
         est détachée, stream:superviseur.removed republié pour chacune.
    """
    try:
        user_id_str = data.get("user_id", "")
        role        = data.get("role", "")
        if not user_id_str:
            logger.warning(f"[CONSUMER] Message user.deleted invalide ignoré : {data}")
            return
        user_id = uuid.UUID(user_id_str)

        async with session_factory() as session:
            async with session.begin():
                cached = await session.execute(
                    select(UserCache).where(UserCache.user_id == user_id)
                )
                cached_user = cached.scalar_one_or_none()
                if cached_user:
                    await session.delete(cached_user)
                    logger.info(f"[CONSUMER] UserCache retiré : {user_id} ({role})")

                if role == "agent":
                    assignment_result = await session.execute(
                        select(AgentParcelle).where(AgentParcelle.agent_id == user_id)
                    )
                    assignment = assignment_result.scalar_one_or_none()
                    if assignment:
                        parcelle_id = assignment.parcelle_id
                        parcelle_result = await session.execute(
                            select(Parcelle)
                            .options(selectinload(Parcelle.forest))
                            .where(Parcelle.id == parcelle_id)
                        )
                        parcelle = parcelle_result.scalar_one_or_none()
                        await session.delete(assignment)

                        try:
                            await redis.xadd(
                                STREAM_AGENT_REMOVED,
                                {
                                    "agent_id":    str(user_id),
                                    "parcelle_id": str(parcelle_id),
                                    "forest_id":   str(parcelle.forest_id) if parcelle else "",
                                },
                            )
                            logger.info(
                                f"[CONSUMER] Agent {user_id} supprimé → "
                                f"parcelle {parcelle_id} libérée")
                        except Exception as e:
                            logger.error(f"[STREAM] Erreur publish agent.removed : {e}")

                elif role == "supervisor":
                    forests_result = await session.execute(
                        select(Forest).where(Forest.superviseur_id == user_id)
                    )
                    forests = forests_result.scalars().all()
                    for forest in forests:
                        forest.superviseur_id = None
                        try:
                            await redis.xadd(
                                STREAM_SUPERVISEUR_REMOVED,
                                {"forest_id": str(forest.id)},
                            )
                            logger.info(
                                f"[CONSUMER] Superviseur {user_id} supprimé → "
                                f"forêt {forest.id} libérée")
                        except Exception as e:
                            logger.error(f"[STREAM] Erreur publish superviseur.removed : {e}")

    except Exception as e:
        logger.error(f"[CONSUMER] Erreur traitement user.deleted : {e}")
        raise  # reraise pour ne pas ACK → sera retraité


HANDLERS = {
    STREAM_ACTIVATED: _process_activated,
    STREAM_DELETED:   _process_deleted,
}


# ────────────────────────────────────────────────────────────
# Boucle principale du consumer
# ────────────────────────────────────────────────────────────
async def run_user_consumer(
    redis: aioredis.Redis,
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    """
    Boucle infinie : lit les messages des deux streams, les traite, les ACK.
    Reprend depuis le dernier ID en cas de redémarrage (consumer group).
    """
    logger.info(f"[CONSUMER] Démarrage — streams: {STREAM_ACTIVATED}, {STREAM_DELETED}")

    for stream in (STREAM_ACTIVATED, STREAM_DELETED):
        await _ensure_consumer_group(redis, stream)

    await _process_pending(redis, session_factory)

    while True:
        try:
            results = await redis.xreadgroup(
                groupname=CONSUMER_GROUP,
                consumername=CONSUMER_NAME,
                streams={STREAM_ACTIVATED: ">", STREAM_DELETED: ">"},
                count=10,
                block=BLOCK_MS,
            )

            if not results:
                continue  # timeout, rien de nouveau

            for stream_name, messages in results:
                for msg_id, data in messages:
                    try:
                        if stream_name == STREAM_DELETED:
                            await _process_deleted(data, redis, session_factory)
                        else:
                            await _process_activated(data, session_factory)
                        # ACK seulement si le traitement a réussi
                        await redis.xack(stream_name, CONSUMER_GROUP, msg_id)
                        logger.debug(f"[CONSUMER] ACK {stream_name} {msg_id}")
                    except Exception as e:
                        logger.error(f"[CONSUMER] Échec message {stream_name} {msg_id} : {e} — sera retraité")

        except asyncio.CancelledError:
            logger.info("[CONSUMER] Consumer arrêté proprement")
            break
        except Exception as e:
            logger.error(f"[CONSUMER] Erreur Redis : {e} — retry dans {RETRY_SLEEP_S}s")
            await asyncio.sleep(RETRY_SLEEP_S)


# ────────────────────────────────────────────────────────────
# Retraiter les messages pending (après crash)
# ────────────────────────────────────────────────────────────
async def _process_pending(
    redis: aioredis.Redis,
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    """
    Récupère les messages assignés à ce consumer mais pas encore ACK.
    Permet la reprise après un crash.
    """
    for stream_name in (STREAM_ACTIVATED, STREAM_DELETED):
        try:
            pending = await redis.xreadgroup(
                groupname=CONSUMER_GROUP,
                consumername=CONSUMER_NAME,
                streams={stream_name: "0"},  # "0" = tous les pending de ce consumer
                count=100,
            )
            if not pending:
                continue

            count = 0
            for _stream_name, messages in pending:
                for msg_id, data in messages:
                    if not data:
                        continue
                    try:
                        if stream_name == STREAM_DELETED:
                            await _process_deleted(data, redis, session_factory)
                        else:
                            await _process_activated(data, session_factory)
                        await redis.xack(stream_name, CONSUMER_GROUP, msg_id)
                        count += 1
                    except Exception as e:
                        logger.error(f"[CONSUMER] Échec pending {stream_name} {msg_id} : {e}")

            if count:
                logger.info(f"[CONSUMER] {count} messages pending retraités sur {stream_name}")
        except Exception as e:
            logger.warning(f"[CONSUMER] Erreur lors du traitement des pending ({stream_name}) : {e}")
