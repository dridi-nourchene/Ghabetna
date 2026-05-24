

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
        AlertType.vol        => '🚨',
        AlertType.inondation => '💧',
        AlertType.glissement => '⛰️',
        AlertType.maladie    => '🌿',
        AlertType.autre      => '⚠️',
      };

  static AlertType fromString(String s) =>
      AlertType.values.firstWhere((e) => e.name == s, orElse: () => AlertType.autre);
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

  static AlertStatus fromString(String s) =>
      AlertStatus.values.firstWhere((e) => e.name == s, orElse: () => AlertStatus.en_cours);
}

enum LocationSource {
  exif,
  agent_gps,
  forest_only;

  static LocationSource fromString(String s) =>
      LocationSource.values.firstWhere((e) => e.name == s, orElse: () => LocationSource.forest_only);
}


// ── Map point (léger) ─────────────────────────────────────────

class AlertMapPoint {
  final String         id;
  final AlertType      type;
  final AlertStatus    status;
  final double?        incidentLat;
  final double?        incidentLng;
  final LocationSource locationSource;
  final String         forestId;
  final DateTime       createdAt;

  const AlertMapPoint({
    required this.id,
    required this.type,
    required this.status,
    this.incidentLat,
    this.incidentLng,
    required this.locationSource,
    required this.forestId,
    required this.createdAt,
  });

  bool get hasExactLocation =>
      incidentLat != null && incidentLng != null;

  factory AlertMapPoint.fromJson(Map<String, dynamic> j) => AlertMapPoint(
        id:             j['id'] as String,
        type:           AlertType.fromString(j['type'] as String),
        status:         AlertStatus.fromString(j['status'] as String),
        incidentLat:    (j['incident_lat'] as num?)?.toDouble(),
        incidentLng:    (j['incident_lng'] as num?)?.toDouble(),
        locationSource: LocationSource.fromString(j['location_source'] as String),
        forestId:       j['forest_id'] as String,
        createdAt:      DateTime.parse(j['created_at'] as String),
      );
}


// ── Détail complet ────────────────────────────────────────────

class AlertDetail {
  final String         id;
  final AlertType      type;
  final AlertStatus    status;
  final String?        description;
  final double?        incidentLat;
  final double?        incidentLng;
  final double?        agentLat;
  final double?        agentLng;
  final LocationSource locationSource;
  final String?        imageUrl;
  final String         agentId;
  final String         forestId;
  final String?        supervisorComment;
  final String?        supervisorId;
  final DateTime?      commentedAt;
  final DateTime       createdAt;
  final DateTime?      updatedAt;

  const AlertDetail({
    required this.id,
    required this.type,
    required this.status,
    this.description,
    this.incidentLat,
    this.incidentLng,
    this.agentLat,
    this.agentLng,
    required this.locationSource,
    this.imageUrl,
    required this.agentId,
    required this.forestId,
    this.supervisorComment,
    this.supervisorId,
    this.commentedAt,
    required this.createdAt,
    this.updatedAt,
  });

  double? get distanceKm {
    if (incidentLat == null || agentLat == null) return null;
    // Haversine simplifié
    const r = 6371.0;
    final dLat = (incidentLat! - agentLat!) * 3.14159265 / 180;
    final dLng = (incidentLng! - agentLng!) * 3.14159265 / 180;
    final a = (dLat / 2) * (dLat / 2) +
        (dLng / 2) * (dLng / 2);
    return r * 2 * (a < 1 ? a : 1);
  }

  factory AlertDetail.fromJson(Map<String, dynamic> j) => AlertDetail(
        id:                j['id'] as String,
        type:              AlertType.fromString(j['type'] as String),
        status:            AlertStatus.fromString(j['status'] as String),
        description:       j['description'] as String?,
        incidentLat:       (j['incident_lat'] as num?)?.toDouble(),
        incidentLng:       (j['incident_lng'] as num?)?.toDouble(),
        agentLat:          (j['agent_lat'] as num?)?.toDouble(),
        agentLng:          (j['agent_lng'] as num?)?.toDouble(),
        locationSource:    LocationSource.fromString(j['location_source'] as String),
        imageUrl:          j['image_url'] as String?,
        agentId:           j['agent_id'] as String,
        forestId:          j['forest_id'] as String,
        supervisorComment: j['supervisor_comment'] as String?,
        supervisorId:      j['supervisor_id'] as String?,
        commentedAt:       j['commented_at'] != null
            ? DateTime.tryParse(j['commented_at'] as String)
            : null,
        createdAt:         DateTime.parse(j['created_at'] as String),
        updatedAt:         j['updated_at'] != null
            ? DateTime.tryParse(j['updated_at'] as String)
            : null,
      );
}