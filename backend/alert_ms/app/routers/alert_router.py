from uuid import UUID
from typing import Optional
from fastapi import APIRouter, Depends, File, Form, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db
from app.core.dependencies import get_current_user_id, require_admin
from app.models.alert import AlertType, AlertStatus
from app.schemas.alert import AlertStatusUpdate
from app.services import alert_service

router = APIRouter(prefix="/api/alerts", tags=["Alertes"])


@router.post("/", status_code=201)
async def create_alert(
    type:         AlertType      = Form(...),
    forest_id:    UUID           = Form(...),
    description:  Optional[str]  = Form(None),
    # EXIF depuis la photo
    incident_lat: Optional[float] = Form(None),
    incident_lng: Optional[float] = Form(None),
    # GPS téléphone agent
    agent_lat:    Optional[float] = Form(None),
    agent_lng:    Optional[float] = Form(None),
    image:        Optional[UploadFile] = File(None),
    db:           AsyncSession   = Depends(get_db),
    agent_id:     UUID           = Depends(get_current_user_id),
):
    from app.schemas.alert import AlertCreate
    data = AlertCreate(
        type         = type,
        description  = description,
        forest_id    = forest_id,
        incident_lat = incident_lat,
        incident_lng = incident_lng,
        agent_lat    = agent_lat,
        agent_lng    = agent_lng,
    )
    return await alert_service.create_alert(
        db=db, data=data, agent_id=agent_id, image=image
    )


@router.get("/mine")
async def get_my_alerts(
    db:       AsyncSession = Depends(get_db),
    agent_id: UUID         = Depends(get_current_user_id),
):
    return await alert_service.get_agent_alerts(db, agent_id)


@router.get("/map")
async def get_map_points(
    db: AsyncSession = Depends(get_db),
    _:  UUID         = Depends(get_current_user_id),
):
    return await alert_service.get_map_points(db)


@router.get("/")
async def get_all_alerts(
    status: Optional[AlertStatus] = None,
    db:     AsyncSession          = Depends(get_db),
    _:      UUID                  = Depends(require_admin),
):
    return await alert_service.get_all_alerts(db, status)


@router.get("/{alert_id}")
async def get_alert(
    alert_id: UUID,
    db:       AsyncSession = Depends(get_db),
    _:        UUID         = Depends(get_current_user_id),
):
    return await alert_service.get_alert_by_id(db, alert_id)


@router.patch("/{alert_id}/status")
async def update_status(
    alert_id: UUID,
    data:     AlertStatusUpdate,
    db:       AsyncSession = Depends(get_db),
    admin_id: UUID         = Depends(require_admin),
):
    return await alert_service.update_alert_status(db, alert_id, data, admin_id)