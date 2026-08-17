"""
Identité de l'appelant.

citizen_ms ne vérifie PAS le JWT lui-même : c'est auth_middleware.py de la
gateway qui le fait, puis qui injecte X-User-Id, X-User-Role et X-User-Email.
Même modèle que alert_ms — la vérification reste centralisée à un seul
endroit.

Conséquence : ces routes ne doivent jamais être exposées directement sur le
port 8006 en production. Le port n'est publié que pour Swagger en dev.
"""

from uuid import UUID

from fastapi import Header, HTTPException, status


async def get_current_user_id(
    x_user_id: str = Header(None, alias="X-User-Id"),
) -> UUID:
    if not x_user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Identité manquante",
        )
    try:
        return UUID(x_user_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Identité invalide",
        )


async def require_admin(
    x_user_id:   str = Header(None, alias="X-User-Id"),
    x_user_role: str = Header(None, alias="X-User-Role"),
) -> UUID:
    """
    Validation des dossiers réservée à l'admin.

    Le superviseur est exclu volontairement : il gère les forêts et les
    alertes, pas l'inscription des citoyens. Si tu veux l'autoriser plus
    tard, c'est la seule ligne à changer.
    """
    if x_user_role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Accès réservé aux administrateurs",
        )
    return await get_current_user_id(x_user_id)
