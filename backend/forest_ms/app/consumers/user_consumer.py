"""
Redis Streams Consumer — forest-service
Écoute stream:user.activated depuis auth-service.
Insère/met à jour users_cache localement.
Consumer Group : forest-service-group
"""
import asyncio
import uuid
import logging

import redis.asyncio as aioredis
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.user_cahe import UserCache

logger = logging.getLogger("redis_consumer")

STREAM_NAME     = "stream:user.activated"
CONSUMER_GROUP  = "forest-service-group"
CONSUMER_NAME   = "forest-consumer-1"
BLOCK_MS        = 5_000   # attendre 5s max par xreadgroup
RETRY_SLEEP_S   = 5       # délai en cas d'erreur Redis


# ────────────────────────────────────────────────────────────
# Initialisation du consumer group (idempotent)
# ────────────────────────────────────────────────────────────
async def _ensure_consumer_group(redis: aioredis.Redis) -> None:
    """
    Crée le consumer group s'il n'existe pas.
    MKSTREAM : crée le stream si absent.
    $ : ne lire que les nouveaux messages (depuis maintenant).
    """
    try:
        await redis.xgroup_create(
            name=STREAM_NAME,
            groupname=CONSUMER_GROUP,
            id="$",
            mkstream=True,
        )
        logger.info(f"[CONSUMER] Consumer group '{CONSUMER_GROUP}' créé")
    except Exception as e:
        if "BUSYGROUP" in str(e):
            logger.info(f"[CONSUMER] Consumer group '{CONSUMER_GROUP}' déjà existant")
        else:
            raise


# ────────────────────────────────────────────────────────────
# Traitement d'un message
# ────────────────────────────────────────────────────────────
async def _process_message(
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
                # Chercher si déjà en cache
                from sqlalchemy import select
                result = await session.execute(
                    select(UserCache).where(UserCache.user_id == user_id)
                )
                cached = result.scalar_one_or_none()

                if cached:
                    # Mise à jour
                    cached.role      = role
                    cached.nom       = nom
                    cached.email     = email
                    cached.phone     = phone
                    cached.is_active = is_active
                    logger.info(f"[CONSUMER] UserCache mis à jour : {nom} ({role})")
                else:
                    # Insertion
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
        logger.error(f"[CONSUMER] Erreur traitement message : {e}")
        raise  # reraise pour ne pas ACK → sera retraité


# ────────────────────────────────────────────────────────────
# Boucle principale du consumer
# ────────────────────────────────────────────────────────────
async def run_user_consumer(
    redis: aioredis.Redis,
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    """
    Boucle infinie : lit les messages du stream, les traite, les ACK.
    Reprend depuis le dernier ID en cas de redémarrage (consumer group).
    """
    logger.info(f"[CONSUMER] Démarrage — stream: {STREAM_NAME}")

    # S'assurer que le consumer group existe
    await _ensure_consumer_group(redis)

    # Retraiter les messages en attente (pending) depuis un crash précédent
    await _process_pending(redis, session_factory)

    while True:
        try:
            # Lire les nouveaux messages (BLOCK 5s)
            results = await redis.xreadgroup(
                groupname=CONSUMER_GROUP,
                consumername=CONSUMER_NAME,
                streams={STREAM_NAME: ">"},
                count=10,
                block=BLOCK_MS,
            )

            if not results:
                continue  # timeout, rien de nouveau

            for stream_name, messages in results:
                for msg_id, data in messages:
                    try:
                        await _process_message(data, session_factory)
                        # ACK seulement si le traitement a réussi
                        await redis.xack(STREAM_NAME, CONSUMER_GROUP, msg_id)
                        logger.debug(f"[CONSUMER] ACK {msg_id}")
                    except Exception as e:
                        logger.error(f"[CONSUMER] Échec message {msg_id} : {e} — sera retraité")

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
    try:
        pending = await redis.xreadgroup(
            groupname=CONSUMER_GROUP,
            consumername=CONSUMER_NAME,
            streams={STREAM_NAME: "0"},  # "0" = tous les pending de ce consumer
            count=100,
        )
        if not pending:
            return

        count = 0
        for stream_name, messages in pending:
            for msg_id, data in messages:
                if not data:
                    continue
                try:
                    await _process_message(data, session_factory)
                    await redis.xack(STREAM_NAME, CONSUMER_GROUP, msg_id)
                    count += 1
                except Exception as e:
                    logger.error(f"[CONSUMER] Échec pending {msg_id} : {e}")

        if count:
            logger.info(f"[CONSUMER] {count} messages pending retraités")
    except Exception as e:
        logger.warning(f"[CONSUMER] Erreur lors du traitement des pending : {e}")