import uuid
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID
from typing import Optional

from fastapi import HTTPException, UploadFile
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.alert import Alert, AlertStatus, LocationSource
from app.models.assignment_cache import AssignmentCache
from app.schemas.alert import AlertCreate, AlertStatusUpdate
from app.core.config import settings

UPLOAD_DIR = Path("uploads/alerts")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp"}
MAX_SIZE_MB   = 10


def _image_url(image_path: Optional[str]) -> Optional[str]:
    if not image_path:
        return None
    base = settings.BASE_URL.rstrip("/")
    return f"{base}/uploads/{image_path}"


# ── HELPERS SQL LOCAUX ───────────────────────────────────

async def _get_agent_info(
    db:       AsyncSession,
    agent_id: UUID,
) -> dict:
    """Récupère nom + phone de l'agent depuis le cache local."""
    result = await db.execute(
        select(AssignmentCache).where(
            AssignmentCache.agent_id == agent_id
        )
    )
    agent = result.scalar_one_or_none()
    if agent:
        return {
            "nom":   agent.agent_nom   or "",
            "phone": agent.agent_phone or "",
        }
    return {}


async def _get_zone_agents(
    db:        AsyncSession,
    forest_id: UUID,
    exclude_agent_id: Optional[UUID] = None,  # ← NOUVEAU : exclure agent émetteur
) -> list[dict]:
    """Récupère tous les agents affectés dans une forêt (sauf l'agent émetteur)."""
    result = await db.execute(
        select(AssignmentCache).where(
            AssignmentCache.forest_id == forest_id
        )
    )
    agents = result.scalars().all()
    
    return [
        {
            "user_id": str(a.agent_id),  # ← AJOUTER pour identifier l'agent
            "nom":     a.agent_nom   or "",
            "phone":   a.agent_phone or "",
        }
        for a in agents
        if exclude_agent_id is None or a.agent_id != exclude_agent_id  # ← EXCLURE
    ]


async def _get_forest_name(
    db:        AsyncSession,
    forest_id: UUID,
) -> Optional[str]:
    """Récupère le nom de la forêt depuis le cache local."""
    result = await db.execute(
        select(AssignmentCache).where(
            AssignmentCache.forest_id == forest_id
        ).limit(1)
    )
    row = result.scalar_one_or_none()
    if row and row.forest_name:
        return row.forest_name
    return None

async def _get_zone_agents_enriched(
    db:        AsyncSession,
    forest_id: UUID,
    exclude_parcelle_id: Optional[UUID] = None,
) -> list[dict]:
    """
    Récupère tous les agents affectés dans une forêt avec leurs infos enrichies.

    """
    result = await db.execute(
        select(AssignmentCache).where(
            AssignmentCache.forest_id == forest_id
        )
    )
    agents = result.scalars().all()
    
    agents_list = []
    for a in agents:
        # Si on a un exclude_parcelle_id et que l'agent y est, skip
        if exclude_parcelle_id and a.parcelle_id == exclude_parcelle_id:
            continue
        
        # Si agent n'a pas de nom (corruption), skip
        if not a.agent_nom:
            continue
        
        agent_dict = {
            "nom": a.agent_nom or "",
            "phone": a.agent_phone or "",
        }
        
        # Ajouter parcelle_name si elle existe
        if a.parcelle_name:
            agent_dict["parcelle_name"] = a.parcelle_name
        
        agents_list.append(agent_dict)
    
    return agents_list


# ── DICT ENRICHI ─────────────────────────────────────────

async def _alert_to_dict(
    alert: Alert,
    db:    AsyncSession,
) -> dict:
    """
    Construit la réponse enrichie avec :
    - agent_nom / agent_phone : infos agent émetteur
    - forest_name : nom forêt si localisation approximative
    - zone_agents : agents dans la zone enrichis avec nom, phone, parcelle_name
    """
    # 1. Infos agent émetteur
    agent_info = await _get_agent_info(db, alert.agent_id)

    # 2. Forest name (seulement si approximatif)
    forest_name = None
    if alert.location_source in (
        LocationSource.forest_only,
        LocationSource.agent_gps,
    ):
        # Récupérer forest_name depuis AssignmentCache
        result = await db.execute(
            select(AssignmentCache)
            .where(AssignmentCache.forest_id == alert.forest_id)
            .limit(1)
        )
        cache_row = result.scalar_one_or_none()
        if cache_row:
            forest_name = cache_row.forest_name

    # 3. Agents de la zone
    # Si EXIF (position exacte) → exclure les agents de la même parcelle
    # Si forest_only ou agent_gps → tous les agents de la forêt
    exclude_parcelle = None
    if alert.location_source == LocationSource.exif:
        # On n'a pas la parcelle_id directement dans Alert
        # Donc on va chercher via AssignmentCache l'agent pour trouver sa parcelle
        result = await db.execute(
            select(AssignmentCache)
            .where(AssignmentCache.agent_id == alert.agent_id)
        )
        agent_assignment = result.scalar_one_or_none()
        if agent_assignment:
            exclude_parcelle = agent_assignment.parcelle_id
    
    zone_agents = await _get_zone_agents_enriched(
        db, 
        alert.forest_id,
        exclude_parcelle_id=exclude_parcelle
    )
    return {
        "id":                 str(alert.id),
        "agent_id":           str(alert.agent_id),    
        "forest_id":          str(alert.forest_id),   
        "type":               alert.type.value,
        "status":             alert.status.value,
        "description":        alert.description,
        "agent_nom":          agent_info.get("nom"),
        "agent_phone":        agent_info.get("phone"),
        "forest_name":        forest_name,
        "zone_agents":        zone_agents,
        "location_source":    alert.location_source.value,
        "incident_lat":       alert.incident_lat,     
        "incident_lng":       alert.incident_lng,  
        "agent_lat":          alert.agent_lat,        
        "agent_lng":          alert.agent_lng,        
        "image_url":          _image_url(alert.image_path),
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


# ── CREATE ────────────────────────────────────────────────

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
    return await _alert_to_dict(alert, db)


# ── GET AGENT ALERTS ──────────────────────────────────────

async def get_agent_alerts(
    db:       AsyncSession,
    agent_id: UUID,
) -> list[dict]:
    result = await db.execute(
        select(Alert)
        .where(Alert.agent_id == agent_id)
        .order_by(Alert.created_at.desc())
    )
    results = []
    for a in result.scalars().all():
        results.append(await _alert_to_dict(a, db))
    return results


# ── GET SUPERVISOR ALERTS ─────────────────────────────────

async def get_supervisor_alerts(
    db:            AsyncSession,
    supervisor_id: UUID,
    forest_ids:    list[UUID],
    status:        Optional[AlertStatus] = None,
) -> list[dict]:
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
    results = []
    for a in result.scalars().all():
        results.append(await _alert_to_dict(a, db))
    return results


# ── GET MAP POINTS ────────────────────────────────────────

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
            "type":            a.type.value,
            "status":          a.status.value,
            "incident_lat":    a.incident_lat,
            "incident_lng":    a.incident_lng,
            "location_source": a.location_source.value,
            "forest_id":       str(a.forest_id),
            "created_at":      a.created_at.isoformat(),
        }
        for a in result.scalars().all()
    ]


async def get_map_points(db: AsyncSession) -> list[dict]:
    result = await db.execute(
        select(Alert)
        .where(Alert.status != AlertStatus.rejeter)
        .order_by(Alert.created_at.desc())
    )
    return [
        {
            "id":              str(a.id),
            "type":            a.type.value,
            "status":          a.status.value,
            "incident_lat":    a.incident_lat,
            "incident_lng":    a.incident_lng,
            "location_source": a.location_source.value,
            "forest_id":       str(a.forest_id),
            "created_at":      a.created_at.isoformat(),
        }
        for a in result.scalars().all()
    ]


# ── GET BY ID ─────────────────────────────────────────────

async def get_alert_by_id(
    db:       AsyncSession,
    alert_id: UUID,
) -> dict:
    result = await db.execute(
        select(Alert).where(Alert.id == alert_id)
    )
    alert = result.scalar_one_or_none()
    if not alert:
        raise HTTPException(status_code=404, detail="Alerte introuvable")
    return await _alert_to_dict(alert, db)


# ── UPDATE STATUS ─────────────────────────────────────────

async def update_alert_status(
    db:            AsyncSession,
    alert_id:      UUID,
    data:          AlertStatusUpdate,
    supervisor_id: UUID,
    forest_ids:    list[UUID],
) -> dict:
    result = await db.execute(
        select(Alert).where(Alert.id == alert_id)
    )
    alert = result.scalar_one_or_none()
    if not alert:
        raise HTTPException(status_code=404, detail="Alerte introuvable")

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
    result2 = await db.execute(
        select(Alert).where(Alert.id == alert_id)
    )
    return await _alert_to_dict(result2.scalar_one(), db)