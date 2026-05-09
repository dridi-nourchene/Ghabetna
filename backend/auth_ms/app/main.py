from contextlib import asynccontextmanager
from fastapi import FastAPI
from app.db.database import engine, Base
from app.core.redis_client import get_redis, close_redis
from app.routers import auth_routes, user_routes


@asynccontextmanager
async def lifespan(app: FastAPI):
    # ── Démarrage ─────────────────────────────────────────
    # Créer les tables en DB
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    # Vérifier la connexion Redis au démarrage (non bloquant)
    try:
        redis = await get_redis()
        await redis.ping()
        print("[REDIS] Connexion Redis OK")
    except Exception as e:
        print(f"[REDIS WARNING] Redis indisponible au démarrage : {e}")
        print("[REDIS WARNING] L'activation des comptes sera bloquée jusqu'à rétablissement")

    yield

    # ── Arrêt ─────────────────────────────────────────────
    await close_redis()
    print("[REDIS] Connexion Redis fermée")


app = FastAPI(
    title="Ghabetna — Auth MS",
    version="1.0.0",
    lifespan=lifespan,
)

app.include_router(auth_routes.router)
app.include_router(user_routes.router)