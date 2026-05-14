import httpx
from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse, Response

ALERT_SERVICE_URL = "http://localhost:8003"

router = APIRouter(tags=["Alertes"])


def _injected_headers(request: Request) -> dict:
    return {
        "X-User-Id":    getattr(request.state, "user_id",    ""),
        "X-User-Role":  getattr(request.state, "user_role",  ""),
        "X-User-Email": getattr(request.state, "user_email", ""),
    }


async def _proxy_json(request: Request, url: str) -> Response:
    """Proxy pour les requêtes JSON classiques."""
    async with httpx.AsyncClient(timeout=90.0) as client:
        body = await request.body()
        response = await client.request(
            method  = request.method,
            url     = url,
            headers = {
                "Content-Type": "application/json",
                **_injected_headers(request),
            },
            content = body,
            params  = request.query_params,
        )
    if not response.content:
        return Response(status_code=response.status_code)
    return JSONResponse(status_code=response.status_code, content=response.json())


async def _proxy_multipart(request: Request, url: str) -> Response:
    """
    Proxy pour les requêtes multipart/form-data (upload image).
    On retransmet le body brut avec le bon Content-Type.
    """
    async with httpx.AsyncClient(timeout=60.0) as client:
        body = await request.body()
        response = await client.request(
            method  = request.method,
            url     = url,
            headers = {
                "Content-Type": request.headers.get("Content-Type", ""),
                **_injected_headers(request),
            },
            content = body,
            params  = request.query_params,
        )
    if not response.content:
        return Response(status_code=response.status_code)
    return JSONResponse(status_code=response.status_code, content=response.json())


# ── Routes ────────────────────────────────────────────────────

@router.post("/api/alerts/")
async def create_alert(request: Request):
    """Création d'alerte — multipart avec image."""
    return await _proxy_multipart(request, f"{ALERT_SERVICE_URL}/api/alerts/")


@router.get("/api/alerts/map")
async def get_map_points(request: Request):
    """Polling map admin — appelé toutes les 30s."""
    return await _proxy_json(request, f"{ALERT_SERVICE_URL}/api/alerts/map")


@router.get("/api/alerts/mine")
async def get_my_alerts(request: Request):
    return await _proxy_json(request, f"{ALERT_SERVICE_URL}/api/alerts/mine")


@router.get("/api/alerts/")
async def get_all_alerts(request: Request):
    return await _proxy_json(request, f"{ALERT_SERVICE_URL}/api/alerts/")


@router.get("/api/alerts/{alert_id}")
async def get_alert(alert_id: str, request: Request):
    return await _proxy_json(request, f"{ALERT_SERVICE_URL}/api/alerts/{alert_id}")


@router.patch("/api/alerts/{alert_id}/status")
async def update_status(alert_id: str, request: Request):
    return await _proxy_json(
        request, f"{ALERT_SERVICE_URL}/api/alerts/{alert_id}/status"
    )