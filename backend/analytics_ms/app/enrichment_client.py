import httpx
from app.core.config import settings

_TIMEOUT = 10.0


async def get_users_map(user_ids: set[str]) -> dict[str, dict]:
    """user_id (str) -> {user_id, nom, email, phone, role}"""
    user_ids = {u for u in user_ids if u}
    if not user_ids:
        return {}
    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        resp = await client.get(
            f"{settings.FOREST_SERVICE_URL}/internal/users",
            params={"ids": ",".join(user_ids)},
        )
        resp.raise_for_status()
        return {u["user_id"]: u for u in resp.json()}


async def get_forests_map(forest_ids: set[str]) -> dict[str, dict]:
    """forest_id (str) -> {forest_id, forest_name, superviseur_id}"""
    forest_ids = {f for f in forest_ids if f}
    if not forest_ids:
        return {}
    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        resp = await client.get(
            f"{settings.FOREST_SERVICE_URL}/internal/forests",
            params={"ids": ",".join(forest_ids)},
        )
        resp.raise_for_status()
        return {f["forest_id"]: f for f in resp.json()}


async def get_all_forests() -> list[dict]:
    """All forests with their superviseur_id — used for the supervisor
    workload table, which needs the full forest→supervisor mapping."""
    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        resp = await client.get(f"{settings.FOREST_SERVICE_URL}/internal/forests/all")
        resp.raise_for_status()
        return resp.json()