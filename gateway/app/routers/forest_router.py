import httpx
from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from starlette.responses import JSONResponse, Response
from app.core.config import FOREST_SERVICE_URL

router = APIRouter(tags=["Forests & Parcelles"])


async def _proxy(request: Request, url: str) -> Response:
    async with httpx.AsyncClient() as client:
        body = await request.body()

        headers = {
            "Content-Type":  "application/json",
            "Authorization": request.headers.get("Authorization", ""),
            "X-User-Id":     getattr(request.state, "user_id",   ""),
            "X-User-Role":   getattr(request.state, "user_role",  ""),
            "X-User-Email":  getattr(request.state, "user_email", ""),
        }

        response = await client.request(
            method  = request.method,
            url     = url,
            headers = headers,
            content = body,
            params  = request.query_params,
        )

    # ✅ Body vide = 204 No Content (DELETE typiquement)
    if not response.content:
        return Response(status_code=response.status_code)


    return JSONResponse(
        status_code = response.status_code,
        content     = response.json(),
    )


# ══════════════════════════════════════════════════════════
#  FORESTS
# ══════════════════════════════════════════════════════════

@router.post("/api/forests/")
async def create_forest(request: Request):
    return await _proxy(request, f"{FOREST_SERVICE_URL}/api/forests/")

@router.get("/api/forests/geojson")
async def get_forests_geojson(request: Request):
    return await _proxy(request, f"{FOREST_SERVICE_URL}/api/forests/geojson")

@router.get("/api/forests/")
async def list_forests(request: Request):
    return await _proxy(request, f"{FOREST_SERVICE_URL}/api/forests/")

@router.get("/api/forests/{forest_id}")
async def get_forest(forest_id: str, request: Request):
    return await _proxy(request, f"{FOREST_SERVICE_URL}/api/forests/{forest_id}")

@router.put("/api/forests/{forest_id}")
async def update_forest(forest_id: str, request: Request):
    return await _proxy(request, f"{FOREST_SERVICE_URL}/api/forests/{forest_id}")

@router.delete("/api/forests/{forest_id}")
async def delete_forest(forest_id: str, request: Request):
    return await _proxy(request, f"{FOREST_SERVICE_URL}/api/forests/{forest_id}")


# ══════════════════════════════════════════════════════════
#  PARCELLES
# ══════════════════════════════════════════════════════════

@router.post("/api/parcelles/")
async def create_parcelle(request: Request):
    return await _proxy(request, f"{FOREST_SERVICE_URL}/api/parcelles/")

@router.get("/api/parcelles/geojson")
async def get_parcelles_geojson(request: Request):
    return await _proxy(request, f"{FOREST_SERVICE_URL}/api/parcelles/geojson")

@router.get("/api/parcelles/")
async def list_parcelles(request: Request):
    return await _proxy(request, f"{FOREST_SERVICE_URL}/api/parcelles/")

@router.get("/api/parcelles/{parcelle_id}")
async def get_parcelle(parcelle_id: str, request: Request):
    return await _proxy(request, f"{FOREST_SERVICE_URL}/api/parcelles/{parcelle_id}")

@router.put("/api/parcelles/{parcelle_id}")
async def update_parcelle(parcelle_id: str, request: Request):
    return await _proxy(request, f"{FOREST_SERVICE_URL}/api/parcelles/{parcelle_id}")

@router.delete("/api/parcelles/{parcelle_id}")
async def delete_parcelle(parcelle_id: str, request: Request):
    return await _proxy(request, f"{FOREST_SERVICE_URL}/api/parcelles/{parcelle_id}")