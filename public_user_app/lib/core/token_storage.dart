import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage du jeton JWT dans le coffre sécurisé du système
/// (Keychain sur iOS, EncryptedSharedPreferences sur Android).
class TokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kToken = 'ghabetna_access_token';
  static const _kRefresh = 'ghabetna_refresh_token';
  static const _kSpecialite = 'ghabetna_specialite';

  static Future<void> saveToken(String token) =>
      _storage.write(key: _kToken, value: token);

  static Future<String?> readToken() => _storage.read(key: _kToken);

  static Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _kRefresh, value: token);

  static Future<String?> readRefreshToken() => _storage.read(key: _kRefresh);

  static Future<void> clear() => _storage.deleteAll();

  /// Spécialité du citoyen : chasseur, campeur ou apiculteur.
  ///
  /// Elle vient désormais du JWT, écrite ici juste après la connexion.
  /// chat_provider la lit sans savoir d'où elle sort : c'est ce qui permet
  /// au sélecteur manuel de disparaître sans toucher au code du chat.
  static Future<void> saveSpecialite(String s) =>
      _storage.write(key: _kSpecialite, value: s);

  static Future<String?> readSpecialite() => _storage.read(key: _kSpecialite);

  // ── Décodage du JWT ─────────────────────────────────────────────────
  // Le jeton n'est PAS chiffré, seulement signé : on peut lire son contenu
  // sans la clé secrète. On ne vérifie donc rien ici — la signature est
  // contrôlée par le gateway. On se contente d'extraire les claims pour
  // savoir quoi afficher.

  static Map<String, dynamic> decode(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      // normalize() rajoute le padding '=' que le base64Url du JWT omet :
      // sans lui, le décodage échoue une fois sur trois selon la longueur.
      final normalise = base64Url.normalize(parts[1]);
      final json = utf8.decode(base64Url.decode(normalise));
      final data = jsonDecode(json);
      return data is Map<String, dynamic> ? data : {};
    } catch (_) {
      return {};
    }
  }

  /// Vrai si le jeton est absent, illisible ou périmé.
  ///
  /// Marge de 30 secondes : un jeton qui expire pendant le vol de la requête
  /// serait refusé par le serveur alors que le client le croyait valide.
  static bool estExpire(String? token) {
    if (token == null || token.isEmpty) return true;
    final exp = decode(token)['exp'];
    if (exp is! int) return true;
    final expiration = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    return DateTime.now().add(const Duration(seconds: 30)).isAfter(expiration);
  }
}
