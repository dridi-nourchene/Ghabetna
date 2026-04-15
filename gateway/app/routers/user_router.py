import httpx
from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from app.core.config import USER_SERVICE_URL

router = APIRouter(prefix="/api/users", tags=["Users"])


async def _proxy(request: Request, url: str) -> JSONResponse:
    """
    Proxy générique :
    - Transfère le body
    - Injecte les headers X-User-* depuis le middleware
    """
    async with httpx.AsyncClient() as client:
        body = await request.body()

        # Headers enrichis avec les infos du user (depuis le middleware)
        headers = {
            "Content-Type":  "application/json",
            "Authorization": request.headers.get("Authorization", ""),
            "X-User-Id":     getattr(request.state, "user_id",    ""),
            "X-User-Role":   getattr(request.state, "user_role",   ""),
            "X-User-Email":  getattr(request.state, "user_email",  ""),
            
        }

        response = await client.request(
            method  = request.method,
            url     = url,
            headers = headers,
            content = body,
            params  = request.query_params,
        )

    return JSONResponse(
        status_code = response.status_code,
        content     = response.json(),
    )


@router.post("/")
async def create_user(request: Request):
    return await _proxy(request, f"{USER_SERVICE_URL}/api/users/")


@router.post("/activate")
async def activate_user(request: Request):
    return await _proxy(request, f"{USER_SERVICE_URL}/api/users/activate")


@router.get("/active")
async def get_active_users(request: Request):
    return await _proxy(request, f"{USER_SERVICE_URL}/api/users/active")


@router.get("/inactive")
async def get_inactive_users(request: Request):
    return await _proxy(request, f"{USER_SERVICE_URL}/api/users/inactive")


@router.get("/{user_id}")
async def get_user(user_id: str, request: Request):
    return await _proxy(request, f"{USER_SERVICE_URL}/api/users/{user_id}")


@router.put("/{user_id}")
async def update_user(user_id: str, request: Request):
    return await _proxy(request, f"{USER_SERVICE_URL}/api/users/{user_id}")


@router.delete("/{user_id}")
async def delete_user(user_id: str, request: Request):
    return await _proxy(request, f"{USER_SERVICE_URL}/api/users/{user_id}")