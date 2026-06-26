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

  // ── Helper URL image ──────────────────────────────────────────
  String buildImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return '';
    if (imageUrl.startsWith('http')) return imageUrl;
    return '$baseUrl$imageUrl';
  }

  // ── Map points (forêts assignées au superviseur) ──────────────

  Future<List<AlertMapPoint>> getSupervisorMapPoints() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/alerts/supervisor/map'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((j) => AlertMapPoint.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Erreur chargement carte (${res.statusCode})');
  }

  // ── Historique alertes superviseur ────────────────────────────

  Future<List<AlertDetail>> getSupervisorAlerts({String? status}) async {
    final uri = Uri.parse('$baseUrl/api/alerts/supervisor').replace(
      queryParameters: status != null ? {'status': status} : null,
    );

    final res = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((j) => _parseAlertDetail(j as Map<String, dynamic>))
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
      return _parseAlertDetail(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception('Alerte introuvable (${res.statusCode})');
  }

  // ── Mettre à jour le statut ───────────────────────────────────

  Future<AlertDetail> updateStatus({
    required String alertId,
    required String status,
    String?         supervisorComment,
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
      return _parseAlertDetail(jsonDecode(res.body) as Map<String, dynamic>);
    }
    final err = jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception(err['detail'] ?? 'Erreur mise à jour statut');
  }

  // ── Parser AlertDetail ────────────────────────────────────────

  AlertDetail _parseAlertDetail(Map<String, dynamic> j) {
    // Corriger l'URL de l'image avant de parser
    final rawImageUrl = j['image_url'] as String?;
    final fixedJson   = Map<String, dynamic>.from(j);
    fixedJson['image_url'] =
        rawImageUrl != null ? buildImageUrl(rawImageUrl) : null;
    return AlertDetail.fromJson(fixedJson);
  }
}