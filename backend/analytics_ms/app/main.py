import asyncio
import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import engine, Base, AsyncSessionLocal
from app.analytics_router import router as analytics_router
from app.core.redis_client import get_redis, close_redis
from app.consumers.analytics_consumer import run_alert_consumer

import app.alert_fact

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

_consumer_task: asyncio.Task | None = None

app = FastAPI(title="Ghabetna — Analytics Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(analytics_router)


@app.on_event("startup")
async def startup():
    global _consumer_task

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("[MAIN] Tables DB initialisées")

    try:
        redis = await get_redis()
        await redis.ping()
        _consumer_task = asyncio.create_task(
            run_alert_consumer(redis, AsyncSessionLocal)
        )
        logger.info("[MAIN] Consumer démarré")
    except Exception as e:
        logger.warning(f"[MAIN] Redis indisponible au démarrage — consumer non lancé : {e}")


@app.on_event("shutdown")
async def shutdown():
    global _consumer_task
    if _consumer_task:
        _consumer_task.cancel()
        try:
            await _consumer_task
        except asyncio.CancelledError:
            pass
    await close_redis()
    logger.info("[MAIN] Shutdown propre")


@app.get("/health")
async def health():
    redis_ok = False
    try:
        redis = await get_redis()
        await redis.ping()
        redis_ok = True
    except Exception:
        pass
    return {
        "status":   "ok",
        "service":  "analytics-service",
        "redis":    "ok" if redis_ok else "unavailable",
        "consumer": "running" if _consumer_task and not _consumer_task.done() else "stopped",
    }