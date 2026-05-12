from uuid import UUID
from fastapi import Header, HTTPException


async def get_current_user_id(
    x_user_id: str = Header(..., alias="X-User-Id")
) -> UUID:
    try:
        return UUID(x_user_id)
    except ValueError:
        raise HTTPException(status_code=401, detail="Token invalide")


async def get_current_user_role(
    x_user_role: str = Header(..., alias="X-User-Role")
) -> str:
    return x_user_role


async def require_admin(
    x_user_id:   str = Header(..., alias="X-User-Id"),
    x_user_role: str = Header(..., alias="X-User-Role"),
) -> UUID:
    if x_user_role != "admin":
        raise HTTPException(status_code=403, detail="Accès réservé à l'admin")
    try:
        return UUID(x_user_id)
    except ValueError:
        raise HTTPException(status_code=401, detail="Token invalide")