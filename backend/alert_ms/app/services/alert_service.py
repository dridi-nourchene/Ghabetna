import os
import uuid
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

# ── Dossier uploads ───────────────────────────────────────────
UPLOAD_DIR = Path("uploads/alerts")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp"}
MAX_SIZE_MB   = 10


# ── HELPERS ───────────────────────────────────────────────────

def _image_url(image_path: Optional[str]) -> Optional[str]:
    """Construit l'URL publique depuis le chemin relatif."""
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


async def _get_forest_centroid(db: AsyncSession, forest_id: UUID) -> tuple[float, float]:
    """
    Fallback : récupère le centroïde de la forêt depuis forest_ms DB.
    Appelé si l'image n'a pas de coordonnées EXIF.
    Note : forest_ms et alert_ms partagent la même DB PostgreSQL dans notre config.
    """
    result = await db.execute(
        text("SELECT centroid_lat, centroid_lng FROM forests WHERE id = :id"),
        {"id": str(forest_id)},
    )
    row = result.fetchone()
    if not row or row[0] is None:
        raise HTTPException(
            status_code=400,
            detail="Impossible de localiser l'alerte — la forêt n'a pas de coordonnées. "
                   "Veuillez prendre une photo avec GPS activé.",
        )
    return float(row[0]), float(row[1])


async def _save_image(file: UploadFile) -> str:
    """Sauvegarde l'image et retourne le chemin relatif."""
    # Vérifier le type
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Format non supporté : {file.content_type}. "
                   f"Utilisez JPEG, PNG ou WebP.",
        )

    # Vérifier la taille
    content = await file.read()
    if len(content) > MAX_SIZE_MB * 1024 * 1024:
        raise HTTPException(
            status_code=400,
            detail=f"Image trop lourde (max {MAX_SIZE_MB}MB)",
        )

    # Sauvegarder avec nom unique
    ext       = file.filename.rsplit(".", 1)[-1].lower() if "." in file.filename else "jpg"
    filename  = f"{uuid.uuid4()}.{ext}"
    file_path = UPLOAD_DIR / filename

    with open(file_path, "wb") as f:
        f.write(content)

    # Retourner le chemin relatif (alerts/filename.jpg)
    return f"alerts/{filename}"


# ── CREATE ────────────────────────────────────────────────────

async def create_alert(
    db:       AsyncSession,
    data:     AlertCreate,
    agent_id: UUID,
    image:    Optional[UploadFile] = None,
) -> dict:
    """
    Crée une alerte.
    Localisation :
      1. Coords envoyées par Flutter (extraites EXIF côté mobile)
      2. Si absentes → centroïde de la forêt (fallback)
    """
    # 1. Résoudre la localisation
    lat, lng = data.latitude, data.longitude

    if lat is None or lng is None:
        # Fallback — centroïde forêt
        lat, lng = await _get_forest_centroid(db, data.forest_id)

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


# ── GET — agent (ses alertes uniquement) ──────────────────────

async def get_agent_alerts(
    db:       AsyncSession,
    agent_id: UUID,
) -> list[dict]:
    result = await db.execute(
        select(Alert)
        .where(Alert.agent_id == agent_id)
        .order_by(Alert.created_at.desc())
    )
    return [_alert_to_dict(a) for a in result.scalars().all()]


# ── GET — admin (toutes les alertes) ─────────────────────────

async def get_all_alerts(
    db:     AsyncSession,
    status: Optional[AlertStatus] = None,
) -> list[dict]:
    query = select(Alert).order_by(Alert.created_at.desc())
    if status:
        query = query.where(Alert.status == status)
    result = await db.execute(query)
    return [_alert_to_dict(a) for a in result.scalars().all()]


# ── GET — map points (polling admin) ─────────────────────────

async def get_map_points(db: AsyncSession) -> list[dict]:
    """
    Retourne uniquement les alertes non rejetées pour la map.
    Rejetées = ne s'affichent plus sur la map.
    Payload minimal pour le polling (léger).
    """
    result = await db.execute(
        select(Alert)
        .where(Alert.status != AlertStatus.rejeter)
        .order_by(Alert.created_at.desc())
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


# ── GET — détail ──────────────────────────────────────────────

async def get_alert_by_id(db: AsyncSession, alert_id: UUID) -> dict:
    result = await db.execute(
        select(Alert).where(Alert.id == alert_id)
    )
    alert = result.scalar_one_or_none()
    if not alert:
        raise HTTPException(status_code=404, detail="Alerte introuvable")
    return _alert_to_dict(alert)


# ── UPDATE statut + commentaire (admin) ───────────────────────

async def update_alert_status(
    db:       AsyncSession,
    alert_id: UUID,
    data:     AlertStatusUpdate,
    admin_id: UUID,
) -> dict:
    result = await db.execute(
        select(Alert).where(Alert.id == alert_id)
    )
    alert = result.scalar_one_or_none()
    if not alert:
        raise HTTPException(status_code=404, detail="Alerte introuvable")

    # Collecter avant commit
    alert.status = data.status
    if data.admin_comment is not None:
        alert.admin_comment = data.admin_comment
        alert.admin_id      = admin_id
        alert.commented_at  = datetime.now(timezone.utc)

    await db.commit()

    # Relire après commit
    result2 = await db.execute(select(Alert).where(Alert.id == alert_id))
    alert   = result2.scalar_one_or_none()
    return _alert_to_dict(alert)