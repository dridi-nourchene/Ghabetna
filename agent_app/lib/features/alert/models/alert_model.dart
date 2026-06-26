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
    AlertType.glissement        => 'Glissement de terrain',
    AlertType.maladie           => 'Maladie forestière',
    AlertType.depot_dechets     => 'Dépôt des déchets',
    AlertType.chasse_illegale   => 'Chasse illégale',
    AlertType.activite_suspecte => 'Activité suspecte',
    AlertType.autre             => 'Autre',
  };

  String get emoji => switch (this) {
    AlertType.incendie          => '🔥',
    AlertType.vol               => '🔒',
    AlertType.inondation        => '💧',
    AlertType.glissement        => '⛰️',
    AlertType.maladie           => '🌿',
    AlertType.depot_dechets     => '🗑️',
    AlertType.chasse_illegale   => '🐾',
    AlertType.activite_suspecte => '👀',
    AlertType.autre             => '⚠️',
  };

  String get value => name;

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

enum LocationSource {
  exif,
  agent_gps,
  forest_only;

  String get label => switch (this) {
    LocationSource.exif        => 'GPS photo',
    LocationSource.agent_gps   => 'GPS téléphone',
    LocationSource.forest_only => 'Forêt uniquement',
  };

  static LocationSource fromString(String v) =>
      LocationSource.values.firstWhere((e) => e.name == v,
          orElse: () => LocationSource.forest_only);
}

// ── Agent dans la zone ────────────────────────────────────────

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
    nom:          j['nom']          as String? ?? '',
    phone:        j['phone']        as String? ?? '',
    parcelleName: j['parcelle_name'] as String?,
  );
}

// ── Modèle principal ──────────────────────────────────────────

class AlertModel {
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

  // Enrichissements backend
  final String?        agentNom;
  final String?        agentPhone;
  final String?        forestName;
  final List<ZoneAgent> zoneAgents;

  // Média
  final String?        imageUrl;

  // Superviseur
  final String?        supervisorComment;
  final String?        supervisorId;
  final DateTime?      commentedAt;

  // Dates
  final DateTime       createdAt;
  final DateTime?      updatedAt;

  const AlertModel({
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

  factory AlertModel.fromJson(Map<String, dynamic> j) => AlertModel(
    id:               j['id']        as String,
    agentId:          j['agent_id']  as String,
    forestId:         j['forest_id'] as String,
    type:             AlertType.fromString(j['type'] as String),
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

// ── ForestSimple (inchangé) ───────────────────────────────────

class ForestSimple {
  final String id;
  final String name;

  const ForestSimple({required this.id, required this.name});

  factory ForestSimple.fromJson(Map<String, dynamic> j) => ForestSimple(
    id:   j['id']   as String,
    name: j['name'] as String,
  );
}