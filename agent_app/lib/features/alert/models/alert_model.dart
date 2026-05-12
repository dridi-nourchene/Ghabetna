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

class AlertModel {
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
  final DateTime    createdAt;

  const AlertModel({
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
    required this.createdAt,
  });

  factory AlertModel.fromJson(Map<String, dynamic> j) => AlertModel(
        id:           j['id'],
        type:         AlertType.fromString(j['type']),
        status:       AlertStatus.fromString(j['status']),
        description:  j['description'],
        latitude:     (j['latitude'] as num).toDouble(),
        longitude:    (j['longitude'] as num).toDouble(),
        imageUrl:     j['image_url'],
        agentId:      j['agent_id'],
        forestId:     j['forest_id'],
        adminComment: j['admin_comment'],
        createdAt:    DateTime.parse(j['created_at']),
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