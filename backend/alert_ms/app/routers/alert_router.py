from uuid import UUID
from typing import Optional
from fastapi import APIRouter, Depends, File, Form, Header, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession
import json

from app.db.database import get_db
from app.core.dependencies import get_current_user_id, require_supervisor
from app.models.alert import AlertType, AlertStatus
from app.schemas.alert import AlertStatusUpdate
from app.services import alert_service

router = APIRouter(prefix="/api/alerts", tags=["Alertes"])


# ── CREATE (agent) ────────────────────────────────────────────

@router.post("/", status_code=201)
async def create_alert(
    type:         AlertType      = Form(...),
    forest_id:    UUID           = Form(...),
    description:  Optional[str]  = Form(None),
    incident_lat: Optional[float] = Form(None),
    incident_lng: Optional[float] = Form(None),
    agent_lat:    Optional[float] = Form(None),
    agent_lng:    Optional[float] = Form(None),
    image:        Optional[UploadFile] = File(None),
    db:           AsyncSession   = Depends(get_db),
    agent_id:     UUID           = Depends(get_current_user_id),
):
    from app.schemas.alert import AlertCreate
    data = AlertCreate(
        type=type, description=description, forest_id=forest_id,
        incident_lat=incident_lat, incident_lng=incident_lng,
        agent_lat=agent_lat, agent_lng=agent_lng,
    )
    return await alert_service.create_alert(db=db, data=data, agent_id=agent_id, image=image)


# ── MINE (agent) ──────────────────────────────────────────────

@router.get("/mine")
async def get_my_alerts(
    db:       AsyncSession = Depends(get_db),
    agent_id: UUID         = Depends(get_current_user_id),
):
    return await alert_service.get_agent_alerts(db, agent_id)


# ── MAP (supervisor — forêts assignées) ───────────────────────

@router.get("/supervisor/map")
async def get_supervisor_map(
    db:            AsyncSession = Depends(get_db),
    supervisor_id: UUID         = Depends(require_supervisor),
    x_forest_ids:  Optional[str] = Header(None, alias="X-Forest-Ids"),
):
    """
    Retourne les points carte pour les forêts assignées au superviseur.
    X-Forest-Ids est injecté par le gateway (liste JSON d'UUIDs).
    """
    forest_ids = _parse_forest_ids(x_forest_ids)
    return await alert_service.get_supervisor_map_points(db, forest_ids)


# ── LIST (supervisor — forêts assignées) ─────────────────────

@router.get("/supervisor")
async def get_supervisor_alerts(
    status:        Optional[AlertStatus] = None,
    db:            AsyncSession          = Depends(get_db),
    supervisor_id: UUID                  = Depends(require_supervisor),
    x_forest_ids:  Optional[str]         = Header(None, alias="X-Forest-Ids"),
):
    forest_ids = _parse_forest_ids(x_forest_ids)
    return await alert_service.get_supervisor_alerts(
        db, supervisor_id, forest_ids, status
    )


# ── GET BY ID ─────────────────────────────────────────────────

@router.get("/{alert_id}")
async def get_alert(
    alert_id: UUID,
    db:       AsyncSession = Depends(get_db),
    _:        UUID         = Depends(get_current_user_id),
):
    return await alert_service.get_alert_by_id(db, alert_id)


# ── UPDATE STATUS (supervisor) ────────────────────────────────

@router.patch("/{alert_id}/status")
async def update_status(
    alert_id:      UUID,
    data:          AlertStatusUpdate,
    db:            AsyncSession  = Depends(get_db),
    supervisor_id: UUID          = Depends(require_supervisor),
    x_forest_ids:  Optional[str] = Header(None, alias="X-Forest-Ids"),
):
    forest_ids = _parse_forest_ids(x_forest_ids)
    return await alert_service.update_alert_status(
        db, alert_id, data, supervisor_id, forest_ids
    )


# ── HELPER ────────────────────────────────────────────────────

def _parse_forest_ids(raw: Optional[str]) -> list[UUID]:
    """Parse X-Forest-Ids header : JSON array of UUID strings."""
    if not raw:
        return []
    try:
        ids = json.loads(raw)
        return [UUID(i) for i in ids]
    except Exception:
        return []