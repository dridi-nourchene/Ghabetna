// features/analytics/models/analytics_models.dart

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

  /// Mock data matching the §7 wireframe numbers — remove once
  /// the real endpoint is wired in.
  factory AlertsByForestData.mock() => const AlertsByForestData(
        items: [
          ForestAlertStat(forestId: '1',  forestName: 'Ichkeul',     rejectedCount: 9, confirmedCount: 31),
          ForestAlertStat(forestId: '2',  forestName: 'Kroumirie',   rejectedCount: 4, confirmedCount: 21),
          ForestAlertStat(forestId: '3',  forestName: 'Zaghouan',    rejectedCount: 5, confirmedCount: 6),
          ForestAlertStat(forestId: '4',  forestName: 'Béja',        rejectedCount: 2, confirmedCount: 8),
          ForestAlertStat(forestId: '5',  forestName: 'Nefza',       rejectedCount: 3, confirmedCount: 14),
          ForestAlertStat(forestId: '6',  forestName: 'Aïn Draham',  rejectedCount: 6, confirmedCount: 12),
          ForestAlertStat(forestId: '7',  forestName: 'Tabarka',     rejectedCount: 1, confirmedCount: 9),
          ForestAlertStat(forestId: '8',  forestName: 'Bulla Regia', rejectedCount: 2, confirmedCount: 5),
          ForestAlertStat(forestId: '9',  forestName: 'Ghardimaou',  rejectedCount: 3, confirmedCount: 4),
          ForestAlertStat(forestId: '10', forestName: 'Fernana',     rejectedCount: 1, confirmedCount: 3),
        ],
        othersRejectedCount:  12,
        othersConfirmedCount: 22,
        othersForestCount:    27,
      );
}