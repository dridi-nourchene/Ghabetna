from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from fastapi import HTTPException

from app.models.user import User, UserStatus, RefreshToken
from app.schemas.auth import (LoginRequest,TokenResponse,RefreshRequest,RefreshResponse,)
from app.core.security import (verify_password,create_access_token,create_refresh_token,verify_refresh_token,get_refresh_token_expiry,)


# ────────────────────────────────────────────────────────────
# LOGIN
# ────────────────────────────────────────────────────────────
async def login(data: LoginRequest,db:   AsyncSession,) -> TokenResponse:
    """
    1. Cherche le user par email
    2. Vérifie que le compte est activé (password_hash not None)
    3. Vérifie le mot de passe
    4. Vérifie que le compte est actif
    5. Génère access + refresh token
    6. Stocke le refresh token en DB
    """

    # ── Chercher le user ──────────────────────────────────
    result = await db.execute(
        select(User).where(User.email == data.email)
    )
    user = result.scalar_one_or_none()

    # Message générique pour ne pas révéler si l'email existe
    if not user:
        raise HTTPException(
            status_code=401,
            detail="Email ou mot de passe incorrect"
        )

    # ── Compte pas encore activé ──────────────────────────
    if not user.password_hash:
        raise HTTPException(
            status_code=401,
            detail="Compte non activé — vérifiez votre email"
        )

    # ── Mauvais mot de passe ──────────────────────────────
    if not verify_password(data.password, user.password_hash):
        raise HTTPException(
            status_code=401,
            detail="mot de passe incorrect"
        )

    # ── Compte inactif ou banni ───────────────────────────
    if user.status != UserStatus.active:
        raise HTTPException(
            status_code=403,
            detail=f"Compte {user.status.value} — contactez l'administrateur"
        )

    # ── Générer les tokens ────────────────────────────────
    access_token = create_access_token({
        "user_id": str(user.user_id),
        "role":    user.role.value,
        "email":   user.email,
    })

    refresh_token_value = create_refresh_token({
        "user_id": str(user.user_id),
    })

    # ── Stocker refresh token en DB ───────────────────────
    db_token = RefreshToken(
        user_id    = user.user_id,
        token      = refresh_token_value,
        expires_at = get_refresh_token_expiry(),
        revoked    = False,
    )
    db.add(db_token)
    await db.commit()

    return TokenResponse(
        access_token  = access_token,
        refresh_token = refresh_token_value,
    )


# ────────────────────────────────────────────────────────────
# REFRESH TOKEN
# ────────────────────────────────────────────────────────────
async def refresh_token(data: RefreshRequest,db:   AsyncSession,) -> RefreshResponse:
    """
    1. Vérifie la signature JWT du refresh token
    2. Vérifie en DB : existe + pas révoqué + pas expiré
    3. Révoque l'ancien refresh token (rotation)
    4. Génère un nouveau access token seulement
    """

    # ── Vérifier la signature JWT ─────────────────────────
    payload = verify_refresh_token(data.refresh_token)
    if not payload:
        raise HTTPException(
            status_code=401,
            detail="Refresh token invalide ou expiré"
        )

    # ── Vérifier en DB ────────────────────────────────────
    result = await db.execute(
        select(RefreshToken).where(
            RefreshToken.token == data.refresh_token
        )
    )
    db_token = result.scalar_one_or_none()

    if not db_token:
        raise HTTPException(
            status_code=401,
            detail="Refresh token invalide"
        )

    if db_token.revoked:
        raise HTTPException(
            status_code=401,
            detail="Refresh token révoqué — reconnectez-vous"
        )

    if db_token.expires_at < datetime.now(timezone.utc):
        raise HTTPException(
            status_code=401,
            detail="Refresh token expiré — reconnectez-vous"
        )

    # ── Récupérer le user ─────────────────────────────────
    result = await db.execute(
        select(User).where(User.user_id == db_token.user_id)
    )
    user = result.scalar_one_or_none()

    if not user or user.status != UserStatus.active:
        raise HTTPException(
            status_code=401,
            detail="User invalide ou inactif"
        )

    # ── Révoquer l'ancien refresh token (rotation) ────────
    db_token.revoked = True
    await db.commit()

    # ── Générer nouveau access token seulement ────────────
    new_access_token = create_access_token({
        "user_id": str(user.user_id),
        "role":    user.role.value,
        "email":   user.email,
    })

    return RefreshResponse(
        access_token = new_access_token,
    )


# ────────────────────────────────────────────────────────────
# LOGOUT
# ────────────────────────────────────────────────────────────
async def logout(data:         RefreshRequest,current_user: User,db:           AsyncSession,) -> dict:
    """
    1. Cherche le refresh token en DB
    2. Vérifie qu'il appartient au current_user
    3. Le révoque
    """

    result = await db.execute(
        select(RefreshToken).where(
            RefreshToken.token   == data.refresh_token,
            RefreshToken.user_id == current_user.user_id,
        )
    )
    db_token = result.scalar_one_or_none()

    if not db_token:
        raise HTTPException(
            status_code=404,
            detail="Token non trouvé"
        )

    if db_token.revoked:
        raise HTTPException(
            status_code=400,
            detail="Token déjà révoqué"
        )

    db_token.revoked = True
    await db.commit()

    return {"message": "Déconnexion réussie"}