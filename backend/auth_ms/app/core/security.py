from datetime import datetime, timedelta, timezone
from typing import Any

import bcrypt
from jose import JWTError, jwt

from app.core.config import settings

# ────────────────────────────────────────────────────────────
# CONFIG
# ────────────────────────────────────────────────────────────
SECRET_KEY           = settings.JWT_SECRET_KEY
ALGORITHM            = settings.JWT_ALGORITHM
ACCESS_TOKEN_EXPIRE  = settings.ACCESS_TOKEN_EXPIRE_MINUTES
REFRESH_TOKEN_EXPIRE = settings.REFRESH_TOKEN_EXPIRE_DAYS


# ────────────────────────────────────────────────────────────
# PASSWORD
# ────────────────────────────────────────────────────────────
def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return bcrypt.checkpw(
        plain_password.encode("utf-8"),
        hashed_password.encode("utf-8"),
    )


# ────────────────────────────────────────────────────────────
# ACCESS TOKEN — courte durée (30 min)
# ────────────────────────────────────────────────────────────
def create_access_token(payload: dict[str, Any]) -> str:
    data = payload.copy()
    data["exp"]  = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE)
    data["type"] = "access"
    return jwt.encode(data, SECRET_KEY, algorithm=ALGORITHM)


def verify_access_token(token: str) -> dict[str, Any] | None:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "access":
            return None
        return payload
    except JWTError:
        return None


# ────────────────────────────────────────────────────────────
# REFRESH TOKEN — longue durée (7 jours)
# ────────────────────────────────────────────────────────────
def create_refresh_token(payload: dict[str, Any]) -> str:
    data = payload.copy()
    data["exp"]  = datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE)
    data["type"] = "refresh"
    return jwt.encode(data, SECRET_KEY, algorithm=ALGORITHM)


def verify_refresh_token(token: str) -> dict[str, Any] | None:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "refresh":
            return None
        return payload
    except JWTError:
        return None


# ────────────────────────────────────────────────────────────
# EXPIRATION
# ────────────────────────────────────────────────────────────
def get_refresh_token_expiry() -> datetime:
    return datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE)