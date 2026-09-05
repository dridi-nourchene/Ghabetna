/// Configuration réseau de l'application.
class ApiConfig {
  ApiConfig._();

  /// Adresse du gateway.
  ///
  /// Prise en variable de compilation plutôt qu'écrite en dur : l'IP change
  /// d'un réseau à l'autre, et on ne veut pas recompiler après édition du
  /// code le jour d'une démonstration.
  ///
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000
  ///
  /// Sur émulateur Android, l'hôte de la machine est 10.0.2.2.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.70:8000',
  );

  /// Le premier appel après un démarrage de chatbot_ms attend le chargement
  /// du modèle d'embedding (10 à 20 s). Les suivants coûtent environ 1 s.
  static const Duration chatTimeout = Duration(seconds: 90);
  static const Duration defaultTimeout = Duration(seconds: 20);
  static const uploadTimeout = Duration(seconds: 120);

  // Routes du gateway
  static const String chat = '/api/chat/';
  static const String me = '/api/auth/me';
  static const login = '/api/auth/login';
  static const refresh = '/api/auth/refresh';
  static const inscription = '/api/citoyens/inscription';
  static const monDossier = '/api/citoyens/mon-dossier';
  static const alertes = '/api/alerts/';
  static const mesAlertes = '/api/alerts/mine';
  static const forets = '/api/forests/';
}
