import '../../../core/token_storage.dart';

/// Ce que l'application sait de l'utilisateur connecté.
///
/// Tout vient du JWT : aucun appel réseau n'est nécessaire pour connaître le
/// rôle ou la spécialité. C'est l'intérêt d'un jeton signé — il transporte
/// l'identité avec lui.
class Session {
  const Session({
    required this.userId,
    required this.email,
    required this.role,
    this.specialite,
  });

  final String userId;
  final String email;
  final String role;
  final String? specialite;

  /// Le personnel (admin, superviseur, agent) n'a pas de spécialité.
  bool get estCitoyen => role == 'citoyen';

  factory Session.depuisJwt(String token) {
    final claims = TokenStorage.decode(token);
    return Session(
      userId: claims['user_id']?.toString() ?? '',
      email: claims['email']?.toString() ?? '',
      role: claims['role']?.toString() ?? '',
      specialite: claims['specialite']?.toString(),
    );
  }
}

/// Réponse de POST /api/auth/login.
class Jetons {
  const Jetons({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  factory Jetons.fromJson(Map<String, dynamic> j) => Jetons(
        accessToken: j['access_token'] as String? ?? '',
        refreshToken: j['refresh_token'] as String? ?? '',
      );
}
