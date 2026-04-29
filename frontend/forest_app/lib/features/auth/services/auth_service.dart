// features/auth/services/auth_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:forest_app/core/constants.dart';
import 'package:forest_app/core/token_storage.dart';
import 'package:forest_app/features/auth/models/auth_model.dart';

class AuthService {
  final _storage = TokenStorage();

  // ── Helper pour extraire le message d'erreur ──────────────
  String _extractErrorMessage(Map<String, dynamic> errorBody) {
    // Cas 1: detail est une liste d'erreurs (FastAPI validation)
    if (errorBody['detail'] is List) {
      final errors = errorBody['detail'] as List;
      if (errors.isNotEmpty) {
        final firstError = errors[0];
        // Récupérer le message d'erreur
        if (firstError['msg'] != null) {
          String msg = firstError['msg'];
          // Ajouter le champ concerné si disponible
          if (firstError['loc'] != null && (firstError['loc'] as List).isNotEmpty) {
            final field = (firstError['loc'] as List).last;
            if (field == 'email') {
              return 'Email invalide: $msg';
            } else if (field == 'password') {
              return 'Mot de passe invalide: $msg';
            }
          }
          return msg;
        }
        return 'Erreur de validation: ${errors[0]['type']}';
      }
      return 'Erreur de validation des données';
    }
    
    // Cas 2: detail est un string (message simple)
    if (errorBody['detail'] is String) {
      return errorBody['detail'];
    }
    
    // Cas 3: message directement dans 'message'
    if (errorBody['message'] is String) {
      return errorBody['message'];
    }
    
    // Cas 4: erreur dans 'error'
    if (errorBody['error'] is String) {
      return errorBody['error'];
    }
    
    // Cas 5: non_authorized ou autre champ
    if (errorBody['non_authorized'] is String) {
      return errorBody['non_authorized'];
    }
    
    // Fallback
    return 'Email ou mot de passe incorrect';
  }

  // ── Login ────────────────────────────────────────────
  Future<TokenResponse> login(String email, String password) async {
    // Validation email
    if (!email.contains('@') || !email.contains('.')) {
      throw Exception('Adresse email invalide');
    }

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(LoginRequest(email: email, password: password).toJson()),
      ).timeout(ApiConstants.requestTimeout);

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Decoded data: $data');
        
        final tokens = TokenResponse.fromJson(data);
        
        final payload = _decodeJwt(tokens.accessToken);
        print('JWT payload: $payload');
        
        await _storage.saveAll(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
          role: payload['role']?.toString() ?? '',
          userId: payload['user_id']?.toString() ?? '',
        );

        return tokens;
      }

      // Gestion des erreurs HTTP (non-200)
      String errorMessage = 'Email ou mot de passe incorrect';
      
      try {
        final errorBody = jsonDecode(response.body);
        print('Error body: $errorBody');
        errorMessage = _extractErrorMessage(errorBody);
      } catch (e) {
        print('Error parsing error response: $e');
        errorMessage = 'Email ou mot de passe incorrect';
      }
      
      throw Exception(errorMessage);
      
    } on http.ClientException catch (e) {
      print('ClientException: $e');
      throw Exception('Vérifiez votre connexion internet');
    } on TimeoutException catch (e) {
      print('TimeoutException: $e');
      throw Exception('Le serveur ne répond pas. Réessayez plus tard.');
  } catch (e) {
      if (e is Exception) rethrow; // ← relance le vrai message
      throw Exception('Une erreur est survenue. Veuillez réessayer.');
    }
  }

  // ── Refresh ──────────────────────────────────────────
  Future<String> refreshAccessToken() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) throw Exception('Pas de refresh token');

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.refreshUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(ApiConstants.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccessToken = data['access_token'] ?? data['accessToken'];
        
        if (newAccessToken == null) {
          throw Exception('Format de réponse invalide');
        }
        
        await _storage.saveAccessToken(newAccessToken);
        return newAccessToken;
      }

      // Gestion des erreurs refresh
      String errorMessage = 'Session expirée — reconnectez-vous';
      try {
        final errorBody = jsonDecode(response.body);
        errorMessage = _extractErrorMessage(errorBody);
      } catch (e) {
        // Ignorer, garder message par défaut
      }
      throw Exception(errorMessage);
      
    } on TimeoutException catch (e) {
      throw Exception('Délai de connexion dépassé');
    } catch (e) {
      throw Exception('Impossible de rafraîchir la session');
    }
  }

  // ── Logout ───────────────────────────────────────────
  Future<void> logout() async {
    final refreshToken = await _storage.getRefreshToken();
    final accessToken = await _storage.getAccessToken();

    if (refreshToken != null && accessToken != null) {
      try {
        await http.post(
          Uri.parse(ApiConstants.logoutUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({'refresh_token': refreshToken}),
        ).timeout(ApiConstants.requestTimeout);
      } catch (e) {
        print('Logout API error: $e');
      }
    }

    await _storage.clear();
  }

  // ── Decode JWT (sans librairie) ───────────────────────
  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(decoded);
    } catch (e) {
      print('JWT decode error: $e');
      return {};
    }
  }
  
  Future<String?> getRole() async => await _storage.getRole();
}