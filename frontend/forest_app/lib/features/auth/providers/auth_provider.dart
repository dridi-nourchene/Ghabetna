// features/auth/providers/auth_provider.dart
// FIX : sentinel _keep pour ne pas écraser error par accident

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forest_app/features/auth/services/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

// Sentinel — objet unique pour signifier "ne pas toucher à cette valeur"
const _keep = Object();

class AuthState {
  final AuthStatus status;
  final String?    error;
  final String?    role;

  const AuthState({
    this.status = AuthStatus.initial,
    this.error,
    this.role,
  });

  // FIX : on utilise Object? comme type pour error et role
  // Si on passe _keep → on garde l'ancienne valeur
  // Si on passe null  → on efface explicitement
  // Si on passe une String → on set la nouvelle valeur
  AuthState copyWith({
    AuthStatus? status,
    Object?     error = _keep,   // ← sentinel
    Object?     role  = _keep,   // ← sentinel
  }) {
    return AuthState(
      status: status ?? this.status,
      error:  error == _keep ? this.error : error as String?,
      role:   role  == _keep ? this.role  : role  as String?,
    );
  }

  bool get isLoading       => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final _authService = AuthService();

  AuthNotifier() : super(const AuthState()) {
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    final role = await _authService.getRole();
    if (role != null) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        role:   role,
      );
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String email, String password) async {
    // On passe error: null EXPLICITEMENT pour effacer l'erreur précédente
    state = state.copyWith(status: AuthStatus.loading, error: null);

    try {
      await _authService.login(email, password);
      final role = await _authService.getRole();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        role:   role,
        error:  null,
      );
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(
        status: AuthStatus.error,
        error:  msg,   // ← l'erreur est bien stockée
      );
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      role:   null,
      error:  null,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);