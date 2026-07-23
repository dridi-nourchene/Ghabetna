from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy import select, func, case
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.alert import Alert, AlertStatus, AlertType
from app.models.assignment_cache import AssignmentCache
from app.models.forest_supervisor_cache import ForestSupervisorCache


# ── Helpers ────────────────────────────────────────────────

def _period_condition(days: Optional[int]):
    if not days:
        return None
    return Alert.created_at >= datetime.now(timezone.utc) - timedelta(days=days)


def _base_conditions(
    forest_id: Optional[UUID] = None,
    type_:     Optional[AlertType] = None,
    days:      Optional[int] = None,
) -> list:
    conditions = []
    if forest_id:
        conditions.append(Alert.forest_id == forest_id)
    if type_:
        conditions.append(Alert.type == type_)
    period = _period_condition(days)
    if period is not None:
        conditions.append(period)
    return conditions


async def _resolve_forest_names(db: AsyncSession, forest_ids: list[UUID]) -> dict[UUID, str]:
    """Résout les noms de forêt via forest_supervisor_cache puis assignments_cache."""
    names: dict[UUID, str] = {}
    if not forest_ids:
        return names

    res = await db.execute(
        select(ForestSupervisorCache.forest_id, ForestSupervisorCache.forest_name)
        .where(ForestSupervisorCache.forest_id.in_(forest_ids))
    )
    for fid, name in res.all():
        if name:
            names[fid] = name

    missing = [f for f in forest_ids if f not in names]
    if missing:
        res2 = await db.execute(
            select(AssignmentCache.forest_id, AssignmentCache.forest_name)
            .where(AssignmentCache.forest_id.in_(missing))
        )
        for fid, name in res2.all():
            if name and fid not in names:
                names[fid] = name

    return names


# ── Alerts by forest ────────────────────────────────────

async def get_alerts_by_forest(
    db: AsyncSession,
    limit: int = 10,
    forest_id: Optional[UUID] = None,
    type_: Optional[AlertType] = None,
    days: Optional[int] = None,
) -> dict:
    conditions = _base_conditions(forest_id, type_, days)

    rejected_expr  = func.count(case((Alert.status == AlertStatus.rejeter, 1)))
    confirmed_expr = func.count(
        case((Alert.status.in_([AlertStatus.traiter, AlertStatus.en_cours]), 1))
    )

    query = (
        select(Alert.forest_id, rejected_expr.label("rejected"), confirmed_expr.label("confirmed"))
        .where(*conditions)
        .group_by(Alert.forest_id)
    )
    rows = (await db.execute(query)).all()

    names = await _resolve_forest_names(db, [r.forest_id for r in rows])

    enriched = [
        {
            "forest_id":       r.forest_id,
            "forest_name":     names.get(r.forest_id, f"Forêt {str(r.forest_id)[:8]}"),
            "rejected_count":  r.rejected,
            "confirmed_count": r.confirmed,
        }
        for r in rows
    ]
    enriched.sort(key=lambda x: x["rejected_count"] + x["confirmed_count"], reverse=True)

    top   = enriched[:limit]
    rest  = enriched[limit:]

    return {
        "items": [
            {**item, "forest_id": str(item["forest_id"])} for item in top
        ],
        "others_rejected_count":  sum(r["rejected_count"]  for r in rest),
        "others_confirmed_count": sum(r["confirmed_count"] for r in rest),
        "others_forest_count":    len(rest),
    }


# ──  Status evolution over time ─────────────────────────

async def get_status_trend(
    db: AsyncSession,
    granularity: str = "week",
    forest_id: Optional[UUID] = None,
    type_: Optional[AlertType] = None,
    days: Optional[int] = None,
) -> list[dict]:
    conditions = _base_conditions(forest_id, type_, days)
    trunc_unit = "week" if granularity == "week" else "month"
    period_expr = func.date_trunc(trunc_unit, Alert.created_at)

    query = (
        select(period_expr.label("period"), Alert.status, func.count().label("cnt"))
        .where(*conditions)
        .group_by(period_expr, Alert.status)
        .order_by(period_expr)
    )
    rows = (await db.execute(query)).all()

    buckets: dict[datetime, dict[str, int]] = {}
    for period, status, cnt in rows:
        bucket = buckets.setdefault(period, {"en_cours": 0, "traiter": 0, "rejeter": 0})
        bucket[status.value] = cnt

    return [
        {"period": period.date().isoformat(), **buckets[period]}
        for period in sorted(buckets.keys())
    ]


# ──  Forest × alert type matrix ─────────────────────────

async def get_forest_type_matrix(
    db: AsyncSession,
    forest_id: Optional[UUID] = None,
    days: Optional[int] = None,
) -> list[dict]:
    conditions = _base_conditions(forest_id, None, days)

    query = (
        select(Alert.forest_id, Alert.type, func.count().label("cnt"))
        .where(*conditions)
        .group_by(Alert.forest_id, Alert.type)
    )
    rows = (await db.execute(query)).all()

    grouped: dict[UUID, dict[str, int]] = {}
    for fid, type_, cnt in rows:
        grouped.setdefault(fid, {})[type_.value] = cnt

    names = await _resolve_forest_names(db, list(grouped.keys()))

    return [
        {
            "forest_id":       str(fid),
            "forest_name":     names.get(fid, f"Forêt {str(fid)[:8]}"),
            "counts_by_type":  counts,
        }
        for fid, counts in grouped.items()
    ]


# ──  Top agents (validation / rejection) ────────────────

async def get_top_agents(db: AsyncSession, status: str, limit: int = 5) -> list[dict]:
    status_enum = AlertStatus(status)  # "traiter" | "rejeter" — validated by router regex

    total_expr = func.count()
    match_expr = func.count(case((Alert.status == status_enum, 1)))

    query = (
        select(Alert.agent_id, match_expr.label("num"), total_expr.label("total"))
        .group_by(Alert.agent_id)
        .having(total_expr > 0)
    )
    rows = (await db.execute(query)).all()

    agent_ids = [r.agent_id for r in rows]
    contacts: dict[UUID, AssignmentCache] = {}
    if agent_ids:
        res = await db.execute(
            select(AssignmentCache).where(AssignmentCache.agent_id.in_(agent_ids))
        )
        for a in res.scalars().all():
            contacts[a.agent_id] = a

    results = []
    for agent_id, num, total in rows:
        rate    = round((num / total) * 100, 1) if total else 0.0
        contact = contacts.get(agent_id)

        item = {
            "agent_id": str(agent_id),
            "nom":      contact.agent_nom if contact else "Inconnu",
            "rate":     rate,
        }

        if status_enum == AlertStatus.rejeter:
            item["agent_phone"] = contact.agent_phone if contact else None
            item["agent_email"] = contact.agent_email if contact else None

            supervisor = None
            if contact:
                sup_res = await db.execute(
                    select(ForestSupervisorCache)
                    .where(ForestSupervisorCache.forest_id == contact.forest_id)
                )
                supervisor = sup_res.scalar_one_or_none()

            item["supervisor_id"]    = str(supervisor.supervisor_id) if supervisor else None
            item["supervisor_nom"]   = supervisor.supervisor_nom     if supervisor else None
            item["supervisor_phone"] = supervisor.supervisor_phone   if supervisor else None
            item["supervisor_email"] = supervisor.supervisor_email   if supervisor else None

        results.append(item)

    results.sort(key=lambda x: x["rate"], reverse=True)
    return results[:limit]


# ── Supervisor workload and quality ────────────────────

async def get_supervisor_workload(db: AsyncSession) -> list[dict]:
    sup_res = await db.execute(select(ForestSupervisorCache))
    forest_rows = sup_res.scalars().all()

    by_supervisor: dict[UUID, dict] = {}
    for row in forest_rows:
        entry = by_supervisor.setdefault(row.supervisor_id, {
            "nom": row.supervisor_nom,
            "forest_ids": [],
        })
        entry["forest_ids"].append(row.forest_id)

    results = []
    for sup_id, entry in by_supervisor.items():
        forest_ids = entry["forest_ids"]

        avg_seconds_expr = func.avg(
            case(
                (Alert.status != AlertStatus.en_cours,
                 func.extract("epoch", Alert.updated_at - Alert.created_at)),
            )
        )
        query = select(
            func.count().label("total"),
            func.count(case((Alert.status == AlertStatus.rejeter, 1))).label("rejected"),
            func.count(case((Alert.status == AlertStatus.traiter, 1))).label("treated"),
            avg_seconds_expr.label("avg_seconds"),
        ).where(Alert.forest_id.in_(forest_ids))

        row = (await db.execute(query)).one()
        rejected, treated = row.rejected or 0, row.treated or 0
        reject_rate = round((rejected / (rejected + treated) * 100), 1) if (rejected + treated) else 0.0
        avg_hours   = round((row.avg_seconds or 0) / 3600, 1)

        results.append({
            "supervisor_id":        str(sup_id),
            "nom":                  entry["nom"],
            "forest_count":         len(forest_ids),
            "alert_count":          row.total or 0,
            "reject_rate":          reject_rate,
            "avg_treatment_hours":  avg_hours,
        })

    results.sort(key=lambda x: x["alert_count"], reverse=True)
    return results