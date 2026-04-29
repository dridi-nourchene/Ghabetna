# backend/forest_ms/app/services/parcelle_service.py
# FIX : même bug syntaxe SQL que forest_service.py

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, text
from fastapi import HTTPException
from uuid import UUID
from typing import Optional

from shapely.geometry import shape, mapping
from geoalchemy2.shape import to_shape, from_shape

from app.models.forest import Forest
from app.models.parcelle import Parcelle
from app.schemas.parcelle import (
    ParcelleCreate, ParcelleUpdate,
    ParcelleFeature, ParcellesGeoJSONCollection,
)


# ── Convertisseurs ────────────────────────────────────────

def _geojson_to_wkb(geojson_dict: dict):
    return from_shape(shape(geojson_dict), srid=4326)


def _wkb_to_geojson(wkb) -> dict:
    return mapping(to_shape(wkb))


def _to_response(p: Parcelle) -> dict:
    return {
        "id":            str(p.id),
        "name":          p.name,
        "forest_id":     str(p.forest_id),
        "geojson":       _wkb_to_geojson(p.geom),
        "area_hectares": p.area_hectares,
        "centroid_lat":  p.centroid_lat,
        "centroid_lng":  p.centroid_lng,
        "created_by":    str(p.created_by),
        "created_at":    p.created_at,
        "updated_at":    p.updated_at,
    }


# ── Calculs spatiaux ──────────────────────────────────────

async def _compute_spatial_fields(
    db: AsyncSession,
    geom_wkb,
) -> tuple[float, float, float]:
    geom_hex = geom_wkb.desc
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


# ── Validation 1 : parcelle dans sa forêt ─────────────────

async def _check_parcelle_within_forest(
    db: AsyncSession,
    geom_wkb,
    forest_id: UUID,
) -> None:
    geom_hex = geom_wkb.desc

    result = await db.execute(
        text("""
            SELECT ST_Within(
                ST_GeomFromWKB(decode(:geom, 'hex'), 4326),
                f.geom
            ) AS is_within
            FROM forests f
            WHERE f.id = CAST(:forest_id AS uuid)
        """),
        {"geom": geom_hex, "forest_id": str(forest_id)},
    )
    row = result.fetchone()

    if row is None:
        raise HTTPException(status_code=404, detail="Forêt parente introuvable")

    if not row.is_within:
        raise HTTPException(
            status_code=409,
            detail="La parcelle dépasse les bordures de sa forêt parente",
        )


# ── Validation 2 : pas de chevauchement entre parcelles ───

async def _check_parcelle_overlap(
    db: AsyncSession,
    geom_wkb,
    forest_id: UUID,
    exclude_id: Optional[UUID] = None,
) -> None:
    """
    FIX : même correction que pour forest_service.
    Deux requêtes séparées selon exclude_id est None ou non.
    """
    geom_hex = geom_wkb.desc

    if exclude_id is None:
        sql = text("""
            SELECT id, name
            FROM parcelles
            WHERE forest_id  = CAST(:forest_id AS uuid)
            AND (
                ST_Overlaps(geom, ST_GeomFromWKB(decode(:geom, 'hex'), 4326))
                OR ST_Contains(geom, ST_GeomFromWKB(decode(:geom, 'hex'), 4326))
                OR ST_Within(geom,  ST_GeomFromWKB(decode(:geom, 'hex'), 4326))
            )
            LIMIT 1
        """)
        result = await db.execute(sql, {
            "geom":      geom_hex,
            "forest_id": str(forest_id),
        })
    else:
        sql = text("""
            SELECT id, name
            FROM parcelles
            WHERE forest_id  = CAST(:forest_id AS uuid)
            AND (
                ST_Overlaps(geom, ST_GeomFromWKB(decode(:geom, 'hex'), 4326))
                OR ST_Contains(geom, ST_GeomFromWKB(decode(:geom, 'hex'), 4326))
                OR ST_Within(geom,  ST_GeomFromWKB(decode(:geom, 'hex'), 4326))
            )
            AND id != CAST(:exclude_id AS uuid)
            LIMIT 1
        """)
        result = await db.execute(sql, {
            "geom":       geom_hex,
            "forest_id":  str(forest_id),
            "exclude_id": str(exclude_id),
        })

    conflict = result.fetchone()
    if conflict:
        raise HTTPException(
            status_code=409,
            detail=f"La parcelle chevauche la parcelle existante : « {conflict.name} »",
        )


# ── CRUD ──────────────────────────────────────────────────

async def create_parcelle(
    db: AsyncSession,
    data: ParcelleCreate,
    user_id: UUID,
) -> dict:
    # 1. Forêt existe ?
    forest_result = await db.execute(
        select(Forest).where(Forest.id == data.forest_id)
    )
    if not forest_result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Forêt introuvable")

    # 2. GeoJSON → WKB
    geom_wkb = _geojson_to_wkb(data.geojson.model_dump())

    # 3. Validations spatiales
    await _check_parcelle_within_forest(db, geom_wkb, data.forest_id)
    await _check_parcelle_overlap(db, geom_wkb, data.forest_id)

    # 4. Calcul spatial
    area_ha, centroid_lat, centroid_lng = await _compute_spatial_fields(db, geom_wkb)

    # 5. Insertion
    parcelle = Parcelle(
        name=data.name,
        forest_id=data.forest_id,
        geom=geom_wkb,
        area_hectares=area_ha,
        centroid_lat=centroid_lat,
        centroid_lng=centroid_lng,
        created_by=user_id,
    )
    db.add(parcelle)
    await db.flush()
    await db.refresh(parcelle)
    return _to_response(parcelle)


async def get_parcelle(db: AsyncSession, parcelle_id: UUID) -> dict:
    result = await db.execute(
        select(Parcelle).where(Parcelle.id == parcelle_id)
    )
    parcelle = result.scalar_one_or_none()
    if not parcelle:
        raise HTTPException(status_code=404, detail="Parcelle introuvable")
    return _to_response(parcelle)


async def list_parcelles(
    db: AsyncSession,
    forest_id: Optional[UUID] = None,
    page: int = 1,
    page_size: int = 20,
    search: Optional[str] = None,
) -> tuple[int, list]:
    query = select(Parcelle)

    if forest_id:
        query = query.where(Parcelle.forest_id == forest_id)
    if search:
        query = query.where(Parcelle.name.ilike(f"%{search}%"))

    count_query = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_query)).scalar_one()

    query = (
        query.order_by(Parcelle.created_at.desc())
             .offset((page - 1) * page_size)
             .limit(page_size)
    )
    parcelles = (await db.execute(query)).scalars().all()

    return total, [_to_response(p) for p in parcelles]


async def update_parcelle(
    db: AsyncSession,
    parcelle_id: UUID,
    data: ParcelleUpdate,
) -> dict:
    result = await db.execute(
        select(Parcelle).where(Parcelle.id == parcelle_id)
    )
    parcelle = result.scalar_one_or_none()
    if not parcelle:
        raise HTTPException(status_code=404, detail="Parcelle introuvable")

    if data.geojson is not None:
        geom_wkb = _geojson_to_wkb(data.geojson.model_dump())
        await _check_parcelle_within_forest(db, geom_wkb, parcelle.forest_id)
        await _check_parcelle_overlap(
            db, geom_wkb, parcelle.forest_id, exclude_id=parcelle_id)

        area_ha, centroid_lat, centroid_lng = await _compute_spatial_fields(db, geom_wkb)
        parcelle.geom          = geom_wkb
        parcelle.area_hectares = area_ha
        parcelle.centroid_lat  = centroid_lat
        parcelle.centroid_lng  = centroid_lng

    if data.name is not None:
        parcelle.name = data.name

    await db.flush()
    await db.refresh(parcelle)
    return _to_response(parcelle)


async def delete_parcelle(db: AsyncSession, parcelle_id: UUID) -> None:
    result = await db.execute(
        select(Parcelle).where(Parcelle.id == parcelle_id)
    )
    parcelle = result.scalar_one_or_none()
    if not parcelle:
        raise HTTPException(status_code=404, detail="Parcelle introuvable")
    await db.delete(parcelle)
    await db.flush()


# ── GeoJSON FeatureCollection ─────────────────────────────

async def get_parcelles_geojson(
    db: AsyncSession,
    forest_id: Optional[UUID] = None,
) -> ParcellesGeoJSONCollection:
    """
    FIX : suppression du filtre Parcelle.status (colonne inexistante).
    """
    query = select(Parcelle)
    if forest_id:
        query = query.where(Parcelle.forest_id == forest_id)

    parcelles = (await db.execute(query)).scalars().all()

    features = [
        ParcelleFeature(
            geometry=_wkb_to_geojson(p.geom),
            properties={
                "id":            str(p.id),
                "name":          p.name,
                "forest_id":     str(p.forest_id),
                "area_hectares": p.area_hectares,
                "centroid_lat":  p.centroid_lat,
                "centroid_lng":  p.centroid_lng,
            },
        )
        for p in parcelles
    ]
    return ParcellesGeoJSONCollection(features=features)