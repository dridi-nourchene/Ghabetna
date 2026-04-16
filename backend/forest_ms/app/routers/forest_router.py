from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import UUID
from typing import Optional

from app.db.database import get_db
from app.schemas.forest import (
    ForestCreate, ForestUpdate, ForestResponse,
    ForestsGeoJSONCollection, PaginatedForests,
)
from app.services import forest_service
from app.core.deps import require_admin, get_current_user_id

router = APIRouter(prefix="/api/forests", tags=["Forests"])


# ── POST /api/forests/ ────────────────────────────────────
@router.post("/", response_model=ForestResponse, status_code=201)
async def create_forest(
    body: ForestCreate,
    db: AsyncSession = Depends(get_db),
    user_id: UUID    = Depends(require_admin),
):
    """Crée une nouvelle forêt. Admin uniquement."""
    return await forest_service.create_forest(db, body, user_id)


# ── GET /api/forests/ ─────────────────────────────────────
@router.get("/", response_model=PaginatedForests)
async def list_forests(
    page:           int            = Query(1,  ge=1),
    page_size:      int            = Query(20, ge=1, le=100),
    search:         Optional[str]  = Query(None),
    db: AsyncSession = Depends(get_db),
    _: UUID          = Depends(get_current_user_id),
):
    """Liste les forêts avec pagination et filtres."""
    total, items = await forest_service.list_forests(
        db, page, page_size, search
    )
    return {"total": total, "page": page, "page_size": page_size, "items": items}


# ── GET /api/forests/geojson ──────────────────────────────
@router.get("/geojson", response_model=ForestsGeoJSONCollection)
async def get_forests_geojson(
    db: AsyncSession = Depends(get_db),
    _: UUID          = Depends(get_current_user_id),
):
    """
    Retourne toutes les forêts actives en GeoJSON FeatureCollection.
    Consommé directement par flutter_map.
    """
    return await forest_service.get_forests_geojson(db)


# ── GET /api/forests/{forest_id} ──────────────────────────
@router.get("/{forest_id}", response_model=ForestResponse)
async def get_forest(
    forest_id: UUID,
    db: AsyncSession = Depends(get_db),
    _: UUID          = Depends(get_current_user_id),
):
    return await forest_service.get_forest(db, forest_id)


# ── PUT /api/forests/{forest_id} ──────────────────────────
@router.put("/{forest_id}", response_model=ForestResponse)
async def update_forest(
    forest_id: UUID,
    body: ForestUpdate,
    db: AsyncSession = Depends(get_db),
    _: UUID          = Depends(require_admin),
):
    """Modifie une forêt. Admin uniquement."""
    return await forest_service.update_forest(db, forest_id, body)


# ── DELETE /api/forests/{forest_id} ───────────────────────
@router.delete("/{forest_id}", status_code=204)
async def delete_forest(
    forest_id: UUID,
    db: AsyncSession = Depends(get_db),
    _: UUID          = Depends(require_admin),
):
    """Supprime une forêt (cascade → supprime ses parcelles). Admin uniquement."""
    await forest_service.delete_forest(db, forest_id)