import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forest_app/features/auth/services/auth_service.dart';

// ── Enum Status ───────────────────────────────────────────
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

// ── State ─────────────────────────────────────────────────
class AuthState {
  final AuthStatus status;
  final String?    error;
  final String?    role;

  const AuthState({
    this.status = AuthStatus.initial,
    this.error,
    this.role,
  });

  // FIX: role behaves like error — no ?? fallback.
  // Passing null explicitly now correctly clears the value.
  // Before: role: role ?? this.role  → null was ignored, old role persisted after logout.
  // After:  role: role               → null clears it, just like error does.
  AuthState copyWith({
    AuthStatus? status,
    String?     error,
    String?     role,
  }) {
    return AuthState(
      status: status ?? this.status,
      error:  error,  // null clears error  ✅
      role:   role,   // null clears role   ✅ (was: role ?? this.role)
    );
  }

  bool get isLoading       => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
}

// ── Notifier ──────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  final _authService = AuthService();

  AuthNotifier() : super(const AuthState()) {
    _checkExistingSession();
  }

  // ── Vérifier si déjà connecté au démarrage ────────────
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

  // ── Login ─────────────────────────────────────────────
  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);

    try {
      await _authService.login(email, password);
      final role = await _authService.getRole();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        role:   role,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error:  e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ── Logout ────────────────────────────────────────────
  Future<void> logout() async {
    await _authService.logout();
    // role: null now correctly clears the role thanks to the copyWith fix
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      role:   null,
    );
  }
}

// ── Provider global ───────────────────────────────────────
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);