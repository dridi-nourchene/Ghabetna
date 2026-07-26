from pydantic import BaseModel
from typing import Optional


class ForestAlertStat(BaseModel):
    forest_id:        str
    forest_name:      str
    rejected_count:   int
    confirmed_count:  int


class AlertsByForestResponse(BaseModel):
    items:                    list[ForestAlertStat]
    others_rejected_count:    int
    others_confirmed_count:   int
    others_forest_count:      int


class StatusTrendPoint(BaseModel):
    period:   str
    en_cours: int
    traiter:  int
    rejeter:  int


class ForestTypeMatrixRow(BaseModel):
    forest_id:       str
    forest_name:     str
    counts_by_type:  dict[str, int]


class TopAgentRejection(BaseModel):
    agent_id:         str
    nom:              str
    rate:             float
    agent_phone:      Optional[str] = None
    agent_email:      Optional[str] = None
    supervisor_id:    Optional[str] = None
    supervisor_nom:   Optional[str] = None
    supervisor_phone: Optional[str] = None
    supervisor_email: Optional[str] = None


class TopAgentValidation(BaseModel):
    agent_id: str
    nom:      str
    rate:     float


class SupervisorWorkloadItem(BaseModel):
    supervisor_id:        str
    nom:                  str
    forest_count:         int
    alert_count:          int
    reject_rate:          float
    avg_treatment_hours:  float


class SupervisorWorkloadResponse(BaseModel):
    threshold: float
    items:     list[SupervisorWorkloadItem]


class OverviewResponse(BaseModel):
    total_alerts:               int
    most_affected_forest_id:    Optional[str] = None
    most_affected_forest_name:  Optional[str] = None
    most_affected_forest_count: int = 0
    global_validation_rate:     float