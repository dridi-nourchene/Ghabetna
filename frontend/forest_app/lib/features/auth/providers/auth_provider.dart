// features/auth/providers/auth_provider.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forest_app/features/auth/services/auth_service.dart';
import 'package:forest_app/core/token_storage.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String?    error;
  final String?    role;
  final String?    accessToken;
  final String?    userId;

  const AuthState({
    this.status      = AuthStatus.initial,
    this.error,
    this.role,
    this.accessToken,
    this.userId,
  });

  AuthState copyWith({
    AuthStatus? status,
    String?     error,
    bool        clearError  = false,
    String?     role,
    bool        clearRole   = false,
    String?     accessToken,
    bool        clearToken  = false,
    String?     userId,
    bool        clearUserId = false,
  }) {
    return AuthState(
      status:      status      ?? this.status,
      error:       clearError  ? null : (error       ?? this.error),
      role:        clearRole   ? null : (role        ?? this.role),
      accessToken: clearToken  ? null : (accessToken ?? this.accessToken),
      userId:      clearUserId ? null : (userId      ?? this.userId),
    );
  }

  bool get isLoading       => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
}

// ─────────────────────────────────────────────────────────────
//  Helper — décoder le JWT et extraire un champ
// ─────────────────────────────────────────────────────────────

Map<String, dynamic> _decodeJwtPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return {};
    final normalized = base64Url.normalize(parts[1]);
    final decoded    = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(decoded) as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
}

bool _isTokenExpired(String token) {
  try {
    final payload = _decodeJwtPayload(token);
    final exp = payload['exp'] as int?;
    if (exp == null) return true;
    return DateTime.now().millisecondsSinceEpoch / 1000 > exp;
  } catch (_) {
    return true;
  }
}

// ─────────────────────────────────────────────────────────────
//  Notifier
// ─────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier({AuthService? authService})
      : _authService = authService ?? AuthService(),
        super(const AuthState()) {
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    final accessToken = await _authService.getAccessToken();
    final role        = await _authService.getRole();

    if (accessToken == null || role == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    if (_isTokenExpired(accessToken)) {
      try {
        await _authService.refreshAccessToken();
        final newToken = await _authService.getAccessToken();
        if (newToken == null) throw Exception('Token introuvable après refresh');

        final payload = _decodeJwtPayload(newToken);
        state = state.copyWith(
          status:      AuthStatus.authenticated,
          role:        role,
          accessToken: newToken,
          userId:      payload['user_id'] as String?,
        );
      } catch (_) {
        await _authService.logout();
        state = state.copyWith(
          status:      AuthStatus.unauthenticated,
          clearRole:   true,
          clearToken:  true,
          clearUserId: true,
        );
      }
      return;
    }

    // Token valide — extraire user_id directement depuis le token
    final payload = _decodeJwtPayload(accessToken);
    state = state.copyWith(
      status:      AuthStatus.authenticated,
      role:        role,
      accessToken: accessToken,
      userId:      payload['user_id'] as String?,
    );
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(
      status:      AuthStatus.loading,
      clearError:  true,
      clearRole:   true,
      clearToken:  true,
      clearUserId: true,
    );

    try {
      await _authService.login(email, password);
      final role  = await _authService.getRole();
      final token = await _authService.getAccessToken();

      // Extraire user_id depuis le JWT
      final payload = token != null ? _decodeJwtPayload(token) : <String, dynamic>{};

      state = state.copyWith(
        status:      AuthStatus.authenticated,
        role:        role,
        accessToken: token,
        userId:      payload['user_id'] as String?,
        clearError:  true,
      );
    } catch (e) {
      String msg = e.toString();
      if (msg.startsWith('Exception: '))  msg = msg.substring(11);
      else if (msg.startsWith('Exception:')) msg = msg.substring(10);
      msg = msg.trim();
      if (msg.isEmpty) msg = 'Erreur de connexion';

      state = state.copyWith(
        status: AuthStatus.error,
        error:  msg,
      );
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = state.copyWith(
      status:      AuthStatus.unauthenticated,
      clearRole:   true,
      clearError:  true,
      clearToken:  true,
      clearUserId: true,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);