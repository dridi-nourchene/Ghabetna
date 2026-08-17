from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import DeclarativeBase
from app.core.config import settings


engine = create_async_engine(settings.DATABASE_URL, echo=False, pool_pre_ping=True,)

AsyncSessionLocal = async_sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False,)


class Base(DeclarativeBase):
    pass


# ── Dépendance FastAPI ────────────────────────────────────
# Pas de commit automatique ici, contrairement à auth_ms : l'inscription
# doit pouvoir décider elle-même du moment du commit pour gérer le rollback.
async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
