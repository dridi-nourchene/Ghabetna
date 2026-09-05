/// Modèles de l'alerte. Miroir des schémas Pydantic d'alert_ms
/// (app/models/alert.py, app/schemas/alert.py) — même vocabulaire, même
/// valeurs d'énumération, pour ne jamais avoir à traduire côté client.
library;

/// Les 9 types déclarés côté backend. Rien n'y distingue un type « agent »
/// d'un type « citoyen » : chasse_illegale, depot_dechets et
/// activite_suspecte ont été ajoutés pensés pour le citoyen, mais
/// l'ensemble reste ouvert à tout signalant authentifié.
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

  String get libelle => switch (this) {
        AlertType.incendie => 'Incendie',
        AlertType.vol => 'Vol',
        AlertType.inondation => 'Inondation',
        AlertType.glissement => 'Glissement de terrain',
        AlertType.maladie => 'Maladie forestière',
        AlertType.depot_dechets => 'Dépôt de déchets',
        AlertType.chasse_illegale => 'Chasse illégale',
        AlertType.activite_suspecte => 'Activité suspecte',
        AlertType.autre => 'Autre',
      };

  String get emoji => switch (this) {
        AlertType.incendie => '🔥',
        AlertType.vol => '🔒',
        AlertType.inondation => '💧',
        AlertType.glissement => '⛰️',
        AlertType.maladie => '🌿',
        AlertType.depot_dechets => '🗑️',
        AlertType.chasse_illegale => '🐾',
        AlertType.activite_suspecte => '👀',
        AlertType.autre => '⚠️',
      };

  /// Valeur envoyée au serveur — le nom de l'enum Python, tel quel.
  String get valeur => name;

  static AlertType depuis(String v) => AlertType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => AlertType.autre,
      );
}

enum AlertStatus {
  en_cours,
  traiter,
  rejeter;

  String get libelle => switch (this) {
        AlertStatus.en_cours => 'En cours',
        AlertStatus.traiter => 'Traitée',
        AlertStatus.rejeter => 'Rejetée',
      };

  static AlertStatus depuis(String v) => AlertStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => AlertStatus.en_cours,
      );
}

class ForestSimple {
  const ForestSimple({required this.id, required this.nom});

  final String id;
  final String nom;

  factory ForestSimple.fromJson(Map<String, dynamic> j) => ForestSimple(
        id: j['id'] as String,
        nom: j['name'] as String,
      );
}

class AlertModel {
  const AlertModel({
    required this.id,
    required this.forestId,
    required this.type,
    required this.status,
    this.description,
    this.forestName,
    this.imageUrl,
    this.supervisorComment,
    required this.createdAt,
  });

  final String id;
  final String forestId;
  final AlertType type;
  final AlertStatus status;
  final String? description;
  final String? forestName;
  final String? imageUrl;
  final String? supervisorComment;
  final DateTime createdAt;

  factory AlertModel.fromJson(Map<String, dynamic> j) => AlertModel(
        id: j['id'] as String,
        forestId: j['forest_id'] as String,
        type: AlertType.depuis(j['type'] as String),
        status: AlertStatus.depuis(j['status'] as String),
        description: j['description'] as String?,
        forestName: j['forest_name'] as String?,
        imageUrl: j['image_url'] as String?,
        supervisorComment: j['supervisor_comment'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
