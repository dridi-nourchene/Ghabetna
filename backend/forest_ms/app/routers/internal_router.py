from typing import Optional
from uuid import UUID
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.database import get_db
from app.models.user_cahe import UserCache
from app.models.forest import Forest

router = APIRouter(prefix="/internal", tags=["Internal — enrichissement analytics"])


def _parse_ids(raw: Optional[str]) -> list[UUID]:
    if not raw:
        return []
    out = []
    for part in raw.split(","):
        part = part.strip()
        if not part:
            continue
        try:
            out.append(UUID(part))
        except ValueError:
            continue
    return out


@router.get("/users")
async def get_users(
    ids: Optional[str] = Query(None, description="UUID séparés par des virgules"),
    db:  AsyncSession  = Depends(get_db),
):
    user_ids = _parse_ids(ids)
    if not user_ids:
        return []
    result = await db.execute(
        select(UserCache).where(UserCache.user_id.in_(user_ids))
    )
    return [
        {
            "user_id": str(u.user_id),
            "nom":     u.nom,
            "email":   u.email,
            "phone":   u.phone,
            "role":    u.role,
        }
        for u in result.scalars().all()
    ]


@router.get("/forests")
async def get_forests(
    ids: Optional[str] = Query(None, description="UUID séparés par des virgules"),
    db:  AsyncSession  = Depends(get_db),
):
    forest_ids = _parse_ids(ids)
    if not forest_ids:
        return []
    result = await db.execute(
        select(Forest).where(Forest.id.in_(forest_ids))
    )
    return [
        {
            "forest_id":      str(f.id),
            "forest_name":    f.name,
            "superviseur_id": str(f.superviseur_id) if f.superviseur_id else None,
        }
        for f in result.scalars().all()
    ]


@router.get("/forests/all")
async def get_all_forests(
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Forest))
    return [
        {
            "forest_id":      str(f.id),
            "forest_name":    f.name,
            "superviseur_id": str(f.superviseur_id) if f.superviseur_id else None,
        }
        for f in result.scalars().all()
    ]