from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.routers.citizen_router import router as citizen_router

import app.models.citizen  # noqa: F401 — nécessaire pour qu'Alembic voie les modèles

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)
(UPLOAD_DIR / "citoyens").mkdir(exist_ok=True)

app = FastAPI(title="Ghabetna — Citizen Service", version="1.0.0")

app.add_middleware(CORSMiddleware, allow_origins=["*"],
                   allow_methods=["*"], allow_headers=["*"])

# Même montage que alert_ms : les pièces sont servies en statique et la
# gateway les relaie. Les tables sont créées par Alembic au démarrage
# (voir Dockerfile), pas par create_all.
app.mount("/uploads", StaticFiles(directory=str(UPLOAD_DIR)), name="uploads")
app.include_router(citizen_router)


@app.get("/health")
async def health():
    return {"status": "ok", "service": "citizen-service"}
