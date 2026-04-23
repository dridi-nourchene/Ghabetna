import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:forest_app/core/constants.dart';
import 'package:forest_app/core/token_storage.dart';
import 'package:forest_app/features/auth/models/auth_model.dart';

class AuthService {
  final _storage = TokenStorage();

  // ── Login ────────────────────────────────────────────
  Future<TokenResponse> login(String email, String password) async {
    if (!email.contains('@') || !email.contains('.')) {
    throw Exception('Adresse email invalide');
  }
    final response = await http.post(
      Uri.parse(ApiConstants.loginUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(LoginRequest(email: email, password: password).toJson()),
    ).timeout(ApiConstants.requestTimeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final tokens = TokenResponse.fromJson(data);

      // Decode JWT pour extraire role et userId
      final payload = _decodeJwt(tokens.accessToken);

      await _storage.saveAll(
        accessToken:  tokens.accessToken,
        refreshToken: tokens.refreshToken,
        role:         payload['role'] ?? '',
        userId:       payload['user_id'] ?? '',
      );

      return tokens;
    }

    final error = jsonDecode(response.body);
    throw Exception(error['detail'] ?? 'Erreur de connexion');
  }

  // ── Refresh ──────────────────────────────────────────
  Future<String> refreshAccessToken() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) throw Exception('Pas de refresh token');

    final response = await http.post(
      Uri.parse(ApiConstants.refreshUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    ).timeout(ApiConstants.requestTimeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final newAccessToken = data['access_token'];
      await _storage.saveAccessToken(newAccessToken);
      return newAccessToken;
    }

    throw Exception('Session expirée — reconnectez-vous');
  }

  // ── Logout ───────────────────────────────────────────
  Future<void> logout() async {
    final refreshToken = await _storage.getRefreshToken();
    final accessToken  = await _storage.getAccessToken();

    if (refreshToken != null && accessToken != null) {
      await http.post(
        Uri.parse(ApiConstants.logoutUrl),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(ApiConstants.requestTimeout);
    }

    await _storage.clear();
  }

  // ── Decode JWT (sans librairie) ───────────────────────
  Map<String, dynamic> _decodeJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return {};
    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(decoded);
  }
  Future<String?> getRole() async => await _storage.getRole();
}