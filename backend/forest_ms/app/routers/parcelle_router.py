from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import UUID
from typing import Optional

from app.db.database import get_db
from app.schemas.parcelle import (
    ParcelleCreate, ParcelleUpdate, ParcelleResponse,
    ParcellesGeoJSONCollection, PaginatedParcelles,
)
from app.services import parcelle_service
from app.core.dependencies import require_admin, get_current_user_id

router = APIRouter(prefix="/api/parcelles", tags=["Parcelles"])


# ── POST /api/parcelles/ ──────────────────────────────────
@router.post("/", response_model=ParcelleResponse, status_code=201)
async def create_parcelle(
    body: ParcelleCreate,
    db: AsyncSession = Depends(get_db),
    user_id: UUID    = Depends(require_admin),
):
    """
    Crée une parcelle dans une forêt. Admin uniquement.
    Validation : dans les bordures de la forêt + pas de chevauchement.
    """
    return await parcelle_service.create_parcelle(db, body, user_id)


# ── GET /api/parcelles/ ───────────────────────────────────
@router.get("/", response_model=PaginatedParcelles)
async def list_parcelles(
    forest_id:  Optional[UUID] = Query(None, description="Filtrer par forêt"),
    page:       int            = Query(1,  ge=1),
    page_size:  int            = Query(20, ge=1, le=100),
    search:     Optional[str]  = Query(None),
    db: AsyncSession = Depends(get_db),
    _: UUID          = Depends(get_current_user_id),
):
    """Liste les parcelles. Si forest_id → filtre par forêt."""
    total, items = await parcelle_service.list_parcelles(
        db, forest_id, page, page_size, search
    )
    return {"total": total, "page": page, "page_size": page_size, "items": items}


# ── GET /api/parcelles/geojson ────────────────────────────
@router.get("/geojson", response_model=ParcellesGeoJSONCollection)
async def get_parcelles_geojson(
    forest_id: Optional[UUID] = Query(None, description="Filtrer par forêt"),
    db: AsyncSession = Depends(get_db),
    _: UUID          = Depends(get_current_user_id),
):
    """
    Retourne les parcelles actives en GeoJSON FeatureCollection.
    Si forest_id fourni → seulement les parcelles de cette forêt.
    """
    return await parcelle_service.get_parcelles_geojson(db, forest_id)


# ── GET /api/parcelles/{parcelle_id} ──────────────────────
@router.get("/{parcelle_id}", response_model=ParcelleResponse)
async def get_parcelle(
    parcelle_id: UUID,
    db: AsyncSession = Depends(get_db),
    _: UUID          = Depends(get_current_user_id),
):
    return await parcelle_service.get_parcelle(db, parcelle_id)


# ── PUT /api/parcelles/{parcelle_id} ──────────────────────
@router.put("/{parcelle_id}", response_model=ParcelleResponse)
async def update_parcelle(
    parcelle_id: UUID,
    body: ParcelleUpdate,
    db: AsyncSession = Depends(get_db),
    _: UUID          = Depends(require_admin),
):
    """Modifie une parcelle. Revalide les contraintes spatiales. Admin uniquement."""
    return await parcelle_service.update_parcelle(db, parcelle_id, body)


# ── DELETE /api/parcelles/{parcelle_id} ───────────────────
@router.delete("/{parcelle_id}", status_code=204)
async def delete_parcelle(
    parcelle_id: UUID,
    db: AsyncSession = Depends(get_db),
    _: UUID          = Depends(require_admin),
):
    """Supprime une parcelle. Admin uniquement."""
    await parcelle_service.delete_parcelle(db, parcelle_id)