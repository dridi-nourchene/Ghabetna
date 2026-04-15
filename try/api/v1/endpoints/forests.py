from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional
from uuid import UUID

from app.db.database import get_db
from app.core.security import *
from app.schemas.forest import *
from app.services import forest_service

router = APIRouter()


# ── GET /geojson ──────────────────────────────────────────
@router.get(
    "/geojson",
    response_model=ForestsGeoJSONCollection,
)
async def get_forests_geojson(
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(verify_token),
):
    """
    Retourne toutes les forêts actives
    en GeoJSON FeatureCollection.
    Flutter_map consomme ce endpoint directement.
    """
    return await forest_service.get_forests_geojson(db)


# ── GET / ─────────────────────────────────────────────────
@router.get(
    "/",
    response_model=PaginatedForests,
)
async def list_forests(
    page:          int            = Query(1, ge=1),
    page_size:     int            = Query(20, ge=1, le=100),
    search:        Optional[str]  = Query(None),
    supervisor_cin: Optional[UUID] = Query(None),
    forest_status: Optional[str]  = Query(None, alias="status"),
    db:            AsyncSession   = Depends(get_db),
    _:             dict           = Depends(verify_token),
):
    total, items = await forest_service.list_forests(
        db, page, page_size, search, supervisor_cin, forest_status
    )
    return PaginatedForests(
        total=total,
        page=page,
        page_size=page_size,
        items=items,
    )


# ── GET /{id} ─────────────────────────────────────────────
@router.get(
    "/{forest_id}",
    response_model=ForestResponse,
)
async def get_forest(
    forest_id: UUID,
    db:        AsyncSession = Depends(get_db),
    _:         dict         = Depends(verify_token),
):
    return await forest_service.get_forest(db, forest_id)


# ── POST / ────────────────────────────────────────────────
@router.post(
    "/",
    response_model=ForestResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_forest(
    data:    ForestCreate = ...,
    db:      AsyncSession = Depends(get_db),
    payload: dict         = Depends(require_admin),
):
    user_id = UUID(payload["sub"])
    return await forest_service.create_forest(db, data, user_id)


# ── PUT /{id} ─────────────────────────────────────────────
@router.put(
    "/{forest_id}",
    response_model=ForestResponse,
)
async def update_forest(
    forest_id: UUID,
    data:      ForestUpdate = ...,
    db:        AsyncSession = Depends(get_db),
    _:         dict         = Depends(require_admin),
):
    return await forest_service.update_forest(db, forest_id, data)


# ── DELETE /{id} ──────────────────────────────────────────
@router.delete(
    "/{forest_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_forest(
    forest_id: UUID,
    db:        AsyncSession = Depends(get_db),
    _:         dict         = Depends(require_admin),
):

    await forest_service.delete_forest(db, forest_id)
