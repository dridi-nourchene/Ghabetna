from typing import Optional
from uuid import UUID
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db
from app.core.dependencies import require_admin
from app.models.alert import AlertType
from app.schemas.analytics import (
    AlertsByForestResponse, StatusTrendPoint, ForestTypeMatrixRow,
    SupervisorWorkloadResponse,
)
from app.services import analytics_service

router = APIRouter(prefix="/api/analytics", tags=["Analytics"])

# Fixed for now — see spec §9. Bump to a dynamic (mean + 1 std dev) calc later
# without touching the frontend, since it's returned in the response payload.
REJECT_RATE_THRESHOLD = 25.0


@router.get("/alerts-by-forest", response_model=AlertsByForestResponse)
async def alerts_by_forest(
    limit:     int             = Query(10, ge=1, le=20, description="5 / 10 / 20 selector"),
    forest_id: Optional[UUID]  = None,
    type:      Optional[AlertType] = None,
    days:      Optional[int]  = Query(None, description="Filtrer sur les N derniers jours"),
    db:        AsyncSession    = Depends(get_db),
    _:         UUID            = Depends(require_admin),
):
    return await analytics_service.get_alerts_by_forest(db, limit, forest_id, type, days)


@router.get("/status-trend", response_model=list[StatusTrendPoint])
async def status_trend(
    granularity: str             = Query("week", pattern="^(week|month)$"),
    forest_id:   Optional[UUID]  = None,
    type:        Optional[AlertType] = None,
    days:        Optional[int]  = None,
    db:          AsyncSession    = Depends(get_db),
    _:           UUID            = Depends(require_admin),
):
    return await analytics_service.get_status_trend(db, granularity, forest_id, type, days)


@router.get("/matrix-forest-type", response_model=list[ForestTypeMatrixRow])
async def matrix_forest_type(
    forest_id: Optional[UUID] = None,
    days:      Optional[int]  = None,
    db:        AsyncSession    = Depends(get_db),
    _:         UUID            = Depends(require_admin),
):
    return await analytics_service.get_forest_type_matrix(db, forest_id, days)


@router.get("/top-agents")
async def top_agents(
    status: str          = Query(..., pattern="^(traiter|rejeter)$"),
    limit:  int           = Query(5, ge=1, le=50),
    db:     AsyncSession   = Depends(get_db),
    _:      UUID           = Depends(require_admin),
):
    return await analytics_service.get_top_agents(db, status, limit)


@router.get("/supervisor-workload", response_model=SupervisorWorkloadResponse)
async def supervisor_workload(
    db: AsyncSession = Depends(get_db),
    _:  UUID         = Depends(require_admin),
):
    items = await analytics_service.get_supervisor_workload(db)
    return {"threshold": REJECT_RATE_THRESHOLD, "items": items}