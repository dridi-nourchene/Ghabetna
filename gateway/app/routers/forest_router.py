import httpx
from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from starlette.responses import Response
from app.core.config import FOREST_SERVICE_URL

router = APIRouter(tags=["Forests, Parcelles & Affectations"])


async def _proxy(request: Request, url: str) -> Response:
    async with httpx.AsyncClient() as client:
        body = await request.body()
        
        # Ne pas envoyer les headers vides
        headers = {
            "Content-Type":  "application/json",
            "Authorization": request.headers.get("Authorization", ""),
        }
        user_id    = getattr(request.state, "user_id",    None)
        user_role  = getattr(request.state, "user_role",  None)
        user_email = getattr(request.state, "user_email", None)
        
        if user_id:    headers["X-User-Id"]    = str(user_id)
        if user_role:  headers["X-User-Role"]  = str(user_role)
        if user_email: headers["X-User-Email"] = str(user_email)
        
        response = await client.request(
            method  = request.method,
            url     = url,
            headers = headers,
            content = body,
            params  = request.query_params,
        )
    if not response.content:
        return Response(status_code=response.status_code)
    return JSONResponse(
        status_code=response.status_code,
        content=response.json(),
    )

# ══════════════════════════════════════════════════════════════
#  FORESTS
# ══════════════════════════════════════════════════════════════

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


# ── Superviseur ────────────────────────────────────────────────

@router.put("/api/forests/{forest_id}/superviseur")
async def assign_superviseur(forest_id: str, request: Request):
    return await _proxy(request, f"{FOREST_SERVICE_URL}/api/forests/{forest_id}/superviseur")

@router.delete("/api/forests/{forest_id}/superviseur")
async def remove_superviseur(forest_id: str, request: Request):
    return await _proxy(request, f"{FOREST_SERVICE_URL}/api/forests/{forest_id}/superviseur")

@router.get("/api/forests/{forest_id}/superviseur")
async def get_forest_superviseur(forest_id: str, request: Request):
    return await _proxy(request, f"{FOREST_SERVICE_URL}/api/forests/{forest_id}/superviseur")


# ══════════════════════════════════════════════════════════════
#  PARCELLES
# ══════════════════════════════════════════════════════════════

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


# ── Agents ────────────────────────────────────────────────────

@router.put("/api/parcelles/{parcelle_id}/agents")
async def assign_agent(parcelle_id: str, request: Request):
    return await _proxy(request, f"{FOREST_SERVICE_URL}/api/parcelles/{parcelle_id}/agents")

@router.put("/api/parcelles/{parcelle_id}/agents/reassign")
async def reassign_agent(parcelle_id: str, request: Request):
    return await _proxy(request, f"{FOREST_SERVICE_URL}/api/parcelles/{parcelle_id}/agents/reassign")

@router.delete("/api/parcelles/{parcelle_id}/agents/{agent_id}")
async def remove_agent(parcelle_id: str, agent_id: str, request: Request):
    return await _proxy(request, f"{FOREST_SERVICE_URL}/api/parcelles/{parcelle_id}/agents/{agent_id}")

@router.get("/api/parcelles/{parcelle_id}/agents")
async def get_parcelle_agents(parcelle_id: str, request: Request):
    return await _proxy(request, f"{FOREST_SERVICE_URL}/api/parcelles/{parcelle_id}/agents")


# ══════════════════════════════════════════════════════════════
#  LISTES AFFECTATIONS
# ══════════════════════════════════════════════════════════════

@router.get("/api/assignments/agents")
async def list_agents(request: Request):
    return await _proxy(request, f"{FOREST_SERVICE_URL}/api/assignments/agents")

@router.get("/api/assignments/superviseurs")
async def list_superviseurs(request: Request):
    return await _proxy(request, f"{FOREST_SERVICE_URL}/api/assignments/superviseurs")