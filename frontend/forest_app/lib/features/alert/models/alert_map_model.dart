// features/alert/models/alert_map_model.dart

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

// ── Source de localisation ────────────────────────────────────
enum LocationSource {
  exif,
  agent_gps,
  forest_only;

  static LocationSource fromString(String v) =>
      LocationSource.values.firstWhere((e) => e.name == v,
          orElse: () => LocationSource.forest_only);
}

// ── Point léger pour la map (polling) ────────────────────────
// incident_lat / incident_lng peuvent être null (pas d'EXIF)
// Dans ce cas on utilise le centroïde de la forêt côté Flutter

class AlertMapPoint {
  final String         id;
  final AlertType      type;
  final AlertStatus    status;
  final double?        incidentLat;    // null si pas d'EXIF
  final double?        incidentLng;    // null si pas d'EXIF
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

  /// Retourne true si on a des coordonnées EXIF précises
  bool get hasExactLocation =>
      incidentLat != null && incidentLng != null;

  factory AlertMapPoint.fromJson(Map<String, dynamic> j) => AlertMapPoint(
        id:             j['id'],
        type:           AlertType.fromString(j['type']),
        status:         AlertStatus.fromString(j['status']),
        incidentLat:    (j['incident_lat'] as num?)?.toDouble(),
        incidentLng:    (j['incident_lng'] as num?)?.toDouble(),
        locationSource: LocationSource.fromString(
            j['location_source'] ?? 'forest_only'),
        forestId:       j['forest_id'],
        createdAt:      DateTime.parse(j['created_at']),
      );
}

// ── Détail complet (popup admin) ──────────────────────────────

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
  final String?        adminComment;
  final String?        adminId;
  final DateTime?      commentedAt;
  final DateTime       createdAt;

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
    this.adminComment,
    this.adminId,
    this.commentedAt,
    required this.createdAt,
  });

  /// Distance en km entre position agent et incident (si les deux disponibles)
  double? get distanceKm {
    if (incidentLat == null || incidentLng == null ||
        agentLat == null || agentLng == null) return null;
    // Formule Haversine simplifiée
    const r = 6371.0;
    final dLat = (incidentLat! - agentLat!) * 3.14159 / 180;
    final dLng = (incidentLng! - agentLng!) * 3.14159 / 180;
    final a = (dLat / 2) * (dLat / 2) +
        ((agentLat! * 3.14159 / 180) *
            (incidentLat! * 3.14159 / 180) *
            (dLng / 2) * (dLng / 2));
    return r * 2 * (a < 1 ? a : 1);
  }

  factory AlertDetail.fromJson(Map<String, dynamic> j) => AlertDetail(
        id:             j['id'],
        type:           AlertType.fromString(j['type']),
        status:         AlertStatus.fromString(j['status']),
        description:    j['description'],
        incidentLat:    (j['incident_lat'] as num?)?.toDouble(),
        incidentLng:    (j['incident_lng'] as num?)?.toDouble(),
        agentLat:       (j['agent_lat']    as num?)?.toDouble(),
        agentLng:       (j['agent_lng']    as num?)?.toDouble(),
        locationSource: LocationSource.fromString(
            j['location_source'] ?? 'forest_only'),
        imageUrl:       j['image_url'],
        agentId:        j['agent_id'],
        forestId:       j['forest_id'],
        adminComment:   j['admin_comment'],
        adminId:        j['admin_id'],
        commentedAt:    j['commented_at'] != null
            ? DateTime.parse(j['commented_at'])
            : null,
        createdAt:      DateTime.parse(j['created_at']),
      );
}