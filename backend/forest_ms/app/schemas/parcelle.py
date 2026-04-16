from pydantic import BaseModel, Field, field_validator
from typing import Optional, List
from uuid import UUID
from datetime import datetime

from app.schemas.forest import GeoJSONPolygon



# ── CREATE ────────────────────────────────────────────────
class ParcelleCreate(BaseModel):
    name:      str            = Field(..., min_length=2, max_length=255)
    forest_id: UUID
    geojson:   GeoJSONPolygon


# ── UPDATE ────────────────────────────────────────────────
class ParcelleUpdate(BaseModel):
    name:   Optional[str]            = Field(None, min_length=2, max_length=255)
    geojson: Optional[GeoJSONPolygon] = None


# ── RESPONSE ──────────────────────────────────────────────
class ParcelleResponse(BaseModel):
    id:            UUID
    name:          str
    forest_id:     UUID
    geojson:       dict
    area_hectares: Optional[float]
    centroid_lat:  Optional[float]
    centroid_lng:  Optional[float]
    created_by:    UUID
    created_at:    datetime
    updated_at:    Optional[datetime]

    model_config = {"from_attributes": True}


# ── GEOJSON FEATURE (pour flutter_map) ───────────────────
class ParcelleFeature(BaseModel):
    type:       str = "Feature"
    geometry:   dict
    properties: dict


class ParcellesGeoJSONCollection(BaseModel):
    type:     str               = "FeatureCollection"
    features: List[ParcelleFeature]


# ── PAGINATION ────────────────────────────────────────────
class PaginatedParcelles(BaseModel):
    total:     int
    page:      int
    page_size: int
    items:     List[ParcelleResponse]