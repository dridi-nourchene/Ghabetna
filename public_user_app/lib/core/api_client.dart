import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';
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

  Map<String, dynamic> _decode(http.Response response) {
    // utf8.decode explicite : sans lui, les accents des textes juridiques
    // reviennent en mojibake sur certaines plateformes.
    final texte = utf8.decode(response.bodyBytes);

    // Trace de diagnostic : montre ce que le serveur renvoie REELLEMENT.
    // A retirer une fois l'integration stabilisee.
    // ignore: avoid_print
    print('[API] ${response.statusCode} — ${texte.length} octets');
    if (texte.length < 600) {
      // ignore: avoid_print
      print('[API] corps: $texte');
    }

    if (response.statusCode == 401) throw ApiException.unauthorized();

    if (response.statusCode >= 400) {
      String message = 'Une erreur est survenue.';
      try {
        final data = jsonDecode(texte);
        if (data is Map && data['detail'] != null) {
          message = data['detail'].toString();
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