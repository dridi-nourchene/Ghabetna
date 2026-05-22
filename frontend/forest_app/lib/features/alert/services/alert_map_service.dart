// features/alert/services/alert_map_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:forest_app/core/constants.dart';
import 'package:forest_app/core/token_storage.dart';
import 'package:forest_app/features/alert/models/alert_map_model.dart';

class AlertMapService {
  final _storage = TokenStorage();
  static const _base = ApiConstants.baseUrl;

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getAccessToken();
    return {
      'Content-Type':  'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  // ── Polling map ───────────────────────────────────────────
  // Retourne les alertes non rejetées
  // incident_lat/lng peuvent être null → sera géré côté Flutter
  // en utilisant le centroïde de la forêt

  Future<List<AlertMapPoint>> getMapPoints() async {
    final res = await http.get(
      Uri.parse('$_base/api/alerts/map'),
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((j) => AlertMapPoint.fromJson(j))
          .toList();
    }
    throw Exception('Erreur chargement alertes map (${res.statusCode})');
  }

  // ── Détail alerte (popup) ─────────────────────────────────

  Future<AlertDetail> getAlertDetail(String alertId) async {
    final res = await http.get(
      Uri.parse('$_base/api/alerts/$alertId'),
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return AlertDetail.fromJson(jsonDecode(res.body));
    }
    throw Exception('Alerte introuvable (${res.statusCode})');
  }

  // ── Changer statut + commentaire ─────────────────────────

  Future<AlertDetail> updateAlertStatus({
    required String alertId,
    required String status,
    String?         adminComment,
  }) async {
    final res = await http.patch(
      Uri.parse('$_base/api/alerts/$alertId/status'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'status':        status,
        if (adminComment != null && adminComment.isNotEmpty)
          'admin_comment': adminComment,
      }),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return AlertDetail.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw Exception(err['detail'] ?? 'Erreur mise à jour statut');
  }
}