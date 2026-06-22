import uuid
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID
from typing import Optional

from fastapi import HTTPException, UploadFile
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.alert import Alert, AlertStatus, LocationSource
from app.schemas.alert import AlertCreate, AlertStatusUpdate
from app.core.config import settings

UPLOAD_DIR = Path("uploads/alerts")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp"}
MAX_SIZE_MB   = 10


def _image_url(image_path: Optional[str]) -> Optional[str]:
    if not image_path:
        return None
    return f"/uploads/{image_path}"


def _alert_to_dict(alert: Alert) -> dict:
    return {
        "id":                 str(alert.id),
        "type":               alert.type,
        "status":             alert.status,
        "description":        alert.description,
        "incident_lat":       alert.incident_lat,
        "incident_lng":       alert.incident_lng,
        "agent_lat":          alert.agent_lat,
        "agent_lng":          alert.agent_lng,
        "location_source":    alert.location_source,
        "image_url":          _image_url(alert.image_path),
        "agent_id":           str(alert.agent_id),
        "forest_id":          str(alert.forest_id),
        "supervisor_comment": alert.supervisor_comment,
        "supervisor_id":      str(alert.supervisor_id) if alert.supervisor_id else None,
        "commented_at":       alert.commented_at.isoformat() if alert.commented_at else None,
        "created_at":         alert.created_at.isoformat(),
        "updated_at":         alert.updated_at.isoformat() if alert.updated_at else None,
    }


async def _save_image(file: UploadFile) -> str:
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=400,
            detail="Format non supporté. Utilisez JPEG, PNG ou WebP.",
        )
    content = await file.read()
    if len(content) > MAX_SIZE_MB * 1024 * 1024:
        raise HTTPException(
            status_code=400,
            detail=f"Image trop lourde (max {MAX_SIZE_MB}MB)",
        )
    ext      = file.filename.rsplit(".", 1)[-1].lower() if "." in file.filename else "jpg"
    filename = f"{uuid.uuid4()}.{ext}"
    path     = UPLOAD_DIR / filename
    with open(path, "wb") as f:
        f.write(content)
    return f"alerts/{filename}"


def _resolve_location(data: AlertCreate):
    if data.incident_lat is not None and data.incident_lng is not None:
        geom = f"SRID=4326;POINT({data.incident_lng} {data.incident_lat})"
        return data.incident_lat, data.incident_lng, LocationSource.exif, geom
    return None, None, LocationSource.forest_only, None


# ── CREATE ────────────────────────────────────────────────────

async def create_alert(
    db:       AsyncSession,
    data:     AlertCreate,
    agent_id: UUID,
    image:    Optional[UploadFile] = None,
) -> dict:
    incident_lat, incident_lng, location_source, geom = _resolve_location(data)

    image_path = None
    if image and image.filename:
        image_path = await _save_image(image)

    alert = Alert(
        type            = data.type,
        status          = AlertStatus.en_cours,
        description     = data.description,
        incident_lat    = incident_lat,
        incident_lng    = incident_lng,
        agent_lat       = data.agent_lat,
        agent_lng       = data.agent_lng,
        location_source = location_source,
        geom            = geom,
        image_path      = image_path,
        agent_id        = agent_id,
        forest_id       = data.forest_id,
    )
    db.add(alert)
    await db.commit()
    await db.refresh(alert)
    return _alert_to_dict(alert)


# ── GET AGENT ALERTS ──────────────────────────────────────────

async def get_agent_alerts(db: AsyncSession, agent_id: UUID) -> list[dict]:
    result = await db.execute(
        select(Alert)
        .where(Alert.agent_id == agent_id)
        .order_by(Alert.created_at.desc())
    )
    return [_alert_to_dict(a) for a in result.scalars().all()]


# ── GET SUPERVISOR ALERTS (forêts assignées) ──────────────────

async def get_supervisor_alerts(
    db:            AsyncSession,
    supervisor_id: UUID,
    forest_ids:    list[UUID],
    status:        Optional[AlertStatus] = None,
) -> list[dict]:
    """
    Retourne les alertes uniquement pour les forêts assignées au superviseur.
    forest_ids est résolu côté gateway depuis forest_service.
    """
    if not forest_ids:
        return []

    query = (
        select(Alert)
        .where(Alert.forest_id.in_(forest_ids))
        .order_by(Alert.created_at.desc())
    )
    if status:
        query = query.where(Alert.status == status)

    result = await db.execute(query)
    return [_alert_to_dict(a) for a in result.scalars().all()]


# ── GET MAP POINTS (supervisor) ───────────────────────────────

async def get_supervisor_map_points(
    db:         AsyncSession,
    forest_ids: list[UUID],
) -> list[dict]:
    if not forest_ids:
        return []

    result = await db.execute(
        select(Alert)
        .where(
            Alert.forest_id.in_(forest_ids),
            Alert.status != AlertStatus.rejeter,
        )
        .order_by(Alert.created_at.desc())
    )
    return [
        {
            "id":              str(a.id),
            "type":            a.type,
            "status":          a.status,
            "incident_lat":    a.incident_lat,
            "incident_lng":    a.incident_lng,
            "location_source": a.location_source,
            "forest_id":       str(a.forest_id),
            "created_at":      a.created_at.isoformat(),
        }
        for a in result.scalars().all()
    ]


# ── MAP POINTS (admin — toutes alertes) ───────────────────────

async def get_map_points(db: AsyncSession) -> list[dict]:
    result = await db.execute(
        select(Alert)
        .where(Alert.status != AlertStatus.rejeter)
        .order_by(Alert.created_at.desc())
    )
    return [
        {
            "id":              str(a.id),
            "type":            a.type,
            "status":          a.status,
            "incident_lat":    a.incident_lat,
            "incident_lng":    a.incident_lng,
            "location_source": a.location_source,
            "forest_id":       str(a.forest_id),
            "created_at":      a.created_at.isoformat(),
        }
        for a in result.scalars().all()
    ]


# ── GET BY ID ─────────────────────────────────────────────────

async def get_alert_by_id(db: AsyncSession, alert_id: UUID) -> dict:
    result = await db.execute(select(Alert).where(Alert.id == alert_id))
    alert  = result.scalar_one_or_none()
    if not alert:
        raise HTTPException(status_code=404, detail="Alerte introuvable")
    return _alert_to_dict(alert)


# ── UPDATE STATUS (superviseur) ───────────────────────────────

async def update_alert_status(
    db:            AsyncSession,
    alert_id:      UUID,
    data:          AlertStatusUpdate,
    supervisor_id: UUID,
    forest_ids:    list[UUID],  # forêts assignées au superviseur
) -> dict:
    result = await db.execute(select(Alert).where(Alert.id == alert_id))
    alert  = result.scalar_one_or_none()
    if not alert:
        raise HTTPException(status_code=404, detail="Alerte introuvable")

    # Vérifier que l'alerte appartient à une forêt du superviseur
    if alert.forest_id not in forest_ids:
        raise HTTPException(
            status_code=403,
            detail="Cette alerte n'appartient pas à vos forêts",
        )

    alert.status = data.status
    if data.supervisor_comment is not None:
        alert.supervisor_comment = data.supervisor_comment
        alert.supervisor_id      = supervisor_id
        alert.commented_at       = datetime.now(timezone.utc)

    await db.commit()
    result2 = await db.execute(select(Alert).where(Alert.id == alert_id))
    return _alert_to_dict(result2.scalar_one())