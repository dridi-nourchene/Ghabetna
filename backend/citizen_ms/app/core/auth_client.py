"""
Client HTTP vers auth_ms.

Ce module est le SEUL endroit de citizen_ms qui parle à auth_ms. Tout le
reste du service ignore comment les comptes sont créés — il ne connaît que
ce fichier.

Rappel du partage des rôles : citizen_ms COMMANDE la création du compte,
auth_ms l'EXÉCUTE. Le mot de passe transite ici mais n'est jamais stocké ni
journalisé — c'est un passe-plat.
"""

import logging
from uuid import UUID

import httpx
from fastapi import HTTPException

from app.core.config import settings

logger = logging.getLogger(__name__)


class AuthIndisponible(Exception):
    """
    auth_ms est injoignable ou a planté.

    Distinguée d'un HTTPException 409 volontairement : un 409 est une faute
    du citoyen (CIN déjà pris), il doit corriger son formulaire ; une
    indisponibilité est notre faute, il doit réessayer plus tard. Les deux
    déclenchent le même nettoyage mais pas le même message.
    """
    pass


# ── Créer un compte citoyen ───────────────────────────────

async def creer_compte(payload: dict) -> UUID:
    """
    Appelle POST /api/internal/users et renvoie le user_id créé.

    Le compte est créé avec le statut en_attente : il existe, son mot de
    passe est haché, mais la connexion est refusée tant que l'admin n'a pas
    validé le dossier.
    """
    url = f"{settings.AUTH_SERVICE_URL}/api/internal/users"

    try:
        async with httpx.AsyncClient(timeout=settings.AUTH_TIMEOUT) as client:
            response = await client.post(url, json=payload)
    except httpx.RequestError as e:
        # Timeout, DNS, conteneur éteint... rien n'a été créé côté auth_ms.
        logger.error("[CITIZEN MS] auth_ms injoignable : %s", e)
        raise AuthIndisponible(str(e))

    # 409 = CIN ou email déjà utilisé. On remonte tel quel au citoyen.
    if response.status_code == 409:
        detail = response.json().get("detail", "Compte déjà existant")
        raise HTTPException(status_code=409, detail=detail)

    # 422 = un champ refusé par la validation d'auth_ms (mot de passe trop
    # faible, CIN mal formé). Utile de le remonter aussi : le citoyen peut
    # corriger.
    if response.status_code == 422:
        raise HTTPException(status_code=422, detail=response.json().get("detail"))

    if response.status_code != 201:
        logger.error("[CITIZEN MS] auth_ms a répondu %s : %s",
                     response.status_code, response.text)
        raise AuthIndisponible(f"Réponse inattendue : {response.status_code}")

    return UUID(response.json()["user_id"])


# ── Changer le statut d'un compte ─────────────────────────

async def changer_statut(user_id: UUID, statut: str) -> None:
    """
    Appelé quand l'admin approuve ou rejette un dossier, et en compensation
    si l'enregistrement local échoue après création du compte.
    """
    url = f"{settings.AUTH_SERVICE_URL}/api/internal/users/{user_id}/status"

    try:
        async with httpx.AsyncClient(timeout=settings.AUTH_TIMEOUT) as client:
            response = await client.patch(url, json={"status": statut})
    except httpx.RequestError as e:
        logger.error("[CITIZEN MS] auth_ms injoignable (statut) : %s", e)
        raise AuthIndisponible(str(e))

    if response.status_code != 200:
        logger.error("[CITIZEN MS] Changement de statut refusé (%s) : %s",
                     response.status_code, response.text)
        raise AuthIndisponible(f"Réponse inattendue : {response.status_code}")
