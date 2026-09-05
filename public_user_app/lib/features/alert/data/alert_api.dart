import 'dart:io';

import '../../../core/api_client.dart';
import '../../../core/api_config.dart';
import '../../../core/fichier_joint.dart';
import 'alert_models.dart';

/// Accès aux routes /api/alerts/ et /api/forests/ via le gateway.
class AlertApi {
  const AlertApi({this.client = const ApiClient()});
  final ApiClient client;

  Future<AlertModel> creer({
    required AlertType type,
    required String forestId,
    String? description,
    double? incidentLat,
    double? incidentLng,
    double? agentLat,
    double? agentLng,
    File? photo,
  }) async {
    final champs = <String, String>{
      'type': type.valeur,
      'forest_id': forestId,
      if (description != null) 'description': description,
      if (incidentLat != null) 'incident_lat': incidentLat.toString(),
      if (incidentLng != null) 'incident_lng': incidentLng.toString(),
      if (agentLat != null) 'agent_lat': agentLat.toString(),
      if (agentLng != null) 'agent_lng': agentLng.toString(),
    };

    final fichiers = <String, FichierJoint>{};
    if (photo != null) {
      final octets = await photo.readAsBytes();
      final ext = photo.path.split('.').last.toLowerCase();
      fichiers['image'] = FichierJoint(
        nom: photo.uri.pathSegments.last,
        octets: octets,
        mimeType: ext == 'png' ? 'image/png' : 'image/jpeg',
      );
    }

    final data = await client.postMultipartAuth(
      ApiConfig.alertes,
      champs: champs,
      fichiers: fichiers,
      timeout: ApiConfig.uploadTimeout,
    );
    return AlertModel.fromJson(data);
  }

  Future<List<AlertModel>> mesAlertes() async {
    final data = await client.get(ApiConfig.mesAlertes);
    final items = (data['data'] as List?) ?? const [];
    return items
        .map((j) => AlertModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<ForestSimple>> forets() async {
    final data = await client.get('${ApiConfig.forets}?page=1&page_size=100');
    final items = (data['items'] as List?) ?? (data['data'] as List?) ?? const [];
    return items
        .map((j) => ForestSimple.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
