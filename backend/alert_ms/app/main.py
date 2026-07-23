from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pathlib import Path
import asyncio
import logging

from app.db.database import engine, Base, AsyncSessionLocal
from app.routers.alert_router import router as alert_router
from app.core.redis_client import get_redis, close_redis
from app.consumers.assignment_consumer import run_assignment_consumer
from app.routers.analytics_router import router as analytics_router

import app.models.forest_supervisor_cache
import app.models.alert
import app.models.assignment_cache  

logger = logging.getLogger(__name__)

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)
(UPLOAD_DIR / "alerts").mkdir(exist_ok=True)

_consumer_task = None

app = FastAPI(title="Ghabetna — Alert Service", version="1.0.0")

app.add_middleware(CORSMiddleware, allow_origins=["*"],
                   allow_methods=["*"], allow_headers=["*"])

app.mount("/uploads", StaticFiles(directory=str(UPLOAD_DIR)), name="uploads")
app.include_router(alert_router)
app.include_router(analytics_router)


@app.on_event("startup")
async def startup():
    global _consumer_task
    UPLOAD_DIR.mkdir(exist_ok=True)
    (UPLOAD_DIR / "alerts").mkdir(exist_ok=True)

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    # Démarrer le consumer
    try:
        redis = await get_redis()
        await redis.ping()
        _consumer_task = asyncio.create_task(
            run_assignment_consumer(redis, AsyncSessionLocal)
        )
        logger.info("[ALERT MS] Consumer démarré")
    except Exception as e:
        logger.warning(f"[ALERT MS] Redis indisponible : {e}")


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


@app.get("/health")
async def health():
    return {"status": "ok", "service": "alert-service"}