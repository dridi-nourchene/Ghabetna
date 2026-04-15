// features/user/services/user_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:forest_app/core/constants.dart';
import 'package:forest_app/core/token_storage.dart';
import 'package:forest_app/features/user/models/user_model.dart';

class UserService {
  final _storage = TokenStorage();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getAccessToken();
    return {
      'Content-Type':  'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  // ── GET /api/users/active ─────────────────────────────
  // Returns all non-admin users with status active
  Future<List<AppUser>> getActiveUsers() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/users/active'),
      headers: await _authHeaders(),
    ).timeout(ApiConstants.requestTimeout);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((u) => AppUser.fromJson(u)).toList();
    }
    throw Exception('Impossible de charger les utilisateurs');
  }

  // ── GET /api/users/inactive ───────────────────────────
  // Returns inactive/pending users
  Future<List<AppUser>> getInactiveUsers() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/users/inactive'),
      headers: await _authHeaders(),
    ).timeout(ApiConstants.requestTimeout);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((u) => AppUser.fromJson(u)).toList();
    }
    throw Exception('Impossible de charger les utilisateurs inactifs');
  }

  // ── DELETE /api/users/:id ─────────────────────────────
  Future<void> deleteUser(String userId) async {
    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/api/users/$userId'),
      headers: await _authHeaders(),
    ).timeout(ApiConstants.requestTimeout);

    if (response.statusCode != 200 && response.statusCode != 204) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Erreur lors de la suppression');
    }
  }

  // ── PUT /api/users/:id ────────────────────────────────
  Future<AppUser> updateUser(String userId, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/api/users/$userId'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    ).timeout(ApiConstants.requestTimeout);

    if (response.statusCode == 200) {
      return AppUser.fromJson(jsonDecode(response.body));
    }
    final error = jsonDecode(response.body);
    throw Exception(error['detail'] ?? 'Erreur lors de la mise à jour');
  }

  // ── POST /api/users/ ──────────────────────────────────
  Future<AppUser> createUser(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/api/users/'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    ).timeout(ApiConstants.requestTimeout);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return AppUser.fromJson(jsonDecode(response.body));
    }
    final error = jsonDecode(response.body);
    throw Exception(error['detail'] ?? 'Erreur lors de la création');
  }
}