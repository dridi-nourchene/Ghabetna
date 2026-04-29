// features/auth/providers/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forest_app/features/auth/services/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? error;
  final String? role;

  const AuthState({
    this.status = AuthStatus.initial,
    this.error,
    this.role,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? error,
    bool clearError = false,
    String? role,
    bool clearRole = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      role: clearRole ? null : (role ?? this.role),
    );
  }

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier({AuthService? authService})
      : _authService = authService ?? AuthService(),
        super(const AuthState()) {
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    try {
      final role = await _authService.getRole();
      if (role != null && role.isNotEmpty) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          role: role,
        );
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      print('Check session error: $e');
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String email, String password) async {
    print('🔐 AuthNotifier.login - START');
    
    // Reset l'état
    state = state.copyWith(
      status: AuthStatus.loading,
      clearError: true,
      clearRole: true,
    );
    print('📊 State set to loading');

    try {
      await _authService.login(email, password);
      final role = await _authService.getRole();
      
      print('✅ Login successful, role: $role');
      state = state.copyWith(
        status: AuthStatus.authenticated,
        role: role,
        clearError: true,
      );
      
    } catch (e) {
      // 🔑 GARDER LE MESSAGE ORIGINAL
      String errorMessage = e.toString();
      print('❌ Original error caught: $errorMessage');
      
      // Enlever 'Exception: ' si présent
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(10);
      }
      
      // Enlever 'Exception:' (sans espace)
      if (errorMessage.startsWith('Exception:')) {
        errorMessage = errorMessage.substring(9);
      }
      
      errorMessage = errorMessage.trim();
      
      // IMPORTANT: Ne pas remplacer le message!
      // Si le message est vide, mettre un message par défaut
      if (errorMessage.isEmpty) {
        errorMessage = 'Erreur de connexion';
      }
      
      print('📝 Final error message: "$errorMessage"');
      
      state = state.copyWith(
        status: AuthStatus.error,
        error: errorMessage,  // ← GARDER LE VRAI MESSAGE
      );
    }
    
    print('🔐 AuthNotifier.login - END');
  }

  Future<void> logout() async {
    await _authService.logout();
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      clearRole: true,
      clearError: true,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);