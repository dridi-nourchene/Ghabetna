"""
Client HTTP vers forest_ms — résolution du nom de forêt.

AssignmentCache (voir app/models/assignment_cache.py) ne connaît une forêt
que si au moins un agent y est actuellement affecté à une parcelle : une
forêt sans agent assigné n'y a aucune ligne, et son nom resterait vide même
si l'alerte porte bien un forest_id valide. forest_ms, lui, connaît TOUTE
forêt existante — c'est la seule source fiable pour garantir qu'un nom de
forêt est toujours affiché, quelle que soit la précision de localisation de
l'alerte (EXIF, GPS téléphone ou forêt seule).
"""
import httpx

from app.core.config import settings

_TIMEOUT = 10.0


async def get_forest_name(forest_id) -> str | None:
    """forest_id -> nom de la forêt, ou None si introuvable/service injoignable."""
    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            resp = await client.get(
                f"{settings.FOREST_SERVICE_URL}/internal/forests",
                params={"ids": str(forest_id)},
            )
            resp.raise_for_status()
            forests = resp.json()
            return forests[0]["forest_name"] if forests else None
    except Exception as e:
        print(f"[ENRICHMENT] Erreur récupération forest_name pour {forest_id} : {e}")
        return None
