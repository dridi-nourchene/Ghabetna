# backend/alert_ms/app/schemas/alert.py

from pydantic import BaseModel
from typing import Optional
from uuid import UUID
from datetime import datetime
from app.models.alert import AlertType, AlertStatus, LocationSource


class AlertCreate(BaseModel):
    type:         AlertType
    description:  Optional[str] = None
    forest_id:    UUID
    incident_lat: Optional[float] = None
    incident_lng: Optional[float] = None
    agent_lat:    Optional[float] = None
    agent_lng:    Optional[float] = None


class AlertStatusUpdate(BaseModel):
    status:             AlertStatus
    supervisor_comment: Optional[str] = None


class ZoneAgent(BaseModel):
    nom:           str
    phone:         str
    parcelle_name: Optional[str] = None

    model_config = {"from_attributes": True}


class AlertDetailResponse(BaseModel):
    # ── Identifiants ──────────────────────────────────
    id:        UUID
    agent_id:  UUID       
    forest_id: UUID       

    # ── Type / Statut en STRING ───────────────────────
    type:   str           
    status: str           

    description: Optional[str] = None

    # ── Agent émetteur ────────────────────────────────
    agent_nom:   Optional[str] = None
    agent_phone: Optional[str] = None

    # ── Forêt (si approximatif) ───────────────────────
    forest_name: Optional[str] = None

    # ── Agents dans la zone ───────────────────────────
    zone_agents: list[ZoneAgent] = []

    # ── Localisation ─────────────────────────────────
    location_source: str         
    incident_lat:    Optional[float] = None
    incident_lng:    Optional[float] = None
    agent_lat:       Optional[float] = None
    agent_lng:       Optional[float] = None

    # ── Média ─────────────────────────────────────────
    image_url: Optional[str] = None

    # ── Superviseur ───────────────────────────────────
    supervisor_comment: Optional[str] = None
    supervisor_id:      Optional[UUID] = None
    commented_at:       Optional[datetime] = None

    # ── Dates ─────────────────────────────────────────
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}



class AlertResponse(BaseModel):
    id:             UUID
    type:           AlertType
    status:         AlertStatus
    description:    Optional[str]
    incident_lat:   Optional[float]
    incident_lng:   Optional[float]
    agent_lat:      Optional[float]
    agent_lng:      Optional[float]
    location_source:    LocationSource
    image_url:          Optional[str]
    agent_id:           UUID
    forest_id:          UUID
    supervisor_comment: Optional[str]
    supervisor_id:      Optional[UUID]
    commented_at:       Optional[datetime]
    created_at:         datetime
    updated_at:         Optional[datetime]

    model_config = {"from_attributes": True}


class AlertMapPoint(BaseModel):
    id:              UUID
    type:            AlertType
    status:          AlertStatus
    incident_lat:    Optional[float]
    incident_lng:    Optional[float]
    location_source: LocationSource
    forest_id:       UUID
    created_at:      datetime