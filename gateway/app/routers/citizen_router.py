"""
Gateway — Citizen Router

Deux modes de relais dans ce fichier, et c'est le point important :

  _proxy_multipart  → l'inscription. Le corps contient des fichiers, donc on
                      relaie les octets BRUTS en conservant le Content-Type
                      d'origine. Ce header porte la frontière multipart
                      (boundary=----WebKitFormBoundary...) : la réécrire ou
                      la perdre rend le corps illisible côté citizen_ms.

  _proxy_json       → tout le reste. Même principe que alert_router.

Ne jamais utiliser json=... ni forcer Content-Type: application/json sur
l'inscription : les fichiers seraient détruits.
"""

import httpx
from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse, Response

from app.core.config import CITIZEN_SERVICE_URL

router = APIRouter(prefix="/api/citoyens", tags=["Citoyens"])


def _base_headers(request: Request) -> dict:
    """Identité injectée par auth_middleware. Vide pour l'inscription."""
    headers = {}
    user_id    = getattr(request.state, "user_id",    None)
    user_role  = getattr(request.state, "user_role",  None)
    user_email = getattr(request.state, "user_email", None)
    if user_id:    headers["X-User-Id"]    = str(user_id)
    if user_role:  headers["X-User-Role"]  = str(user_role)
    if user_email: headers["X-User-Email"] = str(user_email)
    return headers


async def _proxy_multipart(request: Request, url: str) -> Response:
    body = await request.body()

    headers = _base_headers(request)
    # On recopie le Content-Type tel quel : il contient la boundary générée
    # par le client. Sans elle, citizen_ms ne sait pas découper le corps.
    content_type = request.headers.get("content-type")
    if content_type:
        headers["Content-Type"] = content_type

    # Timeout large : l'envoi de plusieurs documents scannés est lent sur une
    # connexion mobile, et citizen_ms attend lui-même auth_ms derrière.
    async with httpx.AsyncClient(timeout=120.0) as client:
        response = await client.request(
            method  = request.method,
            url     = url,
            headers = headers,
            content = body,
        )

    return JSONResponse(status_code=response.status_code, content=response.json())


async def _proxy_json(request: Request, url: str) -> Response:
    async with httpx.AsyncClient(timeout=90.0) as client:
        body    = await request.body()
        headers = {"Content-Type": "application/json", **_base_headers(request)}

        response = await client.request(
            method  = request.method,
            url     = url,
            headers = headers,
            content = body,
            params  = request.query_params,
        )

    if not response.content:
        return Response(status_code=response.status_code)
    return JSONResponse(status_code=response.status_code, content=response.json())


# ── Inscription — route PUBLIQUE, multipart ───────────────

@router.post("/inscription")
async def inscription(request: Request):
    """
    Déclarée dans PUBLIC_ROUTES : le citoyen n'a pas encore de compte, donc
    pas de token. Le middleware saute la vérification mais la requête passe
    quand même par ici — c'est la seule porte ouverte sur l'extérieur.
    """
    return await _proxy_multipart(
        request, f"{CITIZEN_SERVICE_URL}/api/citoyens/inscription"
    )


# ── Citoyen connecté ──────────────────────────────────────

@router.get("/mon-dossier")
async def mon_dossier(request: Request):
    return await _proxy_json(request, f"{CITIZEN_SERVICE_URL}/api/citoyens/mon-dossier")


# ── Admin ─────────────────────────────────────────────────

@router.get("/dossiers")
async def lister_dossiers(request: Request):
    return await _proxy_json(request, f"{CITIZEN_SERVICE_URL}/api/citoyens/dossiers")


@router.get("/dossiers/{profil_id}")
async def detail_dossier(profil_id: str, request: Request):
    return await _proxy_json(
        request, f"{CITIZEN_SERVICE_URL}/api/citoyens/dossiers/{profil_id}"
    )


@router.patch("/dossiers/{profil_id}/decision")
async def decider(profil_id: str, request: Request):
    return await _proxy_json(
        request, f"{CITIZEN_SERVICE_URL}/api/citoyens/dossiers/{profil_id}/decision"
    )


# ── Pièces jointes ────────────────────────────────────────

@router.get("/uploads/{file_path:path}")
async def serve_upload(file_path: str, request: Request):
    """
    Même principe que serve_upload dans alert_router : la gateway relaie le
    fichier brut. Préfixe /api/citoyens/uploads pour ne pas entrer en
    conflit avec la route /uploads d'alert_ms.
    """
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.get(f"{CITIZEN_SERVICE_URL}/uploads/{file_path}")

    if response.status_code != 200:
        return Response(status_code=response.status_code)

    return Response(
        content      = response.content,
        status_code  = response.status_code,
        media_type   = response.headers.get("content-type", "application/octet-stream"),
        headers      = {"Cache-Control": "private, max-age=3600"},
    )