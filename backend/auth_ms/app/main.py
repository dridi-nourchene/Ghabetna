from contextlib import asynccontextmanager
from fastapi import FastAPI
from app.db.database import engine, Base
from app.routers import auth_routes, user_routes


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Créer les tables au démarrage
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    # TODO: ajouter Redis consumer ici plus tard


app = FastAPI(
    title="Ghabetna — Auth MS",
    version="1.0.0",
)

app.include_router(auth_routes.router)
app.include_router(user_routes.router)