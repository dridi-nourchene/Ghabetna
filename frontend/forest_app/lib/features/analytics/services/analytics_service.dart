import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:forest_app/core/token_storage.dart';
import 'package:forest_app/core/constants.dart';
import '../models/analytics_models.dart';

class AnalyticsService {
  final _storage = TokenStorage();
  static const _base = '${ApiConstants.baseUrl}/api/analytics';

  Future<Map<String, String>> _headers() async {
    final token = await _storage.getAccessToken();
    return {
      'Content-Type':  'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  Uri _uri(String path, Map<String, String> query) =>
      Uri.parse('$_base/$path').replace(queryParameters: query.isEmpty ? null : query);

  Future<http.Response> _get(String path, Map<String, String> query) async {
    final res = await http
        .get(_uri(path, query), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Erreur $path (${res.statusCode})');
    }
    return res;
  }

  Future<OverviewData> getOverview(AnalyticsFilters f) async {
    final res = await _get('overview', f.toQuery());
    return OverviewData.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AlertsByForestData> getAlertsByForest(AnalyticsFilters f, {int limit = 10}) async {
    final query = {...f.toQuery(), 'limit': limit.toString()};
    final res = await _get('alerts-by-forest', query);
    return AlertsByForestData.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<StatusTrendPoint>> getStatusTrend(
    AnalyticsFilters f, {
    String granularity = 'week',
  }) async {
    final query = {...f.toQuery(), 'granularity': granularity};
    final res = await _get('status-trend', query);
    return (jsonDecode(res.body) as List)
        .map((j) => StatusTrendPoint.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<ForestTypeMatrixRow>> getForestTypeMatrix(AnalyticsFilters f) async {
    final res = await _get('matrix-forest-type', f.toQuery());
    return (jsonDecode(res.body) as List)
        .map((j) => ForestTypeMatrixRow.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<TopAgentValidation>> getTopAgentsValidation({int limit = 5}) async {
    final res = await _get('top-agents', {'status': 'traiter', 'limit': limit.toString()});
    return (jsonDecode(res.body) as List)
        .map((j) => TopAgentValidation.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<TopAgentRejection>> getTopAgentsRejection({int limit = 5}) async {
    final res = await _get('top-agents', {'status': 'rejeter', 'limit': limit.toString()});
    return (jsonDecode(res.body) as List)
        .map((j) => TopAgentRejection.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<SupervisorWorkloadData> getSupervisorWorkload() async {
    final res = await _get('supervisor-workload', {});
    return SupervisorWorkloadData.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}