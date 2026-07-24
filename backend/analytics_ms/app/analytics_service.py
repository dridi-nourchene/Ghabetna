from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy import select, func, case
from sqlalchemy.ext.asyncio import AsyncSession

from app.alert_fact import AlertFact
from app import enrichment_client


# ── Helpers ────────────────────────────────────────────────

def _period_condition(days: Optional[int]):
    if not days:
        return None
    return AlertFact.created_at >= datetime.now(timezone.utc) - timedelta(days=days)


def _base_conditions(
    forest_id: Optional[UUID] = None,
    type_:     Optional[str] = None,
    days:      Optional[int] = None,
) -> list:
    conditions = []
    if forest_id:
        conditions.append(AlertFact.forest_id == forest_id)
    if type_:
        conditions.append(AlertFact.type == type_)
    period = _period_condition(days)
    if period is not None:
        conditions.append(period)
    return conditions


# ── Alerts by forest ────────────────────────────────────

async def get_alerts_by_forest(
    db: AsyncSession,
    limit: int = 10,
    forest_id: Optional[UUID] = None,
    type_: Optional[str] = None,
    days: Optional[int] = None,
) -> dict:
    conditions = _base_conditions(forest_id, type_, days)

    rejected_expr  = func.count(case((AlertFact.status == "rejeter", 1)))
    confirmed_expr = func.count(
        case((AlertFact.status.in_(["traiter", "en_cours"]), 1))
    )

    query = (
        select(AlertFact.forest_id, rejected_expr.label("rejected"), confirmed_expr.label("confirmed"))
        .where(*conditions)
        .group_by(AlertFact.forest_id)
    )
    rows = (await db.execute(query)).all()

    forests_map = await enrichment_client.get_forests_map({str(r.forest_id) for r in rows})

    enriched = [
        {
            "forest_id":       r.forest_id,
            "forest_name":     forests_map.get(str(r.forest_id), {}).get(
                "forest_name", f"Forêt {str(r.forest_id)[:8]}"
            ),
            "rejected_count":  r.rejected,
            "confirmed_count": r.confirmed,
        }
        for r in rows
    ]
    enriched.sort(key=lambda x: x["rejected_count"] + x["confirmed_count"], reverse=True)

    top  = enriched[:limit]
    rest = enriched[limit:]

    return {
        "items": [
            {**item, "forest_id": str(item["forest_id"])} for item in top
        ],
        "others_rejected_count":  sum(r["rejected_count"]  for r in rest),
        "others_confirmed_count": sum(r["confirmed_count"] for r in rest),
        "others_forest_count":    len(rest),
    }


# ── Status evolution over time ─────────────────────────

async def get_status_trend(
    db: AsyncSession,
    granularity: str = "week",
    forest_id: Optional[UUID] = None,
    type_: Optional[str] = None,
    days: Optional[int] = None,
) -> list[dict]:
    conditions = _base_conditions(forest_id, type_, days)
    trunc_unit  = "week" if granularity == "week" else "month"
    period_expr = func.date_trunc(trunc_unit, AlertFact.created_at)

    query = (
        select(period_expr.label("period"), AlertFact.status, func.count().label("cnt"))
        .where(*conditions)
        .group_by(period_expr, AlertFact.status)
        .order_by(period_expr)
    )
    rows = (await db.execute(query)).all()

    buckets: dict[datetime, dict[str, int]] = {}
    for period, status, cnt in rows:
        bucket = buckets.setdefault(period, {"en_cours": 0, "traiter": 0, "rejeter": 0})
        if status in bucket:
            bucket[status] = cnt

    return [
        {"period": period.date().isoformat(), **buckets[period]}
        for period in sorted(buckets.keys())
    ]


# ── Forest × alert type matrix ─────────────────────────

async def get_forest_type_matrix(
    db: AsyncSession,
    forest_id: Optional[UUID] = None,
    days: Optional[int] = None,
) -> list[dict]:
    conditions = _base_conditions(forest_id, None, days)

    query = (
        select(AlertFact.forest_id, AlertFact.type, func.count().label("cnt"))
        .where(*conditions)
        .group_by(AlertFact.forest_id, AlertFact.type)
    )
    rows = (await db.execute(query)).all()

    grouped: dict[UUID, dict[str, int]] = {}
    for fid, type_, cnt in rows:
        grouped.setdefault(fid, {})[type_] = cnt

    forests_map = await enrichment_client.get_forests_map({str(fid) for fid in grouped.keys()})

    return [
        {
            "forest_id":      str(fid),
            "forest_name":    forests_map.get(str(fid), {}).get(
                "forest_name", f"Forêt {str(fid)[:8]}"
            ),
            "counts_by_type": counts,
        }
        for fid, counts in grouped.items()
    ]


# ── Top agents (validation / rejection) ────────────────

async def get_top_agents(db: AsyncSession, status: str, limit: int = 5) -> list[dict]:
    total_expr = func.count()
    match_expr = func.count(case((AlertFact.status == status, 1)))

    query = (
        select(AlertFact.agent_id, match_expr.label("num"), total_expr.label("total"))
        .group_by(AlertFact.agent_id)
        .having(total_expr > 0)
    )
    rows = (await db.execute(query)).all()

    agent_ids = [str(r.agent_id) for r in rows]
    users_map = await enrichment_client.get_users_map(set(agent_ids))

    supervisor_cache: dict[str, dict] = {}
    results = []

    for agent_id, num, total in rows:
        agent_id_s = str(agent_id)
        rate = round((num / total) * 100, 1) if total else 0.0
        user = users_map.get(agent_id_s, {})

        item = {
            "agent_id": agent_id_s,
            "nom":      user.get("nom") or "Inconnu",
            "rate":     rate,
        }

        if status == "rejeter":
            item["agent_phone"] = user.get("phone")
            item["agent_email"] = user.get("email")

            # The forest(s) this agent has reported in — derived straight
            # from AlertFact, no assignment cache needed.
            forest_rows = (await db.execute(
                select(AlertFact.forest_id)
                .where(AlertFact.agent_id == agent_id)
                .distinct()
            )).all()
            forest_ids = {str(f[0]) for f in forest_rows}
            forests_map = await enrichment_client.get_forests_map(forest_ids)

            supervisor_id = next(
                (f["superviseur_id"] for f in forests_map.values() if f.get("superviseur_id")),
                None,
            )

            sup = None
            if supervisor_id:
                if supervisor_id not in supervisor_cache:
                    sup_map = await enrichment_client.get_users_map({supervisor_id})
                    supervisor_cache[supervisor_id] = sup_map.get(supervisor_id, {})
                sup = supervisor_cache[supervisor_id]

            item["supervisor_id"]    = supervisor_id
            item["supervisor_nom"]   = sup.get("nom")   if sup else None
            item["supervisor_phone"] = sup.get("phone") if sup else None
            item["supervisor_email"] = sup.get("email") if sup else None

        results.append(item)

    results.sort(key=lambda x: x["rate"], reverse=True)
    return results[:limit]


# ── Supervisor workload and quality ────────────────────

async def get_supervisor_workload(db: AsyncSession) -> list[dict]:
    forests = await enrichment_client.get_all_forests()

    by_supervisor: dict[str, dict] = {}
    for f in forests:
        sup_id = f.get("superviseur_id")
        if not sup_id:
            continue
        entry = by_supervisor.setdefault(sup_id, {"forest_ids": []})
        entry["forest_ids"].append(f["forest_id"])

    if not by_supervisor:
        return []

    all_supervisor_ids = set(by_supervisor.keys())
    users_map = await enrichment_client.get_users_map(all_supervisor_ids)

    results = []
    for sup_id, entry in by_supervisor.items():
        forest_ids = [UUID(fid) for fid in entry["forest_ids"]]

        avg_seconds_expr = func.avg(
            case(
                (AlertFact.status != "en_cours",
                 func.extract("epoch", AlertFact.updated_at - AlertFact.created_at)),
            )
        )
        query = select(
            func.count().label("total"),
            func.count(case((AlertFact.status == "rejeter", 1))).label("rejected"),
            func.count(case((AlertFact.status == "traiter", 1))).label("treated"),
            avg_seconds_expr.label("avg_seconds"),
        ).where(AlertFact.forest_id.in_(forest_ids))

        row = (await db.execute(query)).one()
        rejected, treated = row.rejected or 0, row.treated or 0
        reject_rate = round((rejected / (rejected + treated) * 100), 1) if (rejected + treated) else 0.0
        avg_hours   = round((row.avg_seconds or 0) / 3600, 1)

        results.append({
            "supervisor_id":       sup_id,
            "nom":                 users_map.get(sup_id, {}).get("nom") or "Inconnu",
            "forest_count":        len(forest_ids),
            "alert_count":         row.total or 0,
            "reject_rate":         reject_rate,
            "avg_treatment_hours": avg_hours,
        })

    results.sort(key=lambda x: x["alert_count"], reverse=True)
    return results