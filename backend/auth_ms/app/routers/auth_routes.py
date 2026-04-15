from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_active_user
from app.db.database import get_db
from app.models.user import User
from app.schemas.auth import (
    LoginRequest,
    RefreshRequest,
    RefreshResponse,
    TokenResponse,
)
from app.services import auth_service

router = APIRouter(prefix="/api/auth", tags=["Auth"])


# ── POST /api/auth/login ──────────────────────────────────
@router.post(
    "/login",
    response_model=TokenResponse,
    summary="Connexion — retourne access + refresh token",
)
async def login(
    data: LoginRequest,
    db:   AsyncSession = Depends(get_db),
):
    return await auth_service.login(data, db)


# ── POST /api/auth/refresh ────────────────────────────────
@router.post(
    "/refresh",
    response_model=RefreshResponse,
    summary="Renouveler l'access token via refresh token",
)
async def refresh_token(
    data: RefreshRequest,
    db:   AsyncSession = Depends(get_db),
):
    return await auth_service.refresh_token(data, db)


# ── POST /api/auth/logout ─────────────────────────────────
@router.post(
    "/logout",
    summary="Déconnexion — révoque le refresh token",
)
async def logout(
    data:         RefreshRequest,
    db:           AsyncSession = Depends(get_db),
    current_user: User         = Depends(get_current_active_user),
):
    return await auth_service.logout(data, current_user, db)