import 'dart:convert';
import 'dart:io';
import 'package:exif/exif.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:agent_app/core/constants.dart';
import 'package:agent_app/core/token_storage.dart';
import 'package:agent_app/features/alert/models/alert_model.dart';

class AlertService {
  final _storage = TokenStorage();
  static const _base = ApiConstants.baseUrl;

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getAccessToken();
    return {'Authorization': 'Bearer ${token ?? ''}'};
  }

  // ── GPS téléphone (position agent) ────────────────────────

  static Future<({double lat, double lng})?> getAgentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      return (lat: position.latitude, lng: position.longitude);
    } catch (e) {
      return null;
    }
  }

  // ── GPS EXIF depuis la photo ───────────────────────────────

  static Future<({double lat, double lng})?> extractGpsFromImage(
      File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final data  = await readExifFromBytes(bytes);
      if (data.isEmpty) return null;

      final latTag = data['GPS GPSLatitude'];
      final lngTag = data['GPS GPSLongitude'];
      final latRef = data['GPS GPSLatitudeRef'];
      final lngRef = data['GPS GPSLongitudeRef'];
      // Date EXIF — vérifier que la photo est récente (moins d'1h)
      final dateTag = data['EXIF DateTimeOriginal'] ??
                      data['Image DateTime'];

      if (latTag == null || lngTag == null) return null;

      // Vérification date EXIF
      if (dateTag != null) {
        try {
          final exifDateStr = dateTag.printable
              .replaceFirst(':', '-')
              .replaceFirst(':', '-');
          final exifDate = DateTime.parse(exifDateStr);
          final diff = DateTime.now().difference(exifDate).abs();
          if (diff.inHours > 1) {
            print('[EXIF] Photo trop ancienne (${diff.inHours}h) — GPS ignoré');
            return null;
          }
        } catch (_) {
          // Si on ne peut pas parser la date → on garde le GPS quand même
        }
      }

      double toDecimal(IfdTag tag) {
        final values = tag.values.toList();
        final deg = (values[0] as Ratio).toDouble();
        final min = (values[1] as Ratio).toDouble();
        final sec = (values[2] as Ratio).toDouble();
        return deg + (min / 60.0) + (sec / 3600.0);
      }

      double lat = toDecimal(latTag);
      double lng = toDecimal(lngTag);
      if (latRef?.printable == 'S') lat = -lat;
      if (lngRef?.printable == 'W') lng = -lng;

      return (lat: lat, lng: lng);
    } catch (e) {
      print('[EXIF] Erreur : $e');
      return null;
    }
  }

  // ── Créer une alerte ───────────────────────────────────────

  Future<AlertModel> createAlert({
    required AlertType type,
    required String    forestId,
    String?            description,
    double?            incidentLat,
    double?            incidentLng,
    double?            agentLat,
    double?            agentLng,
    File?              imageFile,
  }) async {
    final headers = await _authHeaders();
    final uri     = Uri.parse('$_base/api/alerts/');

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers)
      ..fields['type']      = type.value
      ..fields['forest_id'] = forestId;

    if (description  != null) request.fields['description']  = description;
    if (incidentLat  != null) request.fields['incident_lat'] = incidentLat.toString();
    if (incidentLng  != null) request.fields['incident_lng'] = incidentLng.toString();
    if (agentLat     != null) request.fields['agent_lat']    = agentLat.toString();
    if (agentLng     != null) request.fields['agent_lng']    = agentLng.toString();

    if (imageFile != null) {
      final ext      = imageFile.path.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'png' : 'jpeg';
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        contentType: MediaType('image', mimeType),
      ));
    }

    final streamed = await request.send().timeout(const Duration(seconds: 60));
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

  // ── Liste des forêts ───────────────────────────────────────

  Future<List<ForestSimple>> getForests() async {
    final response = await http.get(
      Uri.parse('$_base/api/forests/?page=1&page_size=100'),
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final body  = jsonDecode(response.body);
      final List items = body is List
          ? body
          : (body['items'] ?? body['forests'] ?? []);
      return items.map((j) => ForestSimple.fromJson(j)).toList();
    }
    throw Exception('Impossible de charger les forêts');
  }
}