from pydantic import BaseModel, EmailStr, field_validator
from uuid import UUID


class LoginRequest(BaseModel):
    email:    EmailStr
    password: str

    @field_validator("password")
    @classmethod
    def password_not_empty(cls, v):
        if not v or not v.strip():
            raise ValueError("Le mot de passe ne peut pas être vide")
        return v


# Retourné après login
class TokenResponse(BaseModel):
    access_token:  str
    refresh_token: str
    token_type:    str = "bearer"


# Envoyé pour refresh ET logout
class RefreshRequest(BaseModel):
    refresh_token: str


# Retourné après refresh
class RefreshResponse(BaseModel):
    access_token: str
    token_type:   str = "bearer"
    
class TokenPayload(BaseModel):
    sub:         str       # user_id (UUID)
    role:        str       # "admin", "superviseur", "agent"
    permissions: list[str] # ["forest:create", "alert:view"...]
    exp:         int       # timestamp expiration


