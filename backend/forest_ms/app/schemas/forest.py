from pydantic import BaseModel, Field, field_validator
from typing import Optional, List
from uuid import UUID
from datetime import datetime



# ── GeoJSON Polygon ───────────────────────────────────────
# Format : { "type": "Polygon", "coordinates": [[ [lng, lat], ... ]] }
class GeoJSONPolygon(BaseModel):
    type: str = "Polygon"
    coordinates: List[List[List[float]]]

    @field_validator("type")
    @classmethod
    def must_be_polygon(cls, v):
        if v != "Polygon":
            raise ValueError("Le type doit être 'Polygon'")
        return v

    @field_validator("coordinates")
    @classmethod
    def validate_coordinates(cls, v):
        if not v or len(v) == 0:
            raise ValueError("Le polygone doit avoir au moins un ring")

        ring = v[0]

        if len(ring) < 4:
            raise ValueError("Le ring doit avoir au moins 4 points")

        if ring[0] != ring[-1]:
            raise ValueError("Le polygone doit être fermé (premier point == dernier point)")

        for point in ring:
            if len(point) != 2:
                raise ValueError("Chaque point doit avoir [longitude, latitude]")

        return v


# ── CREATE ────────────────────────────────────────────────
class ForestCreate(BaseModel):
    name:            str            = Field(..., min_length=2, max_length=255)
    geojson:         GeoJSONPolygon
   


# ── UPDATE ────────────────────────────────────────────────
class ForestUpdate(BaseModel):
    name:            Optional[str]            = Field(None, min_length=2, max_length=255)
    geojson:         Optional[GeoJSONPolygon] = None


# ── RESPONSE ──────────────────────────────────────────────
class ForestResponse(BaseModel):
    id:              UUID
    name:            str
    geojson:         dict
    area_hectares:   Optional[float]
    centroid_lat:    Optional[float]
    centroid_lng:    Optional[float]
    created_by:      UUID
    created_at:      datetime
    updated_at:      Optional[datetime]

    model_config = {"from_attributes": True}


# ── GEOJSON FEATURE (pour flutter_map) ───────────────────
class ForestFeature(BaseModel):
    type:       str = "Feature"
    geometry:   dict
    properties: dict


class ForestsGeoJSONCollection(BaseModel):
    type:     str              = "FeatureCollection"
    features: List[ForestFeature]


# ── PAGINATION ────────────────────────────────────────────
class PaginatedForests(BaseModel):
    total:     int
    page:      int
    page_size: int
    items:     List[ForestResponse]