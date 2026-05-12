enum AlertType {
  incendie,
  vol,
  inondation,
  glissement,
  maladie,
  autre;

  String get label => switch (this) {
        AlertType.incendie   => 'Incendie',
        AlertType.vol        => 'Vol',
        AlertType.inondation => 'Inondation',
        AlertType.glissement => 'Glissement',
        AlertType.maladie    => 'Maladie',
        AlertType.autre      => 'Autre',
      };

  String get emoji => switch (this) {
        AlertType.incendie   => '🔥',
        AlertType.vol        => '🔒',
        AlertType.inondation => '💧',
        AlertType.glissement => '⛰️',
        AlertType.maladie    => '🌿',
        AlertType.autre      => '⚠️',
      };

  static AlertType fromString(String v) =>
      AlertType.values.firstWhere((e) => e.name == v,
          orElse: () => AlertType.autre);
}

enum AlertStatus {
  en_cours,
  traiter,
  rejeter;

  String get label => switch (this) {
        AlertStatus.en_cours => 'En cours',
        AlertStatus.traiter  => 'Traitée',
        AlertStatus.rejeter  => 'Rejetée',
      };

  static AlertStatus fromString(String v) =>
      AlertStatus.values.firstWhere((e) => e.name == v,
          orElse: () => AlertStatus.en_cours);
}

// ── Point léger pour la map (polling) ────────────────────────

class AlertMapPoint {
  final String      id;
  final AlertType   type;
  final AlertStatus status;
  final double      latitude;
  final double      longitude;
  final String      forestId;
  final DateTime    createdAt;

  const AlertMapPoint({
    required this.id,
    required this.type,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.forestId,
    required this.createdAt,
  });

  factory AlertMapPoint.fromJson(Map<String, dynamic> j) => AlertMapPoint(
        id:        j['id'],
        type:      AlertType.fromString(j['type']),
        status:    AlertStatus.fromString(j['status']),
        latitude:  (j['latitude']  as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        forestId:  j['forest_id'],
        createdAt: DateTime.parse(j['created_at']),
      );
}

// ── Détail complet (popup admin) ──────────────────────────────

class AlertDetail {
  final String      id;
  final AlertType   type;
  final AlertStatus status;
  final String?     description;
  final double      latitude;
  final double      longitude;
  final String?     imageUrl;
  final String      agentId;
  final String      forestId;
  final String?     adminComment;
  final String?     adminId;
  final DateTime?   commentedAt;
  final DateTime    createdAt;

  const AlertDetail({
    required this.id,
    required this.type,
    required this.status,
    this.description,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    required this.agentId,
    required this.forestId,
    this.adminComment,
    this.adminId,
    this.commentedAt,
    required this.createdAt,
  });

  factory AlertDetail.fromJson(Map<String, dynamic> j) => AlertDetail(
        id:           j['id'],
        type:         AlertType.fromString(j['type']),
        status:       AlertStatus.fromString(j['status']),
        description:  j['description'],
        latitude:     (j['latitude']  as num).toDouble(),
        longitude:    (j['longitude'] as num).toDouble(),
        imageUrl:     j['image_url'],
        agentId:      j['agent_id'],
        forestId:     j['forest_id'],
        adminComment: j['admin_comment'],
        adminId:      j['admin_id'],
        commentedAt:  j['commented_at'] != null
            ? DateTime.parse(j['commented_at'])
            : null,
        createdAt:    DateTime.parse(j['created_at']),
      );
}