import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_config.dart';
import 'api_exception.dart';
import 'fichier_joint.dart';
import 'token_storage.dart';

/// Client HTTP de l'application.
///
/// Injecte le jeton, sérialise le JSON, traduit les erreurs réseau en
/// [ApiException] lisibles. Toutes les requêtes passent par le gateway :
/// l'application n'appelle jamais un microservice directement.
class ApiClient {
  const ApiClient();

  Future<Map<String, String>> _headers() async {
    final token = await TokenStorage.readToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    try {
      final response = await http
          .post(uri,
              headers: await _headers(), body: jsonEncode(body ?? const {}))
          .timeout(timeout ?? ApiConfig.defaultTimeout);
      return _decode(response);
    } on SocketException {
      throw ApiException.network();
    } on HttpException {
      throw ApiException.network();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.timeout();
    }
  }

  Future<Map<String, dynamic>> get(String path, {Duration? timeout}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    try {
      final response = await http
          .get(uri, headers: await _headers())
          .timeout(timeout ?? ApiConfig.defaultTimeout);
      return _decode(response);
    } on SocketException {
      throw ApiException.network();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.timeout();
    }
  }

  // ── Envoi multipart ─────────────────────────────────────────────────
  /// Utilisé uniquement par l'inscription : c'est le seul appel qui
  /// transporte des fichiers.
  ///
  /// On ne passe PAS par [post] : celle-ci fait jsonEncode et impose
  /// Content-Type: application/json, ce qui détruirait les fichiers.
  /// MultipartRequest génère lui-même son Content-Type avec la frontière
  /// qui délimite les parties — il ne faut jamais l'écraser à la main.
  ///
  /// Aucun jeton n'est envoyé : le citoyen n'a pas encore de compte, et la
  /// route est déclarée publique dans PUBLIC_ROUTES du gateway.
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> champs,
    required Map<String, FichierJoint> fichiers,
    Duration? timeout,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    try {
      final requete = http.MultipartRequest('POST', uri);

      // Les champs vides ne sont pas envoyés du tout. Envoyer "" ferait
      // échouer la conversion en date ou en entier côté citizen_ms — c'est
      // exactement le 422 rencontré pendant les tests Swagger.
      champs.forEach((cle, valeur) {
        if (valeur.trim().isNotEmpty) requete.fields[cle] = valeur;
      });

      fichiers.forEach((cle, f) {
        final parts = f.mimeType.split('/');
        requete.files.add(
          http.MultipartFile.fromBytes(
            cle,
            f.octets,
            filename: f.nom,
            contentType: parts.length == 2
                ? MediaType(parts[0], parts[1])
                : MediaType('application', 'octet-stream'),
          ),
        );
      });

      final streamed =
          await requete.send().timeout(timeout ?? ApiConfig.uploadTimeout);
      final response = await http.Response.fromStream(streamed);
      return _decode(response);
    } on SocketException {
      throw ApiException.network();
    } on HttpException {
      throw ApiException.network();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.timeout();
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    // utf8.decode explicite : sans lui, les accents des textes juridiques
    // reviennent en mojibake sur certaines plateformes.
    final texte = utf8.decode(response.bodyBytes);

    if (response.statusCode == 401) throw ApiException.unauthorized();

    if (response.statusCode >= 400) {
      String message = 'Une erreur est survenue.';
      try {
        final data = jsonDecode(texte);
        if (data is Map && data['detail'] != null) {
          final detail = data['detail'];
          // FastAPI renvoie une LISTE d'erreurs pour un 422 de validation,
          // et une simple chaîne pour les erreurs métier (400, 409, 503).
          // Sans ce test, le citoyen verrait « [{loc: [body, cin]...} ».
          if (detail is List && detail.isNotEmpty) {
            final premier = detail.first;
            message = premier is Map
                ? (premier['msg']?.toString() ?? message)
                : premier.toString();
          } else {
            message = detail.toString();
          }
        }
      } catch (_) {}
      throw ApiException(
        message,
        statusCode: response.statusCode,
        kind: response.statusCode >= 500
            ? ApiErrorKind.server
            : ApiErrorKind.unknown,
      );
    }

    final data = jsonDecode(texte);
    return data is Map<String, dynamic> ? data : {'data': data};
  }
}