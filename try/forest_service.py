from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, text
from fastapi import HTTPException
from uuid import UUID
from typing import Optional

from shapely.geometry import shape, mapping
from geoalchemy2.shape import to_shape, from_shape

from app.models.forest import Forest, ForestStatus
from app.schemas.forest import *


# 

def _geojson_to_wkb(geojson_dict: dict):
    """Convertit GeoJSON → WKB (format stocké par PostGIS)"""
    shapely_polygon = shape(geojson_dict)        # GeoJSON → Shapely
    return from_shape(shapely_polygon, srid=4326) # Shapely → WKB PostGIS


def _wkb_to_geojson(wkb) -> dict:
    """Convertit WKB (PostGIS) → GeoJSON dict """
    shapely_polygon = to_shape(wkb)   # WKB PostGIS → Shapely
    return mapping(shapely_polygon)   # Shapely → GeoJSON dict


def _to_response(forest: Forest) -> dict:
    """
    Convertit un objet Forest SQLAlchemy
    en dict prêt pour la réponse API
    """
    return {
        "id":              forest.id,
        "name":            forest.name,
        "geojson":         _wkb_to_geojson(forest.geom),
        "area_hectares":   forest.area_hectares,
        "centroid_lat":    forest.centroid_lat,
        "centroid_lng":    forest.centroid_lng,
        "supervisor_cin":   forest.supervisor_cin,
        "supervisor_name": forest.supervisor_name,
        "status":          forest.status,
        "created_by":      forest.created_by,
        "created_at":      forest.created_at,
        "updated_at":      forest.updated_at,
    }

# calcul

async def _compute_spatial_fields(
    db: AsyncSession,
    geom_wkb,
) -> tuple[float, float, float]:
    """
    On convertit WKBElement → hex string
    car asyncpg ne comprend pas WKBElement directement
    """
    # WKBElement → hex string que asyncpg peut envoyer à PostGIS
    geom_hex = geom_wkb.desc  # ← la représentation hex du WKB

    result = await db.execute(
        text("""
            SELECT
                ST_Area(
                    ST_Transform(
                        ST_GeomFromWKB(decode(:geom, 'hex'), 4326),
                        3857
                    )
                ) / 10000 AS area_ha,

                ST_Y(ST_Centroid(
                    ST_GeomFromWKB(decode(:geom, 'hex'), 4326)
                )) AS lat,

                ST_X(ST_Centroid(
                    ST_GeomFromWKB(decode(:geom, 'hex'), 4326)
                )) AS lng
        """),
        {"geom": geom_hex},
    )
    row = result.fetchone()
    return round(row.area_ha, 2), row.lat, row.lng

async def create_forest(
    db: AsyncSession,
    data: ForestCreate,
    user_id: UUID,
) -> dict:
    """Crée une nouvelle forêt"""

    # 1. Convertir GeoJSON → WKB
    geom_wkb = _geojson_to_wkb(data.geojson.dict())

    # 2. Calculer aire + centroïde via PostGIS
    area_ha, centroid_lat, centroid_lng = await _compute_spatial_fields(db, geom_wkb)

    # 3. Créer l'objet Forest
    forest = Forest(
        name=data.name,
        geom=geom_wkb,
        area_hectares=area_ha,
        centroid_lat=centroid_lat,
        centroid_lng=centroid_lng,
        supervisor_cin=data.supervisor_cin,
        supervisor_name=data.supervisor_name,
        status=data.status,
        created_by=user_id,
    )

    # 4. Sauvegarder en base
    db.add(forest)
    await db.flush()   
    await db.refresh(forest) 

    return _to_response(forest)


async def get_forest(db: AsyncSession, forest_id: UUID) -> dict:
    """Récupère une forêt par son ID"""
    result = await db.execute(
        select(Forest).where(Forest.id == forest_id)
    )
    forest = result.scalar_one_or_none()

    if not forest:
        raise HTTPException(status_code=404, detail="Forêt introuvable")

    return _to_response(forest)


async def list_forests(
    db: AsyncSession,
    page: int = 1,
    page_size: int = 20,
    search: Optional[str] = None,
    supervisor_cin: Optional[UUID] = None,
    forest_status: Optional[str] = None,
) -> tuple[int, list]:
    """Liste les forêts avec pagination et filtres"""

    query = select(Forest)

    # Filtres 
    if search:
        query = query.where(
            or_(
                Forest.name.ilike(f"%{search}%"),
                Forest.description.ilike(f"%{search}%"),
            )
        )

    if forest_status:
        query = query.where(Forest.status == forest_status)

    #Total 
    count_result = await db.execute(
        select(Forest).where(query.whereclause)
        if query.whereclause is not None
        else select(Forest)
    )
    total = len(count_result.scalars().all())

    # ── Pagination ────────────────────────────────────────
    query = query.order_by(Forest.created_at.desc())
    query = query.offset((page - 1) * page_size).limit(page_size)

    result = await db.execute(query)
    forests = result.scalars().all()

    return total, [_to_response(f) for f in forests]


async def update_forest(
    db: AsyncSession,
    forest_id: UUID,
    data: ForestUpdate,
) -> dict:
    """Modifie une forêt existante"""

    # 1. Récupérer la forêt
    result = await db.execute(
        select(Forest).where(Forest.id == forest_id)
    )
    forest = result.scalar_one_or_none()
    if not forest:
        raise HTTPException(status_code=404, detail="Forêt introuvable")

    # 2. Si le polygone change → recalculer aire + centroïde
    if data.geojson is not None:
        geom_wkb = _geojson_to_wkb(data.geojson.dict())
        area_ha, centroid_lat, centroid_lng = await _compute_spatial_fields(db, geom_wkb)
        forest.geom          = geom_wkb
        forest.area_hectares = area_ha
        forest.centroid_lat  = centroid_lat
        forest.centroid_lng  = centroid_lng

    # 3. Mettre à jour les autres champs si fournis
    if data.name            is not None: forest.name            = data.name
    if data.supervisor_cin  is not None: forest.supervisor_cin  = data.supervisor_cin
    if data.supervisor_name is not None: forest.supervisor_name = data.supervisor_name
    if data.status          is not None: forest.status          = data.status

    await db.flush()
    await db.refresh(forest)
    return _to_response(forest)


async def delete_forest(db: AsyncSession, forest_id: UUID) -> None:
    """Supprime une forêt"""
    result = await db.execute(
        select(Forest).where(Forest.id == forest_id)
    )
    forest = result.scalar_one_or_none()
    if not forest:
        raise HTTPException(status_code=404, detail="Forêt introuvable")

    await db.delete(forest)
    await db.flush()


# GEOJSON FEATURE COLLECTION

async def get_forests_geojson(
    db: AsyncSession,
) -> ForestsGeoJSONCollection:
    """Retourne toutes les forêts actives en GeoJSON FeatureCollection.
    Flutter_map consomme ce format directement pour afficher les polygones sur la carte.
    """
    result = await db.execute(
        select(Forest).where(Forest.status == ForestStatus.active)
    )
    forests = result.scalars().all()

    features = [
        ForestFeature(
            geometry=_wkb_to_geojson(f.geom),
            properties={
                "id":              str(f.id),
                "name":            f.name,
                "area_hectares":   f.area_hectares,
                "supervisor_cin":  f.supervisor_cin,
                "supervisor_name": f.supervisor_name,
                "status":          f.status,
                "centroid_lat":    f.centroid_lat,
                "centroid_lng":    f.centroid_lng,
            },
        )
        for f in forests
    ]

    return ForestsGeoJSONCollection(features=features)
