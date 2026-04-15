import re
from typing import Optional
from uuid import UUID
from datetime import date, datetime
from pydantic import BaseModel, EmailStr, field_validator
from app.models.user import UserRole, UserStatus


# ────────────────────────────────────────────────────────────
# Validator réutilisable — mot de passe fort
# ────────────────────────────────────────────────────────────
def validate_strong_password(v: str) -> str:
    if len(v) < 8:
        raise ValueError(
            "Le mot de passe doit contenir au moins 8 caractères"
        )
    if not re.search(r'[A-Z]', v):
        raise ValueError(
            "Le mot de passe doit contenir au moins 1 majuscule"
        )
    if not re.search(r'[a-z]', v):
        raise ValueError(
            "Le mot de passe doit contenir au moins 1 minuscule"
        )
    if not re.search(r'\d', v):
        raise ValueError(
            "Le mot de passe doit contenir au moins 1 chiffre"
        )
    if not re.search(r'[!@#$%^&*(),.?":{}|<>_\-]', v):
        raise ValueError(
            "Le mot de passe doit contenir au moins 1 caractère spécial"
        )
    return v



class UserCreate(BaseModel):
    full_name: str
    email:     EmailStr
    cin:       str
    phone:     str | None = None  
    birth_date: Optional[date] = None
    role: UserRole    

    @field_validator("cin")
    @classmethod
    def validate_cin(cls, v):
        if not re.match(r'^\d{8}$', v):
            raise ValueError(
                "Le CIN doit contenir exactement 8 chiffres"
            )
        return v

class UserUpdate(BaseModel):
    full_name: str | None = None
    email:     EmailStr | None = None
    cin:       str | None = None
    phone:     str | None = None
    role:      UserRole | None = None
    status:    UserStatus | None = None

    @field_validator("cin")
    @classmethod
    def validate_cin(cls, v):
        if v is not None:
            if not re.match(r'^\d{8}$', v):
                raise ValueError(
                    "Le CIN doit contenir exactement 8 chiffres"
                )
        return v




class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def validate_new_password(cls, v):
        return validate_strong_password(v)





#  User complet (retourné par l'API)

class UserResponse(BaseModel):
    user_id:    UUID
    full_name:  str
    email:      str
    cin:        str
    phone:      str | None
    status:     UserStatus
    birth_date: date | None 
    role: UserRole   
    created_at: datetime
    updated_at: datetime | None

    model_config = {"from_attributes": True}


# Liste users (paginée)

class UserListResponse(BaseModel):
    total: int
    users: list[UserResponse]


class UserActivate(BaseModel):
    token:    str
    password: str

    @field_validator("password")
    @classmethod
    def validate_password(cls, v):
        return validate_strong_password(v)