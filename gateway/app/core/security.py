from jose import JWTError, jwt
from app.core.config import SECRET_KEY, ALGORITHM
from typing import Any

def verify_access_token(token: str) -> dict[str, Any] | None:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "access":
            return None
        return payload
    except JWTError:
        return None