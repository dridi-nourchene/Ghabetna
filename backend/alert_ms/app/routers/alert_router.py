from uuid import UUID
from typing import Optional
from fastapi import APIRouter, Depends, File, Form, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db
from app.core.dependencies import get_current_user_id, get_current_user_role, require_admin
from app.models.alert import AlertType, AlertStatus
from app.schemas.alert import AlertStatusUpdate
from app.services import alert_service

router = APIRouter(prefix="/api/alerts", tags=["Alertes"])


# ── Agent — créer une alerte (multipart) ──────────────────────
@router.post("/", status_code=201,
             summary="Créer une alerte (agent)")
async def create_alert(
    # Champs form
    type:        AlertType     = Form(...),
    forest_id:   UUID          = Form(...),
    description: Optional[str] = Form(None),
    latitude:    Optional[float] = Form(None),   # extrait EXIF côté Flutter
    longitude:   Optional[float] = Form(None),
    # Fichier image
    image:       Optional[UploadFile] = File(None),
    # Auth injecté par le gateway
    db:          AsyncSession  = Depends(get_db),
    agent_id:    UUID          = Depends(get_current_user_id),
):
    from app.schemas.alert import AlertCreate
    data = AlertCreate(
        type        = type,
        description = description,
        forest_id   = forest_id,
        latitude    = latitude,
        longitude   = longitude,
    )
    return await alert_service.create_alert(
        db=db, data=data, agent_id=agent_id, image=image
    )


# ── Agent — ses propres alertes ───────────────────────────────
@router.get("/mine",
            summary="Mes alertes (agent)")
async def get_my_alerts(
    db:       AsyncSession = Depends(get_db),
    agent_id: UUID         = Depends(get_current_user_id),
):
    return await alert_service.get_agent_alerts(db, agent_id)


# ── Map polling — alertes non rejetées ────────────────────────
@router.get("/map",
            summary="Points alertes pour la map (polling admin)")
async def get_map_points(
    db: AsyncSession = Depends(get_db),
    _:  UUID         = Depends(get_current_user_id),
):
    """
    Endpoint léger appelé toutes les 30s par la map admin.
    Retourne uniquement les alertes en_cours et traiter (pas rejetées).
    """
    return await alert_service.get_map_points(db)


# ── Admin — toutes les alertes ────────────────────────────────
@router.get("/",
            summary="Toutes les alertes (admin)")
async def get_all_alerts(
    status: Optional[AlertStatus] = None,
    db:     AsyncSession          = Depends(get_db),
    _:      UUID                  = Depends(require_admin),
):
    return await alert_service.get_all_alerts(db, status)


# ── Détail alerte ─────────────────────────────────────────────
@router.get("/{alert_id}",
            summary="Détail d'une alerte")
async def get_alert(
    alert_id: UUID,
    db:       AsyncSession = Depends(get_db),
    _:        UUID         = Depends(get_current_user_id),
):
    return await alert_service.get_alert_by_id(db, alert_id)


# ── Admin — changer statut + commentaire ──────────────────────
@router.patch("/{alert_id}/status",
              summary="Modifier statut + commentaire (admin)")
async def update_status(
    alert_id: UUID,
    data:     AlertStatusUpdate,
    db:       AsyncSession = Depends(get_db),
    admin_id: UUID         = Depends(require_admin),
):
    return await alert_service.update_alert_status(db, alert_id, data, admin_id)