from pydantic import BaseModel
from typing import Optional
from uuid import UUID
from datetime import datetime
from app.models.alert import AlertType, AlertStatus, LocationSource


class AlertCreate(BaseModel):
    type:        AlertType
    description: Optional[str] = None
    forest_id:   UUID

    # Depuis EXIF photo
    incident_lat: Optional[float] = None
    incident_lng: Optional[float] = None

    # Depuis GPS téléphone
    agent_lat:    Optional[float] = None
    agent_lng:    Optional[float] = None


class AlertStatusUpdate(BaseModel):
    status:        AlertStatus
    admin_comment: Optional[str] = None


class AlertResponse(BaseModel):
    id:             UUID
    type:           AlertType
    status:         AlertStatus
    description:    Optional[str]

    # Localisation incident
    incident_lat:   Optional[float]
    incident_lng:   Optional[float]

    # Localisation agent
    agent_lat:      Optional[float]
    agent_lng:      Optional[float]

    location_source: LocationSource
    image_url:       Optional[str]
    agent_id:        UUID
    forest_id:       UUID
    admin_comment:   Optional[str]
    admin_id:        Optional[UUID]
    commented_at:    Optional[datetime]
    created_at:      datetime
    updated_at:      Optional[datetime]

    model_config = {"from_attributes": True}


class AlertMapPoint(BaseModel):
    id:             UUID
    type:           AlertType
    status:         AlertStatus
    incident_lat:   Optional[float]
    incident_lng:   Optional[float]
    location_source: LocationSource
    forest_id:      UUID
    created_at:     datetime