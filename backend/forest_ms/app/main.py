import asyncio
import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.db.database import engine, Base, AsyncSessionLocal
from app.routers import forest_router, parcelle_router
from app.routers.assignment_router import router as assignment_router
from app.core.redis_client import get_redis, close_redis
from app.consumers.user_consumer import run_user_consumer

import app.models.forest         
import app.models.parcelle       
import app.models.user_cache     
import app.models.agent_parcelle #

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ── Tâche background Redis consumer ──────────────────────────
_consumer_task: asyncio.Task | None = None


async def _start_redis_consumer(app: FastAPI) -> None:
    """Lance le consumer Redis Streams en background."""
    global _consumer_task
    try:
        redis = await get_redis()
        await redis.ping()
        logger.info("[MAIN] Redis disponible — démarrage du consumer")
        _consumer_task = asyncio.create_task(
            run_user_consumer(redis, AsyncSessionLocal)
        )
    except Exception as e:
        logger.warning(
            f"[MAIN] Redis indisponible au démarrage — consumer non lancé : {e}\n"
            f"[MAIN] Les affectations dépendront du cache existant"
        )


app = FastAPI(
    title="Ghabetna — Forest Service",
    version="1.1.0",
)

# ── CORS ──────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────
app.include_router(forest_router.router)
app.include_router(parcelle_router.router)
app.include_router(assignment_router)


# ── Lifecycle ─────────────────────────────────────────────────
@app.on_event("startup")
async def startup():
    # Créer les tables (inclut users_cache et agent_parcelle)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("[MAIN] Tables DB initialisées")

    # Démarrer le consumer Redis
    await _start_redis_consumer(app)


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


# ── Healthcheck ───────────────────────────────────────────────
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
        "service":  "forest-service",
        "redis":    "ok" if redis_ok else "unavailable",
        "consumer": "running" if _consumer_task and not _consumer_task.done() else "stopped",
    }