# backend/alert_ms/app/services/alert_service.py

import os
import uuid
import httpx  # ajouter cet import
import shutil
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID
from typing import Optional

from fastapi import HTTPException, UploadFile
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.alert import Alert, AlertStatus, AlertType
from app.schemas.alert import AlertCreate, AlertStatusUpdate
from app.core.config import settings

UPLOAD_DIR = Path("uploads/alerts")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp"}
MAX_SIZE_MB   = 10

# URL du forest_ms — à mettre dans .env idéalement
FOREST_SERVICE_URL = os.getenv("FOREST_SERVICE_URL", "http://localhost:8002")


# ── HELPERS ───────────────────────────────────────────────────

def _image_url(image_path: Optional[str]) -> Optional[str]:
    if not image_path:
        return None
    return f"{settings.BASE_URL}/uploads/{image_path}"


def _alert_to_dict(alert: Alert) -> dict:
    return {
        "id":            str(alert.id),
        "type":          alert.type,
        "status":        alert.status,
        "description":   alert.description,
        "latitude":      alert.latitude,
        "longitude":     alert.longitude,
        "image_url":     _image_url(alert.image_path),
        "agent_id":      str(alert.agent_id),
        "forest_id":     str(alert.forest_id),
        "admin_comment": alert.admin_comment,
        "admin_id":      str(alert.admin_id) if alert.admin_id else None,
        "commented_at":  alert.commented_at.isoformat() if alert.commented_at else None,
        "created_at":    alert.created_at.isoformat(),
        "updated_at":    alert.updated_at.isoformat() if alert.updated_at else None,
    }


async def _get_forest_centroid(forest_id: UUID) -> tuple[float, float]:
    """
    Récupère le centroïde de la forêt via l'API du forest_ms.
    NE PAS faire de requête SQL directe — forest est dans une autre DB.
    """
    url = f"{FOREST_SERVICE_URL}/api/forests/{forest_id}"
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(url)

        if response.status_code == 404:
            raise HTTPException(
                status_code=400,
                detail="Forêt introuvable — vérifiez l'identifiant.",
            )
        if response.status_code != 200:
            raise HTTPException(
                status_code=400,
                detail="Impossible de contacter le service forêt.",
            )

        data = response.json()
        lat  = data.get("centroid_lat")
        lng  = data.get("centroid_lng")

        if lat is None or lng is None:
            raise HTTPException(
                status_code=400,
                detail="Impossible de localiser l'alerte — la forêt n'a pas de "
                       "coordonnées. Veuillez prendre une photo avec GPS activé.",
            )
        return float(lat), float(lng)

    except httpx.RequestError as e:
        raise HTTPException(
            status_code=503,
            detail=f"Service forêt inaccessible : {e}",
        )


async def _save_image(file: UploadFile) -> str:
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Format non supporté : {file.content_type}. Utilisez JPEG, PNG ou WebP.",
        )
    content = await file.read()
    if len(content) > MAX_SIZE_MB * 1024 * 1024:
        raise HTTPException(status_code=400, detail=f"Image trop lourde (max {MAX_SIZE_MB}MB)")

    ext       = file.filename.rsplit(".", 1)[-1].lower() if "." in file.filename else "jpg"
    filename  = f"{uuid.uuid4()}.{ext}"
    file_path = UPLOAD_DIR / filename
    with open(file_path, "wb") as f:
        f.write(content)
    return f"alerts/{filename}"


# ── CREATE ────────────────────────────────────────────────────

async def create_alert(
    db:       AsyncSession,
    data:     AlertCreate,
    agent_id: UUID,
    image:    Optional[UploadFile] = None,
) -> dict:
    # 1. Résoudre la localisation
    lat, lng = data.latitude, data.longitude

    if lat is None or lng is None:
        # Fallback HTTP vers forest_ms — plus de SQL cross-service
        lat, lng = await _get_forest_centroid(data.forest_id)

    # 2. Sauvegarder l'image
    image_path = None
    if image and image.filename:
        image_path = await _save_image(image)

    # 3. Construire le POINT PostGIS
    geom_wkt = f"SRID=4326;POINT({lng} {lat})"

    # 4. Insérer
    alert = Alert(
        type        = data.type,
        status      = AlertStatus.en_cours,
        description = data.description,
        latitude    = lat,
        longitude   = lng,
        geom        = geom_wkt,
        image_path  = image_path,
        agent_id    = agent_id,
        forest_id   = data.forest_id,
    )
    db.add(alert)
    await db.commit()
    await db.refresh(alert)
    return _alert_to_dict(alert)


# Les autres fonctions restent identiques...
async def get_agent_alerts(db: AsyncSession, agent_id: UUID) -> list[dict]:
    result = await db.execute(
        select(Alert).where(Alert.agent_id == agent_id).order_by(Alert.created_at.desc())
    )
    return [_alert_to_dict(a) for a in result.scalars().all()]


async def get_all_alerts(db: AsyncSession, status: Optional[AlertStatus] = None) -> list[dict]:
    query = select(Alert).order_by(Alert.created_at.desc())
    if status:
        query = query.where(Alert.status == status)
    result = await db.execute(query)
    return [_alert_to_dict(a) for a in result.scalars().all()]


async def get_map_points(db: AsyncSession) -> list[dict]:
    result = await db.execute(
        select(Alert).where(Alert.status != AlertStatus.rejeter).order_by(Alert.created_at.desc())
    )
    alerts = result.scalars().all()
    return [
        {
            "id":         str(a.id),
            "type":       a.type,
            "status":     a.status,
            "latitude":   a.latitude,
            "longitude":  a.longitude,
            "forest_id":  str(a.forest_id),
            "created_at": a.created_at.isoformat(),
        }
        for a in alerts
    ]


async def get_alert_by_id(db: AsyncSession, alert_id: UUID) -> dict:
    result = await db.execute(select(Alert).where(Alert.id == alert_id))
    alert  = result.scalar_one_or_none()
    if not alert:
        raise HTTPException(status_code=404, detail="Alerte introuvable")
    return _alert_to_dict(alert)


async def update_alert_status(
    db: AsyncSession, alert_id: UUID, data: AlertStatusUpdate, admin_id: UUID
) -> dict:
    result = await db.execute(select(Alert).where(Alert.id == alert_id))
    alert  = result.scalar_one_or_none()
    if not alert:
        raise HTTPException(status_code=404, detail="Alerte introuvable")

    alert.status = data.status
    if data.admin_comment is not None:
        alert.admin_comment = data.admin_comment
        alert.admin_id      = admin_id
        alert.commented_at  = datetime.now(timezone.utc)

    await db.commit()
    result2 = await db.execute(select(Alert).where(Alert.id == alert_id))
    alert   = result2.scalar_one_or_none()
    return _alert_to_dict(alert)