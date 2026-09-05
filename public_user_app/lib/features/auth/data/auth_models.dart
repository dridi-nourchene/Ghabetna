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
    this.fullName,
    this.specialite,
  });

  final String userId;
  final String email;
  final String role;

  /// Nom complet, ajouté aux claims d'auth_ms le 22/08/2026.
  ///
  /// Nullable et pas `required` : un jeton émis AVANT cette modification ne
  /// contient pas le champ. Il reste valide jusqu'à sa péremption (30 min),
  /// après quoi le refresh en fabrique un nouveau qui, lui, l'aura. Rendre
  /// le champ obligatoire ferait planter l'application pendant cette
  /// demi-heure de transition.
  final String? fullName;

  final String? specialite;

  /// Le personnel (admin, superviseur, agent) n'a pas de spécialité.
  bool get estCitoyen => role == 'citoyen';

  /// Ce qu'on affiche quand on veut désigner la personne.
  ///
  /// L'email est un repli acceptable : il identifie sans ambiguïté et le
  /// citoyen le reconnaît, contrairement à un « Utilisateur » générique.
  String get nomAffiche =>
      (fullName != null && fullName!.trim().isNotEmpty)
          ? fullName!.trim()
          : email;

  /// Initiales pour un avatar, si un écran en a besoin plus tard.
  /// « Ben Salah Mohamed » → « BM ». Un seul mot → une seule lettre.
  String get initiales {
    final mots = nomAffiche
        .trim()
        .split(RegExp(r'\s+'))
        .where((m) => m.isNotEmpty)
        .toList();
    if (mots.isEmpty) return '?';
    if (mots.length == 1) return mots.first[0].toUpperCase();
    return (mots.first[0] + mots.last[0]).toUpperCase();
  }

  factory Session.depuisJwt(String token) {
    final claims = TokenStorage.decode(token);
    return Session(
      userId: claims['user_id']?.toString() ?? '',
      email: claims['email']?.toString() ?? '',
      role: claims['role']?.toString() ?? '',
      fullName: claims['full_name']?.toString(),
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
