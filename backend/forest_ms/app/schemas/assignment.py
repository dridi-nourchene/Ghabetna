from pydantic import BaseModel
from typing import Optional
from uuid import UUID


# ── Superviseur ────────────────────────────────────────────

class AssignSuperviseurRequest(BaseModel):
    superviseur_id: UUID


class SuperviseurInfo(BaseModel):
    user_id: str
    nom:     str
    email:   str


class ForestSuperviseurResponse(BaseModel):
    forest_id:       str
    forest_name:     str
    superviseur_id:  Optional[str]
    superviseur:     Optional[SuperviseurInfo]


# ── Agent ──────────────────────────────────────────────────

class AssignAgentRequest(BaseModel):
    agent_id: UUID


class AgentAssignmentResponse(BaseModel):
    conflict:      bool
    agent_id:      str
    agent_nom:     Optional[str]  = None
    agent_email:   Optional[str]  = None
    parcelle_id:   Optional[str]  = None
    parcelle_name: Optional[str]  = None
    # Rempli uniquement si conflict=True
    current_parcelle_id:   Optional[str] = None
    current_parcelle_name: Optional[str] = None
    message:               Optional[str] = None


# ── Listes ─────────────────────────────────────────────────

class ParcelleInfo(BaseModel):
    parcelle_id:   str
    parcelle_name: str


class ForestInfo(BaseModel):
    forest_id:   str
    forest_name: str


class AgentStatusItem(BaseModel):
    user_id:          str
    nom:              str
    email:            str
    is_assigned:      bool
    current_parcelle: Optional[ParcelleInfo]


class SuperviseurStatusItem(BaseModel):
    user_id:         str
    nom:             str
    email:           str
    is_assigned:     bool
    current_forests: list[ForestInfo]


class ParcelleAgentItem(BaseModel):
    user_id:     str
    nom:         str
    email:       str
    assigned_at: Optional[str]