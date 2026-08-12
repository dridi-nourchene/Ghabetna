import httpx
from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from app.core.config import CHATBOT_SERVICE_URL

router = APIRouter(prefix="/api/chat", tags=["Chatbot"])


async def _proxy(request: Request, url: str) -> JSONResponse:
    """
    Proxy vers chatbot_ms.

    Timeout plus large que les autres services : la premiere requete apres
    un demarrage attend le chargement du modele d'embedding (10 a 20 s).
    Ensuite chaque requete coute environ 1 seconde.
    """
    async with httpx.AsyncClient(timeout=120.0) as client:
        body = await request.body()

        headers = {
            "Content-Type":  "application/json",
            "Authorization": request.headers.get("Authorization", ""),
        }
        user_id    = getattr(request.state, "user_id",    None)
        user_role  = getattr(request.state, "user_role",  None)
        user_email = getattr(request.state, "user_email", None)

        if user_id:    headers["X-User-Id"]    = str(user_id)
        if user_role:  headers["X-User-Role"]  = str(user_role)
        if user_email: headers["X-User-Email"] = str(user_email)

        # Specialite du citoyen : "chasseur", "campeur" ou "apiculteur".
        # C'est elle qui determine le domaine interroge par le RAG et donc
        # l'etancheite entre les trois publics.
        # Le champ n'existe pas encore dans le JWT : il sera ajoute avec
        # l'authentification citoyenne. En attendant, chatbot_ms accepte
        # aussi la specialite dans le corps de la requete.
        specialite = getattr(request.state, "user_specialite", None)
        if specialite:
            headers["X-User-Specialite"] = str(specialite)

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
async def chat(request: Request):
    return await _proxy(request, f"{CHATBOT_SERVICE_URL}/api/chat/")


@router.post("/debug")
async def chat_debug(request: Request):
    """Retrieval seul, sans appel au LLM. Utile pour verifier le corpus."""
    return await _proxy(request, f"{CHATBOT_SERVICE_URL}/api/chat/debug")


@router.get("/health")
async def chat_health(request: Request):
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.get(f"{CHATBOT_SERVICE_URL}/health")
    return JSONResponse(status_code=response.status_code,
                        content=response.json())