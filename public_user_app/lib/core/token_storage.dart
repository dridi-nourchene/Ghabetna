import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage du jeton JWT dans le coffre sécurisé du système
/// (Keychain sur iOS, EncryptedSharedPreferences sur Android).
class TokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kToken = 'ghabetna_access_token';
  static const _kSpecialite = 'ghabetna_specialite';

  static Future<void> saveToken(String token) =>
      _storage.write(key: _kToken, value: token);

  static Future<String?> readToken() => _storage.read(key: _kToken);

  static Future<void> clear() => _storage.deleteAll();

  /// Spécialité du citoyen : chasseur, campeur ou apiculteur.
  ///
  /// Elle sera lue depuis le JWT dès que l'authentification citoyenne
  /// existera. En attendant elle est stockée localement, ce qui permet de
  /// développer l'écran de chat sans dépendre de auth_ms.
  static Future<void> saveSpecialite(String s) =>
      _storage.write(key: _kSpecialite, value: s);

  static Future<String?> readSpecialite() => _storage.read(key: _kSpecialite);
}
