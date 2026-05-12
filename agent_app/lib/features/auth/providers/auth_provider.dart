// features/auth/providers/auth_provider.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_app/features/auth/services/auth_service.dart';
import 'package:agent_app/core/token_storage.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? error;
  final String? role;
  final String? email;

  const AuthState({
    this.status = AuthStatus.initial,
    this.error,
    this.role,
    this.email,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? error,
    bool clearError = false,
    String? role,
    bool clearRole = false,
    String? email,
    bool clearEmail = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      error:  clearError ? null : (error ?? this.error),
      role:   clearRole  ? null : (role  ?? this.role),
      email:  clearEmail ? null : (email ?? this.email),
    );
  }

  bool get isLoading       => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  String? get errorMessage => error;
}

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
        state = state.copyWith(
          status: AuthStatus.authenticated,
          role:   role,
        );
      } catch (_) {
        await _authService.logout();
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
      return;
    }

    state = state.copyWith(
      status: AuthStatus.authenticated,
      role:   role,
    );
  }

  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload    = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded    = utf8.decode(base64Url.decode(normalized));
      final data       = jsonDecode(decoded);
      final exp        = data['exp'] as int?;
      if (exp == null) return true;
      return DateTime.now().millisecondsSinceEpoch / 1000 > exp;
    } catch (_) {
      return true;
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(
      status:     AuthStatus.loading,
      clearError: true,
      clearRole:  true,
      clearEmail: true,
    );

    try {
      await _authService.login(email, password);
      final role = await _authService.getRole();

      state = state.copyWith(
        status:     AuthStatus.authenticated,
        role:       role,
        email:      email,
        clearError: true,
      );
      return true;

    } catch (e) {
      String errorMessage = e.toString();

      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11);
      } else if (errorMessage.startsWith('Exception:')) {
        errorMessage = errorMessage.substring(10);
      }

      errorMessage = errorMessage.trim();

      if (errorMessage.isEmpty) {
        errorMessage = 'Erreur de connexion';
      }

      state = state.copyWith(
        status: AuthStatus.error,
        error:  errorMessage,
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = state.copyWith(
      status:      AuthStatus.unauthenticated,
      clearRole:   true,
      clearError:  true,
      clearEmail:  true,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);