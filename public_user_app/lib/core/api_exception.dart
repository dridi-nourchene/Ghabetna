/// Erreur remontée par le client HTTP.
///
/// On distingue les cas pour que l'interface affiche un message utile
/// plutôt qu'une trace technique.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final ApiErrorKind kind;

  const ApiException(this.message, {this.statusCode, required this.kind});

  factory ApiException.network() => const ApiException(
        'Impossible de joindre le serveur. Vérifiez votre connexion.',
        kind: ApiErrorKind.network,
      );

  factory ApiException.timeout() => const ApiException(
        'Le serveur met trop de temps à répondre.',
        kind: ApiErrorKind.timeout,
      );

  factory ApiException.unauthorized() => const ApiException(
        'Votre session a expiré. Reconnectez-vous.',
        statusCode: 401,
        kind: ApiErrorKind.unauthorized,
      );

  @override
  String toString() => message;
}

enum ApiErrorKind { network, timeout, unauthorized, server, unknown }
