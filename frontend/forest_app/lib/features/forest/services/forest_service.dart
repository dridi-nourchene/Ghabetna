// features/forest/services/forest_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:forest_app/core/constants.dart';
import 'package:forest_app/core/token_storage.dart';
import 'package:forest_app/features/forest/models/forest_model.dart';

class ForestService {
  final _storage = TokenStorage();

  static const String _base = '${ApiConstants.baseUrl}/api';

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getAccessToken();
    return {
      'Content-Type':  'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  // ── FORESTS ───────────────────────────────────────────

  /// GET /api/forests/  (paginated)
  Future<PaginatedForests> getForests({
    int page = 1,
    int pageSize = 100,
    String? search,
  }) async {
    final params = {
      'page':      '$page',
      'page_size': '$pageSize',
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final uri = Uri.parse('$_base/forests/').replace(queryParameters: params);
    final response = await http
        .get(uri, headers: await _authHeaders())
        .timeout(ApiConstants.requestTimeout);

    if (response.statusCode == 200) {
      return PaginatedForests.fromJson(jsonDecode(response.body));
    }
    throw Exception('Impossible de charger les forêts');
  }

  /// POST /api/forests/
  Future<Forest> createForest({
    required String name,
    required Map<String, dynamic> geojson,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_base/forests/'),
          headers: await _authHeaders(),
          body: jsonEncode({'name': name, 'geojson': geojson}),
        )
        .timeout(ApiConstants.requestTimeout);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return Forest.fromJson(jsonDecode(response.body));
    }
    final error = jsonDecode(response.body);
    throw Exception(error['detail'] ?? 'Erreur lors de la création');
  }

  /// PUT /api/forests/:id
  Future<Forest> updateForest(
    String forestId, {
    String? name,
    Map<String, dynamic>? geojson,
  }) async {
    final body = <String, dynamic>{};
    if (name != null)    body['name']    = name;
    if (geojson != null) body['geojson'] = geojson;

    final response = await http
        .put(
          Uri.parse('$_base/forests/$forestId'),
          headers: await _authHeaders(),
          body: jsonEncode(body),
        )
        .timeout(ApiConstants.requestTimeout);

    if (response.statusCode == 200) {
      return Forest.fromJson(jsonDecode(response.body));
    }
    final error = jsonDecode(response.body);
    throw Exception(error['detail'] ?? 'Erreur lors de la modification');
  }

  /// DELETE /api/forests/:id
  Future<void> deleteForest(String forestId) async {
    final response = await http
        .delete(
          Uri.parse('$_base/forests/$forestId'),
          headers: await _authHeaders(),
        )
        .timeout(ApiConstants.requestTimeout);

    if (response.statusCode != 200 && response.statusCode != 204) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Erreur lors de la suppression');
    }
  }

  // ── PARCELLES ─────────────────────────────────────────

  /// GET /api/parcelles/?forest_id=...
  Future<PaginatedParcelles> getParcelles({
    required String forestId,
    int page = 1,
    int pageSize = 100,
  }) async {
    final uri = Uri.parse('$_base/parcelles/').replace(queryParameters: {
      'forest_id': forestId,
      'page':      '$page',
      'page_size': '$pageSize',
    });
    final response = await http
        .get(uri, headers: await _authHeaders())
        .timeout(ApiConstants.requestTimeout);

    if (response.statusCode == 200) {
      return PaginatedParcelles.fromJson(jsonDecode(response.body));
    }
    throw Exception('Impossible de charger les parcelles');
  }

  /// POST /api/parcelles/
  Future<Parcelle> createParcelle({
    required String forestId,
    required String name,
    required Map<String, dynamic> geojson,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_base/parcelles/'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'name':      name,
            'forest_id': forestId,
            'geojson':   geojson,
          }),
        )
        .timeout(ApiConstants.requestTimeout);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return Parcelle.fromJson(jsonDecode(response.body));
    }
    final error = jsonDecode(response.body);
    throw Exception(error['detail'] ?? 'Erreur lors de la création');
  }

  /// PUT /api/parcelles/:id
  Future<Parcelle> updateParcelle(
    String parcelleId, {
    String? name,
    Map<String, dynamic>? geojson,
  }) async {
    final body = <String, dynamic>{};
    if (name != null)    body['name']    = name;
    if (geojson != null) body['geojson'] = geojson;

    final response = await http
        .put(
          Uri.parse('$_base/parcelles/$parcelleId'),
          headers: await _authHeaders(),
          body: jsonEncode(body),
        )
        .timeout(ApiConstants.requestTimeout);

    if (response.statusCode == 200) {
      return Parcelle.fromJson(jsonDecode(response.body));
    }
    final error = jsonDecode(response.body);
    throw Exception(error['detail'] ?? 'Erreur lors de la modification');
  }

  /// DELETE /api/parcelles/:id
  Future<void> deleteParcelle(String parcelleId) async {
    final response = await http
        .delete(
          Uri.parse('$_base/parcelles/$parcelleId'),
          headers: await _authHeaders(),
        )
        .timeout(ApiConstants.requestTimeout);

    if (response.statusCode != 200 && response.statusCode != 204) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Erreur lors de la suppression');
    }
  }
}