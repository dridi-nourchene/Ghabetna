import httpx
from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from app.core.config import USER_SERVICE_URL

router = APIRouter(prefix="/api/auth", tags=["Auth"])

# ── Schémas pour Swagger ──────────────────────────────────
class LoginRequest(BaseModel):
    email:    str
    password: str

class RefreshRequest(BaseModel):
    refresh_token: str

class LogoutRequest(BaseModel):
    refresh_token: str

# ── Proxy générique ───────────────────────────────────────
async def _proxy(request: Request, url: str, body: dict) -> JSONResponse:
    async with httpx.AsyncClient() as client:
        response = await client.request(
            method  = request.method,
            url     = url,
            headers = {"Content-Type": "application/json"},
            json    = body,
        )
    return JSONResponse(
        status_code = response.status_code,
        content     = response.json(),
    )

# ── Endpoints ─────────────────────────────────────────────
@router.post("/login")
async def login(request: Request, body: LoginRequest):
    return await _proxy(request, f"{USER_SERVICE_URL}/api/auth/login", body.model_dump())

@router.post("/refresh")
async def refresh(request: Request, body: RefreshRequest):
    return await _proxy(request, f"{USER_SERVICE_URL}/api/auth/refresh", body.model_dump())

@router.post("/logout")
async def logout(request: Request, body: LogoutRequest):
    return await _proxy(request, f"{USER_SERVICE_URL}/api/auth/logout", body.model_dump())