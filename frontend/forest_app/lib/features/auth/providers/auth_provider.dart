// frontend/forest_app/lib/features/auth/providers/auth_provider.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forest_app/features/auth/services/auth_service.dart';
import 'package:forest_app/core/token_storage.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String?    error;
  final String?    role;
  final String?    email;
  final String?    userId;       // ← AJOUTÉ
  final String?    accessToken;  // ← AJOUTÉ

  const AuthState({
    this.status      = AuthStatus.initial,
    this.error,
    this.role,
    this.email,
    this.userId,
    this.accessToken,
  });

  AuthState copyWith({
    AuthStatus? status,
    String?     error,
    bool        clearError   = false,
    String?     role,
    bool        clearRole    = false,
    String?     email,
    bool        clearEmail   = false,
    String?     userId,
    bool        clearUserId  = false,
    String?     accessToken,
    bool        clearToken   = false,
  }) {
    return AuthState(
      status:      status      ?? this.status,
      error:       clearError  ? null : (error       ?? this.error),
      role:        clearRole   ? null : (role        ?? this.role),
      email:       clearEmail  ? null : (email       ?? this.email),
      userId:      clearUserId ? null : (userId      ?? this.userId),
      accessToken: clearToken  ? null : (accessToken ?? this.accessToken),
    );
  }

  bool    get isLoading       => status == AuthStatus.loading;
  bool    get isAuthenticated => status == AuthStatus.authenticated;
  String? get errorMessage    => error;
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
    final userId      = await _authService.getUserId();   // ← AJOUTÉ

    if (accessToken == null || role == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    if (_isTokenExpired(accessToken)) {
      try {
        await _authService.refreshAccessToken();
        final newToken = await _authService.getAccessToken();
        state = state.copyWith(
          status:      AuthStatus.authenticated,
          role:        role,
          userId:      userId,         // ← AJOUTÉ
          accessToken: newToken,       // ← AJOUTÉ
        );
      } catch (_) {
        await _authService.logout();
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
      return;
    }

    state = state.copyWith(
      status:      AuthStatus.authenticated,
      role:        role,
      userId:      userId,             // ← AJOUTÉ
      accessToken: accessToken,        // ← AJOUTÉ
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
      status:      AuthStatus.loading,
      clearError:  true,
      clearRole:   true,
      clearEmail:  true,
      clearUserId: true,
      clearToken:  true,
    );

    try {
      await _authService.login(email, password);
      final role        = await _authService.getRole();
      final userId      = await _authService.getUserId();   // ← AJOUTÉ
      final accessToken = await _authService.getAccessToken(); // ← AJOUTÉ

      state = state.copyWith(
        status:      AuthStatus.authenticated,
        role:        role,
        email:       email,
        userId:      userId,           // ← AJOUTÉ
        accessToken: accessToken,      // ← AJOUTÉ
        clearError:  true,
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
      if (errorMessage.isEmpty) errorMessage = 'Erreur de connexion';

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
      clearUserId: true,
      clearToken:  true,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);