import 'dart:convert';
import 'dart:io';
import 'package:exif/exif.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:agent_app/core/constants.dart';
import 'package:agent_app/features/alert/models/alert_model.dart';

class AlertService {
  static const _storage = FlutterSecureStorage();
  static const _base    = ApiConstants.baseUrl;

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: 'access_token');
    return {'Authorization': 'Bearer ${token ?? ''}'};
  }

  // ── EXIF GPS extraction ────────────────────────────────────

  /// Extrait les coordonnées GPS depuis les métadonnées EXIF d'une image.
  /// Retourne null si pas de GPS dans l'image.
  static Future<({double lat, double lng})?> extractGpsFromImage(
      File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final data  = await readExifFromBytes(bytes);

      if (data.isEmpty) return null;

      final latTag  = data['GPS GPSLatitude'];
      final lngTag  = data['GPS GPSLongitude'];
      final latRef  = data['GPS GPSLatitudeRef'];
      final lngRef  = data['GPS GPSLongitudeRef'];

      if (latTag == null || lngTag == null) return null;

      // Convertir IFDRatio list → degrés décimaux
      double _toDecimal(IfdTag tag) {
        final values = tag.values.toList();
        final deg    = (values[0] as Ratio).toDouble();
        final min    = (values[1] as Ratio).toDouble();
        final sec    = (values[2] as Ratio).toDouble();
        return deg + (min / 60.0) + (sec / 3600.0);
      }

      double lat = _toDecimal(latTag);
      double lng = _toDecimal(lngTag);

      // Appliquer le signe selon N/S et E/W
      if (latRef?.printable == 'S') lat = -lat;
      if (lngRef?.printable == 'W') lng = -lng;

      return (lat: lat, lng: lng);
    } catch (e) {
      print('[EXIF] Erreur extraction GPS : $e');
      return null;
    }
  }

  // ── Créer une alerte ───────────────────────────────────────

  Future<AlertModel> createAlert({
    required AlertType   type,
    required String      forestId,
    String?              description,
    double?              latitude,
    double?              longitude,
    File?                imageFile,
  }) async {
    final headers = await _authHeaders();
    final uri     = Uri.parse('$_base/api/alerts/');

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers)
      ..fields['type']      = type.value
      ..fields['forest_id'] = forestId;

    if (description != null && description.isNotEmpty) {
      request.fields['description'] = description;
    }
    if (latitude != null)  request.fields['latitude']  = latitude.toString();
    if (longitude != null) request.fields['longitude'] = longitude.toString();

    if (imageFile != null) {
      final ext      = imageFile.path.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'png' : 'jpeg';
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        contentType: MediaType('image', mimeType),
      ));
    }

    final streamed = await request.send().timeout(
      const Duration(seconds: 60),
    );
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 201) {
      return AlertModel.fromJson(jsonDecode(response.body));
    }

    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? 'Erreur lors de la création');
  }

  // ── Mes alertes ────────────────────────────────────────────

  Future<List<AlertModel>> getMyAlerts() async {
    final response = await http.get(
      Uri.parse('$_base/api/alerts/mine'),
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((j) => AlertModel.fromJson(j))
          .toList();
    }
    throw Exception('Impossible de charger les alertes');
  }

  // ── Liste des forêts (pour le dropdown) ───────────────────

  Future<List<ForestSimple>> getForests() async {
    final response = await http.get(
      Uri.parse('$_base/api/forests/?page=1&page_size=100'),
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      // Adapter selon le format de réponse de forest_ms
      final List items = body is List ? body : (body['items'] ?? body['forests'] ?? []);
      return items.map((j) => ForestSimple.fromJson(j)).toList();
    }
    throw Exception('Impossible de charger les forêts');
  }
}