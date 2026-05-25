"""
Gateway — Alert Router
Le gateway injecte X-Forest-Ids pour les routes superviseur :
  - Il interroge forest_service pour récupérer les forêts assignées au superviseur
  - Il passe la liste JSON dans le header X-Forest-Ids vers alert_ms
"""
import json
import httpx
from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse, Response

from app.core.config import ALERT_SERVICE_URL, FOREST_SERVICE_URL

router = APIRouter(tags=["Alertes"])


def _base_headers(request: Request) -> dict:
    """Headers utilisateur injectés par l'auth middleware."""
    headers = {}
    user_id    = getattr(request.state, "user_id",    None)
    user_role  = getattr(request.state, "user_role",  None)
    user_email = getattr(request.state, "user_email", None)
    if user_id:    headers["X-User-Id"]    = str(user_id)
    if user_role:  headers["X-User-Role"]  = str(user_role)
    if user_email: headers["X-User-Email"] = str(user_email)
    return headers


async def _get_supervisor_forest_ids(supervisor_id: str, auth_header: str) -> list[str]:
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                f"{FOREST_SERVICE_URL}/api/forests/",
                headers={
                    "Authorization": auth_header,
                    "X-User-Id":    supervisor_id,
                    "X-User-Role":  "supervisor",
                },
                params={"page_size": 100},
            )
            if response.status_code != 200:
                return []
            data = response.json()
            forests = data.get("items", [])
            # Normaliser les deux côtés en lowercase pour la comparaison
            supervisor_id_lower = supervisor_id.lower()
            return [
                f["id"] for f in forests
                if str(f.get("superviseur_id", "")).lower() == supervisor_id_lower
            ]
    except Exception as e:
        print(f"[GATEWAY] Erreur _get_supervisor_forest_ids: {e}")
        return []


async def _proxy_json(request: Request, url: str, extra_headers: dict | None = None) -> Response:
    async with httpx.AsyncClient(timeout=90.0) as client:
        body = await request.body()
        headers = {
            "Content-Type": "application/json",
            **_base_headers(request),
        }
        if extra_headers:
            headers.update(extra_headers)
        response = await client.request(
            method  = request.method,
            url     = url,
            headers = headers,
            content = body,
            params  = request.query_params,
        )
    if not response.content:
        return Response(status_code=response.status_code)
    return JSONResponse(status_code=response.status_code, content=response.json())


async def _proxy_multipart(request: Request, url: str) -> Response:
    async with httpx.AsyncClient(timeout=60.0) as client:
        body = await request.body()
        response = await client.request(
            method  = request.method,
            url     = url,
            headers = {
                "Content-Type": request.headers.get("Content-Type", ""),
                **_base_headers(request),
            },
            content = body,
            params  = request.query_params,
        )
    if not response.content:
        return Response(status_code=response.status_code)
    return JSONResponse(status_code=response.status_code, content=response.json())


async def _supervisor_headers(request: Request) -> dict:
    """Injecte X-Forest-Ids en récupérant les forêts du superviseur."""
    supervisor_id = str(getattr(request.state, "user_id", ""))
    auth_header   = request.headers.get("Authorization", "")
    forest_ids    = await _get_supervisor_forest_ids(supervisor_id, auth_header)
    return {"X-Forest-Ids": json.dumps(forest_ids)}


# ── Agent ─────────────────────────────────────────────────────

@router.post("/api/alerts/")
async def create_alert(request: Request):
    return await _proxy_multipart(request, f"{ALERT_SERVICE_URL}/api/alerts/")


@router.get("/api/alerts/mine")
async def get_my_alerts(request: Request):
    return await _proxy_json(request, f"{ALERT_SERVICE_URL}/api/alerts/mine")


# ── Supervisor ────────────────────────────────────────────────

@router.get("/api/alerts/supervisor/map")
async def get_supervisor_map(request: Request):
    """Carte pour le superviseur — injecte X-Forest-Ids."""
    extra = await _supervisor_headers(request)
    return await _proxy_json(
        request, f"{ALERT_SERVICE_URL}/api/alerts/supervisor/map", extra
    )


@router.get("/api/alerts/supervisor")
async def get_supervisor_alerts(request: Request):
    """Liste des alertes du superviseur — injecte X-Forest-Ids."""
    extra = await _supervisor_headers(request)
    return await _proxy_json(
        request, f"{ALERT_SERVICE_URL}/api/alerts/supervisor", extra
    )


@router.patch("/api/alerts/{alert_id}/status")
async def update_status(alert_id: str, request: Request):
    """Mise à jour statut — superviseur, injecte X-Forest-Ids."""
    extra = await _supervisor_headers(request)
    return await _proxy_json(
        request, f"{ALERT_SERVICE_URL}/api/alerts/{alert_id}/status", extra
    )


# ── Commun ────────────────────────────────────────────────────

@router.get("/api/alerts/{alert_id}")
async def get_alert(alert_id: str, request: Request):
    return await _proxy_json(request, f"{ALERT_SERVICE_URL}/api/alerts/{alert_id}")