from fastapi import Header, HTTPException
from uuid import UUID
from typing import Optional


async def get_current_user_id(
    x_user_id: Optional[str] = Header(None),
) -> UUID:
    """Extrait l'ID utilisateur depuis le header injecté par le gateway."""
    if not x_user_id:
        raise HTTPException(status_code=401, detail="Non authentifié")
    try:
        return UUID(x_user_id)
    except ValueError:
        raise HTTPException(status_code=401, detail="User ID invalide")


async def require_admin(
    x_user_id:   Optional[str] = Header(None),
    x_user_role: Optional[str] = Header(None),
) -> UUID:
    """Vérifie que l'utilisateur est admin. Retourne son UUID."""
    if not x_user_id or not x_user_role:
        raise HTTPException(status_code=401, detail="Non authentifié")
    if x_user_role != "admin":
        raise HTTPException(status_code=403, detail="Accès réservé aux administrateurs")
    try:
        return UUID(x_user_id)
    except ValueError:
        raise HTTPException(status_code=401, detail="User ID invalide")


async def require_admin_or_supervisor(
    x_user_id:   Optional[str] = Header(None),
    x_user_role: Optional[str] = Header(None),
) -> UUID:
    """Vérifie que l'utilisateur est admin ou supervisor."""
    if not x_user_id or not x_user_role:
        raise HTTPException(status_code=401, detail="Non authentifié")
    if x_user_role not in ("admin", "supervisor"):
        raise HTTPException(status_code=403, detail="Accès non autorisé")
    try:
        return UUID(x_user_id)
    except ValueError:
        raise HTTPException(status_code=401, detail="User ID invalide")