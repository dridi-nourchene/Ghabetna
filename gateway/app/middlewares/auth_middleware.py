# api_gateway/app/middlewares/auth_middleware.py

from fastapi import Request
from fastapi.responses import JSONResponse

from app.core.security import verify_access_token
from app.core.config import PUBLIC_ROUTES


async def auth_middleware(request: Request, call_next):
    path   = request.url.path
    method = request.method

    # 🔥 1. TRÈS IMPORTANT — laisser passer CORS preflight
    if method == "OPTIONS":
        return await call_next(request)

    # ─────────────────────────────────────────────
    # 🔓 Swagger & docs
    # ─────────────────────────────────────────────
    PUBLIC_PATHS = [
        "/docs",
        "/openapi.json",
        "/redoc",
    ]

    if any(path.startswith(p) for p in PUBLIC_PATHS):
        return await call_next(request)

    # ─────────────────────────────────────────────
    # 🔓 Routes publiques
    # ─────────────────────────────────────────────
    is_public = any(
        path == route and method == route_method
        for route, route_method in PUBLIC_ROUTES
    )

    if is_public:
        return await call_next(request)

    # ─────────────────────────────────────────────
    # 🔐 Vérification JWT
    # ─────────────────────────────────────────────
    auth_header = request.headers.get("Authorization")

    if not auth_header or not auth_header.startswith("Bearer "):
        return JSONResponse(
            status_code=401,
            content={"detail": "Token manquant"}
        )

    token = auth_header.split(" ")[1]
    payload = verify_access_token(token)

    if not payload:
        return JSONResponse(
            status_code=401,
            content={"detail": "Token invalide ou expiré"}
        )

    # Injecter les infos utilisateur
    request.state.user_id    = payload.get("user_id")
    request.state.user_role  = payload.get("role")
    request.state.user_email = payload.get("email")

    return await call_next(request)