from uuid import UUID
from datetime import datetime
from pydantic import BaseModel



# Permission schemas
class PermissionResponse(BaseModel):
    perm_id:     UUID
    name:        str
    description: str | None
    created_at:  datetime

    model_config = {"from_attributes": True}


class PermissionCreate(BaseModel):
    name:        str
    description: str | None = None

# role schemas
class RoleCreate(BaseModel):
    name:                     str
    requires_email_activation: bool = False

    # L'admin coche les permissions au moment de créer le rôle
    # liste des perm_id à assigner 
    permission_ids: list[UUID] = []


class RoleUpdate(BaseModel):
    name:                     str | None = None
    requires_email_activation: bool | None = None
    permission_ids:           list[UUID] | None = None


class RoleResponse(BaseModel):
    role_id:                  UUID
    name:                     str
    requires_email_activation: bool
    created_at:               datetime

    # Retourne les permissions complètes 
    permissions: list[PermissionResponse] = []

    model_config = {"from_attributes": True}


class RoleListResponse(BaseModel):
    total: int
    roles: list[RoleResponse]