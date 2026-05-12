// features/assignment/services/assignment_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:forest_app/core/constants.dart';
import 'package:forest_app/core/token_storage.dart';
import 'package:forest_app/features/assignment/models/assignment_model.dart';

class AssignmentService {
  final _storage = TokenStorage();
  static const _base = ApiConstants.baseUrl;

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getAccessToken();
    return {
      'Content-Type':  'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  // ── Listes ──────────────────────────────────────────────

  Future<List<AgentStatus>> getAgents() async {
    final res = await http.get(
      Uri.parse('$_base/api/assignments/agents'),
      headers: await _authHeaders(),
    ).timeout(ApiConstants.requestTimeout);

    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((j) => AgentStatus.fromJson(j))
          .toList();
    }
    throw Exception('Impossible de charger les agents');
  }

  Future<List<SuperviseurStatus>> getSuperviseurs() async {
    final res = await http.get(
      Uri.parse('$_base/api/assignments/superviseurs'),
      headers: await _authHeaders(),
    ).timeout(ApiConstants.requestTimeout);

    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((j) => SuperviseurStatus.fromJson(j))
          .toList();
    }
    throw Exception('Impossible de charger les superviseurs');
  }

  // ── Affectation agent ────────────────────────────────────

  /// Retourne AssignmentResult — peut avoir conflict=true
  Future<AssignmentResult> assignAgent({
    required String parcelleId,
    required String agentId,
  }) async {
    final res = await http.put(
      Uri.parse('$_base/api/parcelles/$parcelleId/agents'),
      headers: await _authHeaders(),
      body: jsonEncode({'agent_id': agentId}),
    ).timeout(ApiConstants.requestTimeout);

    if (res.statusCode == 200) {
      return AssignmentResult.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw Exception(err['detail'] ?? "Erreur lors de l'affectation");
  }

  /// Confirmer déplacement après conflict
  Future<AssignmentResult> reassignAgent({
    required String parcelleId,
    required String agentId,
  }) async {
    final res = await http.put(
      Uri.parse('$_base/api/parcelles/$parcelleId/agents/reassign'),
      headers: await _authHeaders(),
      body: jsonEncode({'agent_id': agentId}),
    ).timeout(ApiConstants.requestTimeout);

    if (res.statusCode == 200) {
      return AssignmentResult.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw Exception(err['detail'] ?? "Erreur lors du déplacement");
  }

  Future<void> removeAgent({
    required String parcelleId,
    required String agentId,
  }) async {
    final res = await http.delete(
      Uri.parse('$_base/api/parcelles/$parcelleId/agents/$agentId'),
      headers: await _authHeaders(),
    ).timeout(ApiConstants.requestTimeout);

    if (res.statusCode != 200 && res.statusCode != 204) {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Erreur lors de la suppression');
    }
  }

  // ── Affectation superviseur ──────────────────────────────

  Future<Map<String, dynamic>> assignSuperviseur({
    required String forestId,
    required String superviseurId,
  }) async {
    final res = await http.put(
      Uri.parse('$_base/api/forests/$forestId/superviseur'),
      headers: await _authHeaders(),
      body: jsonEncode({'superviseur_id': superviseurId}),
    ).timeout(ApiConstants.requestTimeout);

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    final err = jsonDecode(res.body);
    throw Exception(err['detail'] ?? "Erreur lors de l'affectation");
  }

  Future<void> removeSuperviseur({required String forestId}) async {
    final res = await http.delete(
      Uri.parse('$_base/api/forests/$forestId/superviseur'),
      headers: await _authHeaders(),
    ).timeout(ApiConstants.requestTimeout);

    if (res.statusCode != 200 && res.statusCode != 204) {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Erreur lors de la suppression');
    }
  }
}