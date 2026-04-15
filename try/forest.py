import enum
from pydantic import BaseModel, Field, field_validator
from typing import Optional, List
from uuid import UUID
from datetime import datetime


# ── Status (même que le modèle) ───────────────────────────
class ForestStatus(str, enum.Enum):
    active    = "active"
    inactive  = "inactive"
    protected = "protected"


# ── GeoJSON Polygon ───────────────────────────────────────
# C'est ce que Flutter envoie quand l'admin
# dessine une forêt sur la carte
#
# Format attendu :
# {
#   "type": "Polygon",
#   "coordinates": [
#     [
#       [9.12, 36.45],   ← [longitude, latitude]
#       [9.18, 36.45],
#       [9.18, 36.50],
#       [9.12, 36.50],
#       [9.12, 36.45]    ← même que le 1er point (fermé)
#     ]
#   ]
# }
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
        # doit avoir au moins 1 ring (anneau extérieur)
        if not v or len(v) == 0:
            raise ValueError("Le polygone doit avoir au moins un ring")

        ring = v[0]  # anneau extérieur

        # minimum 4 points (3 points + fermeture)
        if len(ring) < 4:
            raise ValueError("Le ring doit avoir au moins 4 points")

        # premier point == dernier point (polygone fermé)
        if ring[0] != ring[-1]:
            raise ValueError("Le polygone doit être fermé — premier point == dernier point")

        # chaque point doit avoir exactement 2 valeurs [lng, lat]
        for point in ring:
            if len(point) != 2:
                raise ValueError("Chaque point doit avoir [longitude, latitude]")

        return v


class ForestCreate(BaseModel):
    """Schema pour créer une forêt — POST /forests/"""
    name:            str            = Field(..., min_length=2, max_length=255)
    geojson:         GeoJSONPolygon           
    supervisor_cin:   Optional[UUID] = None
    supervisor_name: Optional[str]  = None
    status:          ForestStatus   = ForestStatus.active


class ForestUpdate(BaseModel):
    name:            Optional[str]            = Field(None, min_length=2, max_length=255)
    geojson:         Optional[GeoJSONPolygon] = None
    supervisor_cin:   Optional[UUID]           = None
    supervisor_name: Optional[str]            = None
    status:          Optional[ForestStatus]   = None



# SCHEMAS DE RÉPONSE 

class ForestResponse(BaseModel):
    """Schema de réponse pour une forêt"""
    id:              UUID
    name:            str
    geojson:         dict            # WKB PostGIS sera reconverti en GeoJSON
    area_hectares:   Optional[float]
    centroid_lat:    Optional[float]
    centroid_lng:    Optional[float]
    supervisor_cin:   Optional[UUID]
    supervisor_name: Optional[str]
    status:          ForestStatus
    created_by:      UUID
    created_at:      datetime
    updated_at:      Optional[datetime]

    class Config:
        from_attributes = True   # lit depuis un objet SQLAlchemy


# ── GeoJSON FeatureCollection ─────────────────────────────
# Retourné par GET /forests/geojson
# Flutter_map consomme ce format directement

class ForestFeature(BaseModel):
    """Un polygone forêt + ses propriétés"""
    type:       str  = "Feature"
    geometry:   dict
    properties: dict


class ForestsGeoJSONCollection(BaseModel):
    """Toutes les forêts → prêt pour flutter_map"""
    type:     str               = "FeatureCollection"
    features: List[ForestFeature]


# ── Liste paginée ─────────────────────────────────────────
class PaginatedForests(BaseModel):
    total:     int
    page:      int
    page_size: int
    items:     List[ForestResponse]






"""
GeoJSONPolygon          → valide le polygone dessiné par l'admin
                          vérifie : type, points, fermé, lng/lat

ForestCreate            → données pour CRÉER une forêt (POST)
ForestUpdate            → données pour MODIFIER une forêt (PUT)
                          tout est Optional → modifie seulement ce qui est envoyé

ForestResponse          → ce que l'API retourne après chaque opération
ForestsGeoJSONCollection → toutes les forêts pour flutter_map
PaginatedForests         → liste avec pagination"""