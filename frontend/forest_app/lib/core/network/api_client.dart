import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:forest_app/core/constants.dart';
import 'package:forest_app/core/token_storage.dart';

class ApiClient {
  final _storage = TokenStorage();

  // ── Headers avec token ────────────────────────────────
  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getAccessToken();
    return {
      'Content-Type':  'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Refresh token ─────────────────────────────────────
  Future<String?> _tryRefresh() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) return null;

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.refreshUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(ApiConstants.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newToken = data['access_token'];
        await _storage.saveAccessToken(newToken);
        return newToken;
      }
    } catch (_) {}

    return null;
  }

  // ── Gérer 401 → refresh → retry ──────────────────────
  Future<http.Response> _handleResponse(
    Future<http.Response> Function(Map<String, String> headers) request,
    BuildContext? context,
  ) async {
    var headers  = await _authHeaders();
    var response = await request(headers);

    if (response.statusCode == 401) {
      final newToken = await _tryRefresh();

      if (newToken == null) {
        // refresh expiré → logout forcé
        await _storage.clear();
        if (context != null && context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login', (_) => false,
          );
        }
        return response;
      }

      // Rejoue avec nouveau token
      headers  = await _authHeaders();
      response = await request(headers);
    }

    return response;
  }

  // ── GET ───────────────────────────────────────────────
  Future<http.Response> get(
    String url, {
    BuildContext? context,
  }) async {
    return _handleResponse(
      (headers) => http
          .get(Uri.parse(url), headers: headers)
          .timeout(ApiConstants.requestTimeout),
      context,
    );
  }

  // ── POST ──────────────────────────────────────────────
  Future<http.Response> post(
    String url,
    Map<String, dynamic> body, {
    BuildContext? context,
  }) async {
    return _handleResponse(
      (headers) => http
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(ApiConstants.requestTimeout),
      context,
    );
  }

  // ── PUT ───────────────────────────────────────────────
  Future<http.Response> put(
    String url,
    Map<String, dynamic> body, {
    BuildContext? context,
  }) async {
    return _handleResponse(
      (headers) => http
          .put(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(ApiConstants.requestTimeout),
      context,
    );
  }

  // ── DELETE ────────────────────────────────────────────
  Future<http.Response> delete(
    String url, {
    BuildContext? context,
  }) async {
    return _handleResponse(
      (headers) => http
          .delete(Uri.parse(url), headers: headers)
          .timeout(ApiConstants.requestTimeout),
      context,
    );
  }
}