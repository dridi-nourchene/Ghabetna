// features/profile/services/profile_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:agent_app/core/constants.dart';
import 'package:agent_app/core/token_storage.dart';
import 'package:agent_app/features/profile/models/agent_profile.dart';

class ProfileService {
  final _storage = TokenStorage();

  Future<AgentProfile> getMyProfile() async {
    final token = await _storage.getAccessToken();
    final response = await http.get(
      Uri.parse(ApiConstants.myProfileUrl),
      headers: {'Authorization': 'Bearer ${token ?? ''}'},
    ).timeout(ApiConstants.requestTimeout);

    if (response.statusCode == 200) {
      return AgentProfile.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)));
    }
    throw Exception('profile_load_failed');
  }

  /// Nom et email lus dans le token : affichés tout de suite, avant même
  /// la réponse du serveur, et en secours si forest_ms ne connaît pas
  /// encore l'agent.
  Future<({String? nom, String? email})> identityFromToken() async {
    final token = await _storage.getAccessToken();
    if (token == null) return (nom: null, email: null);
    try {
      final parts = token.split('.');
      if (parts.length != 3) return (nom: null, email: null);
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      return (
        nom:   payload['full_name'] as String?,
        email: payload['email']     as String?,
      );
    } catch (_) {
      return (nom: null, email: null);
    }
  }
}
