

// ── §1 Overview KPIs ──────────────────────────────────────
class OverviewData {
  final int     totalAlerts;
  final String? mostAffectedForestId;
  final String? mostAffectedForestName;
  final int     mostAffectedForestCount;
  final double  globalValidationRate;

  const OverviewData({
    required this.totalAlerts,
    this.mostAffectedForestId,
    this.mostAffectedForestName,
    this.mostAffectedForestCount = 0,
    required this.globalValidationRate,
  });

  factory OverviewData.fromJson(Map<String, dynamic> j) => OverviewData(
        totalAlerts:             j['total_alerts']               as int,
        mostAffectedForestId:    j['most_affected_forest_id']    as String?,
        mostAffectedForestName:  j['most_affected_forest_name']  as String?,
        mostAffectedForestCount: j['most_affected_forest_count'] as int? ?? 0,
        globalValidationRate:   (j['global_validation_rate']    as num).toDouble(),
      );
}

// ── §2 Alerts by forest ───────────────────────────────────
class ForestAlertStat {
  final String forestId;
  final String forestName;
  final int    rejectedCount;
  final int    confirmedCount;

  const ForestAlertStat({
    required this.forestId,
    required this.forestName,
    required this.rejectedCount,
    required this.confirmedCount,
  });

  factory ForestAlertStat.fromJson(Map<String, dynamic> j) => ForestAlertStat(
        forestId:       j['forest_id']       as String,
        forestName:     j['forest_name']     as String,
        rejectedCount:  j['rejected_count']  as int,
        confirmedCount: j['confirmed_count'] as int,
      );
}

class AlertsByForestData {
  final List<ForestAlertStat> items;
  final int othersRejectedCount;
  final int othersConfirmedCount;
  final int othersForestCount;

  const AlertsByForestData({
    required this.items,
    this.othersRejectedCount  = 0,
    this.othersConfirmedCount = 0,
    this.othersForestCount    = 0,
  });

  bool get hasOthers => othersForestCount > 0;

  factory AlertsByForestData.fromJson(Map<String, dynamic> j) => AlertsByForestData(
        items: (j['items'] as List? ?? [])
            .map((e) => ForestAlertStat.fromJson(e as Map<String, dynamic>))
            .toList(),
        othersRejectedCount:  j['others_rejected_count']  as int? ?? 0,
        othersConfirmedCount: j['others_confirmed_count'] as int? ?? 0,
        othersForestCount:    j['others_forest_count']    as int? ?? 0,
      );
}

// ── §3 Status trend ────────────────────────────────────────
class StatusTrendPoint {
  final String period;
  final int    enCours;
  final int    traiter;
  final int    rejeter;

  const StatusTrendPoint({
    required this.period,
    required this.enCours,
    required this.traiter,
    required this.rejeter,
  });

  factory StatusTrendPoint.fromJson(Map<String, dynamic> j) => StatusTrendPoint(
        period:  j['period']   as String,
        enCours: j['en_cours'] as int,
        traiter: j['traiter']  as int,
        rejeter: j['rejeter']  as int,
      );
}

// ── §4 Forest × type matrix ────────────────────────────────
class ForestTypeMatrixRow {
  final String            forestId;
  final String            forestName;
  final Map<String, int>  countsByType;

  const ForestTypeMatrixRow({
    required this.forestId,
    required this.forestName,
    required this.countsByType,
  });

  factory ForestTypeMatrixRow.fromJson(Map<String, dynamic> j) => ForestTypeMatrixRow(
        forestId:     j['forest_id']   as String,
        forestName:   j['forest_name'] as String,
        countsByType: Map<String, int>.from(j['counts_by_type'] as Map),
      );
}

// ── §5 Top agents — validation ────────────────────────────
class TopAgentValidation {
  final String agentId;
  final String nom;
  final double rate;

  const TopAgentValidation({
    required this.agentId,
    required this.nom,
    required this.rate,
  });

  factory TopAgentValidation.fromJson(Map<String, dynamic> j) => TopAgentValidation(
        agentId: j['agent_id'] as String,
        nom:     j['nom']      as String,
        rate:    (j['rate'] as num).toDouble(),
      );
}

// ── §5 Top agents — rejet (avec contacts) ─────────────────
class TopAgentRejection {
  final String  agentId;
  final String  nom;
  final double  rate;
  final String? agentPhone;
  final String? agentEmail;
  final String? supervisorId;
  final String? supervisorNom;
  final String? supervisorPhone;
  final String? supervisorEmail;

  const TopAgentRejection({
    required this.agentId,
    required this.nom,
    required this.rate,
    this.agentPhone,
    this.agentEmail,
    this.supervisorId,
    this.supervisorNom,
    this.supervisorPhone,
    this.supervisorEmail,
  });

  factory TopAgentRejection.fromJson(Map<String, dynamic> j) => TopAgentRejection(
        agentId:         j['agent_id']         as String,
        nom:             j['nom']              as String,
        rate:            (j['rate'] as num).toDouble(),
        agentPhone:      j['agent_phone']      as String?,
        agentEmail:      j['agent_email']      as String?,
        supervisorId:    j['supervisor_id']    as String?,
        supervisorNom:   j['supervisor_nom']   as String?,
        supervisorPhone: j['supervisor_phone'] as String?,
        supervisorEmail: j['supervisor_email'] as String?,
      );
}

// ── §6 Supervisor workload ─────────────────────────────────
class SupervisorWorkloadItem {
  final String supervisorId;
  final String nom;
  final int    forestCount;
  final int    alertCount;
  final double rejectRate;
  final double avgTreatmentHours;

  const SupervisorWorkloadItem({
    required this.supervisorId,
    required this.nom,
    required this.forestCount,
    required this.alertCount,
    required this.rejectRate,
    required this.avgTreatmentHours,
  });

  factory SupervisorWorkloadItem.fromJson(Map<String, dynamic> j) => SupervisorWorkloadItem(
        supervisorId:      j['supervisor_id']       as String,
        nom:               j['nom']                 as String,
        forestCount:       j['forest_count']         as int,
        alertCount:        j['alert_count']          as int,
        rejectRate:        (j['reject_rate']         as num).toDouble(),
        avgTreatmentHours: (j['avg_treatment_hours']  as num).toDouble(),
      );
}

class SupervisorWorkloadData {
  final double threshold;
  final List<SupervisorWorkloadItem> items;

  const SupervisorWorkloadData({
    required this.threshold,
    required this.items,
  });

  factory SupervisorWorkloadData.fromJson(Map<String, dynamic> j) => SupervisorWorkloadData(
        threshold: (j['threshold'] as num).toDouble(),
        items: (j['items'] as List? ?? [])
            .map((e) => SupervisorWorkloadItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ── Filtres partagés par tous les widgets ──────────────────
class AnalyticsFilters {
  final String? forestId;
  final String? type;
  final int?    days;

  const AnalyticsFilters({this.forestId, this.type, this.days});

  AnalyticsFilters copyWith({
    String? forestId,
    String? type,
    int?    days,
    bool    clearForestId = false,
    bool    clearType     = false,
    bool    clearDays     = false,
  }) =>
      AnalyticsFilters(
        forestId: clearForestId ? null : (forestId ?? this.forestId),
        type:     clearType     ? null : (type     ?? this.type),
        days:     clearDays     ? null : (days     ?? this.days),
      );

  Map<String, String> toQuery() => {
        if (forestId != null) 'forest_id': forestId!,
        if (type     != null) 'type':      type!,
        if (days     != null) 'days':      days!.toString(),
      };
}