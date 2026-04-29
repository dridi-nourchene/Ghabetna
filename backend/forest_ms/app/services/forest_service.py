# backend/forest_ms/app/services/forest_service.py
# FIX : syntaxe SQL corrigée — plus de mélange $N / :param
from starlette.responses import JSONResponse, Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, func, text
from fastapi import HTTPException
from uuid import UUID
from typing import Optional

from shapely.geometry import shape, mapping
from geoalchemy2.shape import to_shape, from_shape

from app.models.forest import Forest
from app.schemas.forest import (
    ForestCreate, ForestUpdate,
    ForestFeature, ForestsGeoJSONCollection,
)


# ── Convertisseurs GeoJSON ↔ WKB ─────────────────────────

def _geojson_to_wkb(geojson_dict: dict):
    """GeoJSON dict → WKBElement PostGIS (srid=4326)"""
    shapely_polygon = shape(geojson_dict)
    return from_shape(shapely_polygon, srid=4326)


def _wkb_to_geojson(wkb) -> dict:
    """WKBElement PostGIS → GeoJSON dict"""
    return mapping(to_shape(wkb))


def _to_response(forest: Forest) -> dict:
    return {
        "id":            str(forest.id),
        "name":          forest.name,
        "geojson":       _wkb_to_geojson(forest.geom),
        "area_hectares": forest.area_hectares,
        "centroid_lat":  forest.centroid_lat,
        "centroid_lng":  forest.centroid_lng,
        "created_by":    str(forest.created_by),
        "created_at":    forest.created_at,
        "updated_at":    forest.updated_at,
    }


# ── Calculs spatiaux (aire + centroïde) ───────────────────

async def _compute_spatial_fields(
    db: AsyncSession,
    geom_wkb,
) -> tuple[float, float, float]:
    """
    Calcule aire (hectares) + centroïde via PostGIS.
    FIX : utilise uniquement la syntaxe :param (pas de mélange avec $N)
    """
    geom_hex = geom_wkb.desc

    result = await db.execute(
        text("""
            SELECT
                ST_Area(
                    ST_Transform(
                        ST_GeomFromWKB(decode(:geom, 'hex'), 4326),
                        3857
                    )
                ) / 10000  AS area_ha,
                ST_Y(ST_Centroid(
                    ST_GeomFromWKB(decode(:geom, 'hex'), 4326)
                ))         AS lat,
                ST_X(ST_Centroid(
                    ST_GeomFromWKB(decode(:geom, 'hex'), 4326)
                ))         AS lng
        """),
        {"geom": geom_hex},
    )
    row = result.fetchone()
    return round(row.area_ha, 2), row.lat, row.lng


# ── Validation anti-chevauchement ─────────────────────────

async def _check_forest_overlap(
    db: AsyncSession,
    geom_wkb,
    exclude_id: Optional[UUID] = None,
) -> None:
    """
    FIX CRITIQUE : La requête originale mélangeait la syntaxe asyncpg ($1, $2)
    avec la syntaxe SQLAlchemy (:param). asyncpg voit $2 mais aussi :exclude_id
    → PostgresSyntaxError.

    Solution : utiliser UNIQUEMENT la syntaxe :param de SQLAlchemy text().
    Pour le cas NULL, on utilise CASE WHEN au lieu de IS NULL sur un param mixte.
    """
    geom_hex = geom_wkb.desc

    if exclude_id is None:
        # Pas d'exclusion — requête simple
        sql = text("""
            SELECT id, name
            FROM forests
            WHERE (
                ST_Overlaps(geom, ST_GeomFromWKB(decode(:geom, 'hex'), 4326))
                OR ST_Contains(geom, ST_GeomFromWKB(decode(:geom, 'hex'), 4326))
                OR ST_Within(geom,  ST_GeomFromWKB(decode(:geom, 'hex'), 4326))
            )
            LIMIT 1
        """)
        result = await db.execute(sql, {"geom": geom_hex})
    else:
        # Avec exclusion — on passe l'UUID comme string, cast côté SQL
        sql = text("""
            SELECT id, name
            FROM forests
            WHERE (
                ST_Overlaps(geom, ST_GeomFromWKB(decode(:geom, 'hex'), 4326))
                OR ST_Contains(geom, ST_GeomFromWKB(decode(:geom, 'hex'), 4326))
                OR ST_Within(geom,  ST_GeomFromWKB(decode(:geom, 'hex'), 4326))
            )
            AND id != CAST(:exclude_id AS uuid)
            LIMIT 1
        """)
        result = await db.execute(sql, {
            "geom":       geom_hex,
            "exclude_id": str(exclude_id),
        })

    conflict = result.fetchone()
    if conflict:
        raise HTTPException(
            status_code=409,
            detail=f"Le polygone chevauche la forêt existante : « {conflict.name} »",
        )


# ── CRUD ──────────────────────────────────────────────────

async def create_forest(
    db: AsyncSession,
    data: ForestCreate,
    user_id: UUID,
) -> dict:
    """Crée une nouvelle forêt avec validation anti-chevauchement."""

    # 1. GeoJSON → WKB
    geom_wkb = _geojson_to_wkb(data.geojson.model_dump())

    # 2. Validation chevauchement (pas d'exclude_id lors de la création)
    await _check_forest_overlap(db, geom_wkb)

    # 3. Calcul aire + centroïde
    area_ha, centroid_lat, centroid_lng = await _compute_spatial_fields(db, geom_wkb)

    # 4. Insertion
    forest = Forest(
        name=data.name,
        geom=geom_wkb,
        area_hectares=area_ha,
        centroid_lat=centroid_lat,
        centroid_lng=centroid_lng,
        created_by=user_id,
    )
    db.add(forest)
    await db.flush()
    await db.refresh(forest)
    return _to_response(forest)


async def get_forest(db: AsyncSession, forest_id: UUID) -> dict:
    """Récupère une forêt par son ID."""
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
) -> tuple[int, list]:
    """Liste les forêts avec pagination + filtres optionnels."""

    query = select(Forest)

    if search:
        query = query.where(Forest.name.ilike(f"%{search}%"))

    # COUNT total
    count_query = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_query)).scalar_one()

    # Pagination
    query = (
        query.order_by(Forest.created_at.desc())
             .offset((page - 1) * page_size)
             .limit(page_size)
    )
    forests = (await db.execute(query)).scalars().all()

    return total, [_to_response(f) for f in forests]


async def update_forest(
    db: AsyncSession,
    forest_id: UUID,
    data: ForestUpdate,
) -> dict:
    """Modifie une forêt. Revalide le chevauchement si le polygone change."""

    result = await db.execute(select(Forest).where(Forest.id == forest_id))
    forest = result.scalar_one_or_none()
    if not forest:
        raise HTTPException(status_code=404, detail="Forêt introuvable")

    if data.geojson is not None:
        geom_wkb = _geojson_to_wkb(data.geojson.model_dump())

        # FIX : exclude_id passé correctement
        await _check_forest_overlap(db, geom_wkb, exclude_id=forest_id)

        area_ha, centroid_lat, centroid_lng = await _compute_spatial_fields(db, geom_wkb)
        forest.geom          = geom_wkb
        forest.area_hectares = area_ha
        forest.centroid_lat  = centroid_lat
        forest.centroid_lng  = centroid_lng

    if data.name is not None:
        forest.name = data.name

    await db.flush()
    await db.refresh(forest)
    return _to_response(forest)


async def delete_forest(db: AsyncSession, forest_id: UUID) -> None:
    """Supprime une forêt (cascade → supprime aussi ses parcelles)."""
    result = await db.execute(select(Forest).where(Forest.id == forest_id))
    forest = result.scalar_one_or_none()
    if not forest:
        raise HTTPException(status_code=404, detail="Forêt introuvable")
    await db.delete(forest)
    await db.flush()


# ── GeoJSON FeatureCollection ─────────────────────────────

async def get_forests_geojson(
    db: AsyncSession,
) -> ForestsGeoJSONCollection:
    """
    Retourne toutes les forêts en GeoJSON FeatureCollection.
    FIX : suppression du filtre Forest.status (colonne inexistante).
    """
    result = await db.execute(select(Forest))
    forests = result.scalars().all()

    features = [
        ForestFeature(
            geometry=_wkb_to_geojson(f.geom),
            properties={
                "id":            str(f.id),
                "name":          f.name,
                "area_hectares": f.area_hectares,
                "centroid_lat":  f.centroid_lat,
                "centroid_lng":  f.centroid_lng,
            },
        )
        for f in forests
    ]
    return ForestsGeoJSONCollection(features=features)