from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.db.database import engine, Base
from app.routers import forest_router, parcelle_router

# Import des modèles pour que SQLAlchemy les enregistre
import app.models.forest    # noqa
import app.models.parcelle  # noqa

app = FastAPI(
    title="Ghabetna — Forest Service",
    version="1.0.0",
    description="Microservice de gestion des forêts et parcelles (PostGIS)",
)

# ── CORS ──────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],       # gateway filtre déjà en amont
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────
app.include_router(forest_router.router)
app.include_router(parcelle_router.router)


# ── Healthcheck ───────────────────────────────────────────
@app.get("/health")
async def health():
    return {"status": "ok", "service": "forest-service"}