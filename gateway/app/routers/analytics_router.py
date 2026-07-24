import httpx
from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from app.core.config import ANALYTICS_SERVICE_URL

router = APIRouter(prefix="/api/analytics", tags=["Analytics"])


def _headers(request: Request) -> dict:
    headers = {"Content-Type": "application/json"}
    user_id   = getattr(request.state, "user_id",   None)
    user_role = getattr(request.state, "user_role", None)
    if user_id:   headers["X-User-Id"]   = str(user_id)
    if user_role: headers["X-User-Role"] = str(user_role)
    return headers


async def _proxy(request: Request, url: str) -> JSONResponse:
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.get(url, headers=_headers(request), params=request.query_params)
    return JSONResponse(status_code=response.status_code, content=response.json())


@router.get("/alerts-by-forest")
async def alerts_by_forest(request: Request):
    return await _proxy(request, f"{ANALYTICS_SERVICE_URL}/api/analytics/alerts-by-forest")


@router.get("/status-trend")
async def status_trend(request: Request):
    return await _proxy(request, f"{ANALYTICS_SERVICE_URL}/api/analytics/status-trend")


@router.get("/matrix-forest-type")
async def matrix_forest_type(request: Request):
    return await _proxy(request, f"{ANALYTICS_SERVICE_URL}/api/analytics/matrix-forest-type")


@router.get("/top-agents")
async def top_agents(request: Request):
    return await _proxy(request, f"{ANALYTICS_SERVICE_URL}/api/analytics/top-agents")


@router.get("/supervisor-workload")
async def supervisor_workload(request: Request):
    return await _proxy(request, f"{ANALYTICS_SERVICE_URL}/api/analytics/supervisor-workload")