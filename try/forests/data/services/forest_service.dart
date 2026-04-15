import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/forest_model.dart';
import '../../../../frontend/forest_app/lib/core/constants.dart';
import '../../../../frontend/forest_app/lib/core/token_storage.dart';


class ForestService {

  // ── Headers avec JWT ──────────────────────────────────
  Future<Map<String, String>> _headers() async {
    final token = await TokenStorage().getToken();
    return {
      'Content-Type':  'application/json',
      'Authorization': 'Bearer $token',
    };
  }


  // ── GET /forests/geojson ──────────────────────────────
  // Récupère toutes les forêts actives en GeoJSON
  // flutter_map consomme ce résultat directement
  Future<ForestsGeoJSONCollection> getForestsGeoJson() async {
    final response = await http
        .get(
          Uri.parse(ApiConstants.forestsGeoJsonUrl),
          headers: await _headers(),
        )
        .timeout(ApiConstants.requestTimeout);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return ForestsGeoJSONCollection.fromJson(json);
    }

    throw Exception(
      'Erreur chargement forêts: ${response.statusCode}',
    );
  }


  // ── GET /forests/ ─────────────────────────────────────
  // Liste paginée des forêts
  Future<List<ForestModel>> listForests({
    int page     = 1,
    int pageSize = 20,
    String? search,
  }) async {
    // Construction de l'URL avec paramètres
    final uri = Uri.parse(ApiConstants.forestsUrl).replace(
      queryParameters: {
        'page':      page.toString(),
        'page_size': pageSize.toString(),
        if (search != null) 'search': search,
      },
    );

    final response = await http
        .get(uri, headers: await _headers())
        .timeout(ApiConstants.requestTimeout);

    if (response.statusCode == 200) {
      final json    = jsonDecode(response.body);
      final items   = json['items'] as List;
      return items.map((f) => ForestModel.fromJson(f)).toList();
    }

    throw Exception(
      'Erreur liste forêts: ${response.statusCode}',
    );
  }


  // ── GET /forests/{id} ─────────────────────────────────
  Future<ForestModel> getForest(String id) async {
    final response = await http
        .get(
          Uri.parse('${ApiConstants.forestsUrl}/$id'),
          headers: await _headers(),
        )
        .timeout(ApiConstants.requestTimeout);

    if (response.statusCode == 200) {
      return ForestModel.fromJson(jsonDecode(response.body));
    }

    throw Exception(
      'Forêt introuvable: ${response.statusCode}',
    );
  }


  // ── POST /forests/ ────────────────────────────────────
  // Crée une nouvelle forêt
  // points → liste de [lng, lat] dessinés par l'admin
  Future<ForestModel> createForest({
    required String name,
    required List<List<double>> points,  // [[lng, lat], ...]
    String? supervisorcin,
    String? supervisorName,
  }) async {

    // Ferme le polygone si pas déjà fermé
    // premier point doit == dernier point
    final closedPoints = List<List<double>>.from(points);
    if (closedPoints.first[0] != closedPoints.last[0] ||
        closedPoints.first[1] != closedPoints.last[1]) {
      closedPoints.add(closedPoints.first);
    }

    final body = {
      'name':        name,
      'geojson': {
        'type':        'Polygon',
        'coordinates': [closedPoints],  // ← format GeoJSON
      },
      if (supervisorcin   != null) 'supervisor_cin':   supervisorcin,
      if (supervisorName != null) 'supervisor_name': supervisorName,
      'status': 'active',
    };

    final response = await http
        .post(
          Uri.parse(ApiConstants.forestsUrl),
          headers: await _headers(),
          body:    jsonEncode(body),
        )
        .timeout(ApiConstants.requestTimeout);

    if (response.statusCode == 201) {
      return ForestModel.fromJson(jsonDecode(response.body));
    }

    throw Exception(
      'Erreur création forêt: ${response.statusCode} ${response.body}',
    );
  }


  // ── DELETE /forests/{id} ──────────────────────────────
  Future<void> deleteForest(String id) async {
    final response = await http
        .delete(
          Uri.parse('${ApiConstants.forestsUrl}/$id'),
          headers: await _headers(),
        )
        .timeout(ApiConstants.requestTimeout);

    if (response.statusCode != 204) {
      throw Exception(
        'Erreur suppression: ${response.statusCode}',
      );
    }
  }

    Future<ForestModel> updateForest({
    required String        id,
    String?                name,
    List<List<double>>?    points,
  }) async {
    final body = <String, dynamic>{};

    if (name        != null) body['name']        = name;

    // ken nouveau polygone dessiné
    if (points != null) {
      final closed = List<List<double>>.from(points);
      if (closed.first[0] != closed.last[0] ||
          closed.first[1] != closed.last[1]) {
        closed.add(closed.first);
      }
      body['geojson'] = {
        'type':        'Polygon',
        'coordinates': [closed],
      };
    }

    final response = await http.put(
      Uri.parse('${ApiConstants.forestsUrl}/$id'),
      headers: await _headers(),
      body:    jsonEncode(body),
    ).timeout(ApiConstants.requestTimeout);

    if (response.statusCode == 200) {
      return ForestModel.fromJson(jsonDecode(response.body));
    }

    throw Exception('Erreur modification: ${response.statusCode}');
  }
}