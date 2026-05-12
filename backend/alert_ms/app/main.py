from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pathlib import Path

from app.db.database import engine, Base
from app.routers.alert_router import router as alert_router
import app.models.alert  # noqa — enregistre le modèle

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

app = FastAPI(
    title="Ghabetna — Alert Service",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Servir les images uploadées ───────────────────────────────
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# ── Router ────────────────────────────────────────────────────
app.include_router(alert_router)


@app.on_event("startup")
async def startup():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    print("[ALERT MS] Tables initialisées")


@app.get("/health")
async def health():
    return {"status": "ok", "service": "alert-service"}