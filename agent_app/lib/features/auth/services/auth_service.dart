import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:agent_app/core/constants.dart';
import 'package:agent_app/core/token_storage.dart';

class AuthService {
  final _storage = TokenStorage();

  Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse(ApiConstants.loginUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(ApiConstants.requestTimeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final payload = _decodeJwtPayload(data['access_token']);

      await _storage.saveAll(
        accessToken:  data['access_token'],
        refreshToken: data['refresh_token'],
        role:         payload['role'] ?? '',
        userId:       payload['user_id'] ?? '',
      );
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Erreur de connexion');
    }
  }

  Future<void> refreshAccessToken() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) throw Exception('Pas de refresh token');

    final response = await http.post(
      Uri.parse(ApiConstants.refreshUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    ).timeout(ApiConstants.requestTimeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _storage.saveAccessToken(data['access_token']);
    } else {
      throw Exception('Session expirée');
    }
  }

  Future<void> logout() async {
    try {
      final accessToken  = await _storage.getAccessToken();
      final refreshToken = await _storage.getRefreshToken();
      if (accessToken != null && refreshToken != null) {
        await http.post(
          Uri.parse(ApiConstants.logoutUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({'refresh_token': refreshToken}),
        ).timeout(ApiConstants.requestTimeout);
      }
    } catch (_) {
      // Ignore les erreurs réseau au logout
    } finally {
      await _storage.clear();
    }
  }

  Future<String?> getAccessToken()  => _storage.getAccessToken();
  Future<String?> getRefreshToken() => _storage.getRefreshToken();
  Future<String?> getRole()         => _storage.getRole();
  Future<String?> getUserId()       => _storage.getUserId();

  Map<String, dynamic> _decodeJwtPayload(String token) {
    try {
      final parts     = token.split('.');
      if (parts.length != 3) return {};
      final payload   = parts[1];
      final normalized = base64Url.normalize(payload);
      return jsonDecode(utf8.decode(base64Url.decode(normalized)));
    } catch (_) {
      return {};
    }
  }
}