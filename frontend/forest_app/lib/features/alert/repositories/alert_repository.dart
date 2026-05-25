// frontend/forest_app/lib/features/alert/repositories/alert_repository.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/alert_map_model.dart';

class AlertRepository {
  final String baseUrl;
  final String Function() getToken;

  AlertRepository({required this.baseUrl, required this.getToken});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${getToken()}',
      };

  // ── Map points (forêts assignées au superviseur) ──────────────

  Future<List<AlertMapPoint>> getSupervisorMapPoints() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/alerts/supervisor/map'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((j) => AlertMapPoint.fromJson(j))
          .toList();
    }
    throw Exception('Erreur chargement carte (${res.statusCode})');
  }

  // ── Historique alertes superviseur ────────────────────────────

  Future<List<AlertDetail>> getSupervisorAlerts({String? status}) async {
    final uri = Uri.parse('$baseUrl/api/alerts/supervisor').replace(
      queryParameters: status != null ? {'status': status} : null,
    );

    final res = await http.get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((j) => AlertDetail.fromJson(j))
          .toList();
    }
    throw Exception('Erreur chargement alertes (${res.statusCode})');
  }

  // ── Détail alerte ─────────────────────────────────────────────

  Future<AlertDetail> getAlertById(String alertId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/alerts/$alertId'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return AlertDetail.fromJson(jsonDecode(res.body));
    }
    throw Exception('Alerte introuvable (${res.statusCode})');
  }

  // ── Mettre à jour le statut ───────────────────────────────────

  Future<AlertDetail> updateStatus({
    required String alertId,
    required String status,
    String? supervisorComment,
  }) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/api/alerts/$alertId/status'),
      headers: _headers,
      body: jsonEncode({
        'status': status,
        if (supervisorComment != null && supervisorComment.isNotEmpty)
          'supervisor_comment': supervisorComment,
      }),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return AlertDetail.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw Exception(err['detail'] ?? 'Erreur mise à jour statut');
  }
}