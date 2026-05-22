enum AlertType {
  incendie, vol, inondation, glissement, maladie, autre;

  String get label => switch (this) {
    AlertType.incendie   => 'Incendie',
    AlertType.vol        => 'Vol',
    AlertType.inondation => 'Inondation',
    AlertType.glissement => 'Glissement de terrain',
    AlertType.maladie    => 'Maladie forestière',
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

  String get value => name;

  static AlertType fromString(String v) =>
      AlertType.values.firstWhere((e) => e.name == v,
          orElse: () => AlertType.autre);
}

enum AlertStatus {
  en_cours, traiter, rejeter;

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
  exif, agent_gps, forest_only;

  String get label => switch (this) {
    LocationSource.exif        => 'GPS photo',
    LocationSource.agent_gps   => 'GPS téléphone',
    LocationSource.forest_only => 'Forêt uniquement',
  };

  static LocationSource fromString(String v) =>
      LocationSource.values.firstWhere((e) => e.name == v,
          orElse: () => LocationSource.forest_only);
}

class AlertModel {
  final String          id;
  final AlertType       type;
  final AlertStatus     status;
  final String?         description;
  final double?         incidentLat;
  final double?         incidentLng;
  final double?         agentLat;
  final double?         agentLng;
  final LocationSource  locationSource;
  final String?         imageUrl;
  final String          agentId;
  final String          forestId;
  final String?         adminComment;
  final DateTime        createdAt;

  const AlertModel({
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
    required this.createdAt,
  });

  factory AlertModel.fromJson(Map<String, dynamic> j) => AlertModel(
    id:             j['id'],
    type:           AlertType.fromString(j['type']),
    status:         AlertStatus.fromString(j['status']),
    description:    j['description'],
    incidentLat:    (j['incident_lat'] as num?)?.toDouble(),
    incidentLng:    (j['incident_lng'] as num?)?.toDouble(),
    agentLat:       (j['agent_lat']    as num?)?.toDouble(),
    agentLng:       (j['agent_lng']    as num?)?.toDouble(),
    locationSource: LocationSource.fromString(j['location_source'] ?? 'forest_only'),
    imageUrl:       j['image_url'],
    agentId:        j['agent_id'],
    forestId:       j['forest_id'],
    adminComment:   j['admin_comment'],
    createdAt:      DateTime.parse(j['created_at']),
  );
}

class ForestSimple {
  final String id;
  final String name;

  const ForestSimple({required this.id, required this.name});

  factory ForestSimple.fromJson(Map<String, dynamic> j) => ForestSimple(
    id:   j['id'],
    name: j['name'],
  );
}