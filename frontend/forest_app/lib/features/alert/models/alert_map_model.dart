// frontend/forest_app/lib/features/alert/models/alert_map_model.dart

enum AlertType {
  incendie,
  vol,
  inondation,
  glissement,
  maladie,
  depot_dechets,
  chasse_illegale,
  activite_suspecte,
  autre;

  String get label => switch (this) {
    AlertType.incendie          => 'Incendie',
    AlertType.vol               => 'Vol',
    AlertType.inondation        => 'Inondation',
    AlertType.glissement        => 'Glissement',
    AlertType.maladie           => 'Maladie',
    AlertType.depot_dechets     => 'Dépôt des déchets',
    AlertType.chasse_illegale   => 'Chasse illégale',
    AlertType.activite_suspecte => 'Activité suspecte',
    AlertType.autre             => 'Autre',
  };

  String get emoji => switch (this) {
    AlertType.incendie          => '🔥',
    AlertType.vol               => '🚨',
    AlertType.inondation        => '💧',
    AlertType.glissement        => '⛰️',
    AlertType.maladie           => '🌿',
    AlertType.depot_dechets     => '🗑️',
    AlertType.chasse_illegale   => '🐾',
    AlertType.activite_suspecte => '👀',
    AlertType.autre             => '⚠️',
  };

  static AlertType fromString(String s) =>
      AlertType.values.firstWhere((e) => e.name == s,
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

  static AlertStatus fromString(String s) =>
      AlertStatus.values.firstWhere((e) => e.name == s,
          orElse: () => AlertStatus.en_cours);
}

enum LocationSource {
  exif,
  agent_gps,
  forest_only;

  static LocationSource fromString(String s) =>
      LocationSource.values.firstWhere((e) => e.name == s,
          orElse: () => LocationSource.forest_only);
}

// ── Agent dans la zone ────────────────────────────────────────
// Aligné sur la réponse backend : { nom, phone, parcelle_name }

class ZoneAgent {
  final String  nom;
  final String  phone;
  final String? parcelleName;

  const ZoneAgent({
    required this.nom,
    required this.phone,
    this.parcelleName,
  });

  factory ZoneAgent.fromJson(Map<String, dynamic> j) => ZoneAgent(
    nom:          j['nom']           as String? ?? '',
    phone:        j['phone']         as String? ?? '',
    parcelleName: j['parcelle_name'] as String?,
  );
}

// ── Map point (léger, pour la carte) ─────────────────────────

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
    id:             j['id']        as String,
    type:           AlertType.fromString(j['type'] as String),
    status:         AlertStatus.fromString(j['status'] as String),
    incidentLat:    (j['incident_lat'] as num?)?.toDouble(),
    incidentLng:    (j['incident_lng'] as num?)?.toDouble(),
    locationSource: LocationSource.fromString(
                        j['location_source'] as String? ?? 'forest_only'),
    forestId:       j['forest_id'] as String,
    createdAt:      DateTime.parse(j['created_at'] as String),
  );
}

// ── Détail complet ────────────────────────────────────────────
// Aligné sur AlertDetailResponse du backend

class AlertDetail {
  final String         id;
  final String         agentId;
  final String         forestId;
  final AlertType      type;
  final AlertStatus    status;
  final String?        description;

  // Localisation
  final double?        incidentLat;
  final double?        incidentLng;
  final double?        agentLat;
  final double?        agentLng;
  final LocationSource locationSource;

  // Enrichissements
  final String?        agentNom;       // ← remplace emitting_agent.nom
  final String?        agentPhone;     // ← remplace emitting_agent.phone
  final String?        forestName;     // ← nom forêt si approximatif
  final List<ZoneAgent> zoneAgents;    // ← agents dans la zone

  // Média
  final String?        imageUrl;

  // Superviseur
  final String?        supervisorComment;
  final String?        supervisorId;
  final DateTime?      commentedAt;

  // Dates
  final DateTime       createdAt;
  final DateTime?      updatedAt;

  const AlertDetail({
    required this.id,
    required this.agentId,
    required this.forestId,
    required this.type,
    required this.status,
    this.description,
    this.incidentLat,
    this.incidentLng,
    this.agentLat,
    this.agentLng,
    required this.locationSource,
    this.agentNom,
    this.agentPhone,
    this.forestName,
    this.zoneAgents = const [],
    this.imageUrl,
    this.supervisorComment,
    this.supervisorId,
    this.commentedAt,
    required this.createdAt,
    this.updatedAt,
  });

  /// Distance approximative incident ↔ agent (km)
  double? get distanceKm {
    if (incidentLat == null || agentLat == null) return null;
    const r    = 6371.0;
    final dLat = (incidentLat! - agentLat!) * 3.14159265 / 180;
    final dLng = (incidentLng! - agentLng!) * 3.14159265 / 180;
    final a    = (dLat / 2) * (dLat / 2) + (dLng / 2) * (dLng / 2);
    return r * 2 * (a < 1 ? a : 1);
  }

  factory AlertDetail.fromJson(Map<String, dynamic> j) => AlertDetail(
    id:               j['id']        as String,
    agentId:          j['agent_id']  as String,
    forestId:         j['forest_id'] as String,
    type:             AlertType.fromString(j['type']   as String),
    status:           AlertStatus.fromString(j['status'] as String),
    description:      j['description'] as String?,
    incidentLat:      (j['incident_lat'] as num?)?.toDouble(),
    incidentLng:      (j['incident_lng'] as num?)?.toDouble(),
    agentLat:         (j['agent_lat']    as num?)?.toDouble(),
    agentLng:         (j['agent_lng']    as num?)?.toDouble(),
    locationSource:   LocationSource.fromString(
                          j['location_source'] as String? ?? 'forest_only'),
    agentNom:         j['agent_nom']   as String?,
    agentPhone:       j['agent_phone'] as String?,
    forestName:       j['forest_name'] as String?,
    zoneAgents:       (j['zone_agents'] as List? ?? [])
                          .map((e) => ZoneAgent.fromJson(e as Map<String, dynamic>))
                          .toList(),
    imageUrl:         j['image_url']  as String?,
    supervisorComment: j['supervisor_comment'] as String?,
    supervisorId:     j['supervisor_id'] as String?,
    commentedAt:      j['commented_at'] != null
                          ? DateTime.tryParse(j['commented_at'] as String)
                          : null,
    createdAt:        DateTime.parse(j['created_at'] as String),
    updatedAt:        j['updated_at'] != null
                          ? DateTime.tryParse(j['updated_at'] as String)
                          : null,
  );
}