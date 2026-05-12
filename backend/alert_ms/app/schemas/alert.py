from pydantic import BaseModel, Field
from typing import Optional
from uuid import UUID
from datetime import datetime
from app.models.alert import AlertType, AlertStatus


# ── Création (multipart — les champs non-fichier) ─────────────
class AlertCreate(BaseModel):
    type:        AlertType
    description: Optional[str] = None
    forest_id:   UUID
    # Coords extraites côté Flutter depuis EXIF ou GPS
    # Si absentes → le service utilise le centroïde de la forêt
    latitude:    Optional[float] = None
    longitude:   Optional[float] = None


# ── Mise à jour statut + commentaire (admin) ──────────────────
class AlertStatusUpdate(BaseModel):
    status:        AlertStatus
    admin_comment: Optional[str] = None


# ── Réponse complète ──────────────────────────────────────────
class AlertResponse(BaseModel):
    id:            UUID
    type:          AlertType
    status:        AlertStatus
    description:   Optional[str]
    latitude:      float
    longitude:     float
    image_url:     Optional[str]   # URL publique construite par le service
    agent_id:      UUID
    forest_id:     UUID
    admin_comment: Optional[str]
    admin_id:      Optional[UUID]
    commented_at:  Optional[datetime]
    created_at:    datetime
    updated_at:    Optional[datetime]

    model_config = {"from_attributes": True}


# ── Réponse légère pour la map (polling) ──────────────────────
class AlertMapPoint(BaseModel):
    id:        UUID
    type:      AlertType
    status:    AlertStatus
    latitude:  float
    longitude: float
    forest_id: UUID
    created_at: datetime