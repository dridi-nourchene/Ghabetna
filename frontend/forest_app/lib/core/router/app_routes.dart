// core/router/app_routes.dart  ← VERSION FINALE

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/activation_screen.dart';
import '../../features/admin/screens/admin_shell.dart';
import '../../features/admin/screens/admin_dashboard.dart';
import '../../features/admin/screens/admin_users_screen.dart';
import '../../features/admin/screens/admin_create_user_screen.dart';
import '../../features/admin/screens/admin_edit_user_screen.dart';

class _PlaceholderScreen extends StatelessWidget {
  final String name;
  const _PlaceholderScreen(this.name);
  @override
  Widget build(BuildContext context) => Center(
        child: Text(name,
            style: const TextStyle(fontSize: 18, color: Colors.grey)),
      );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',

    redirect: (context, state) {
      if (authState.status == AuthStatus.initial) return null;

      final isLoggedIn    = authState.isAuthenticated;
      final isActivatePage = state.matchedLocation.startsWith('/activate');
      final isLoginPage    = state.matchedLocation == '/login' || isActivatePage;

      // /activate est toujours accessible — même si l'admin est connecté
      // (c'est l'utilisateur nouvellement créé qui active son compte)
      if (isActivatePage) return null;

      if (!isLoggedIn && !isLoginPage) return '/login';

      if (isLoggedIn && isLoginPage) {
        return switch (authState.role) {
          'admin'      => '/admin/dashboard',
          'supervisor' => '/supervisor/dashboard',
          'agent'      => '/agent/dashboard',
          _            => '/login',
        };
      }
      return null;
    },

    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/activate',
        builder: (_, state) => ActivationScreen(
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),

      // ── ADMIN shell ──────────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin/dashboard',
            builder: (_, __) => const AdminDashboard(),
          ),

          // ✅ Liste des utilisateurs
          GoRoute(
            path: '/admin/users',
            builder: (_, __) => const AdminUsersScreen(),
          ),

          // ✅ Créer un utilisateur
          // IMPORTANT: /new doit être déclaré AVANT /:id
          // sinon GoRouter traite "new" comme un userId
          GoRoute(
            path: '/admin/users/new',
            builder: (_, __) => const AdminCreateUserScreen(),
          ),

          // ✅ Modifier un utilisateur
          GoRoute(
            path: '/admin/users/:id',
            builder: (_, state) => AdminEditUserScreen(
              userId: state.pathParameters['id']!,
            ),
          ),

          GoRoute(
            path: '/admin/forests',
            builder: (_, __) => const _PlaceholderScreen('Forêts'),
          ),
          GoRoute(
            path: '/admin/alerts',
            builder: (_, __) => const _PlaceholderScreen('Alertes'),
          ),
          GoRoute(
            path: '/admin/reports',
            builder: (_, __) => const _PlaceholderScreen('Rapports'),
          ),
          GoRoute(
            path: '/admin/settings',
            builder: (_, __) => const _PlaceholderScreen('Paramètres'),
          ),
        ],
      ),

      GoRoute(
        path: '/supervisor/dashboard',
        builder: (_, __) => const _PlaceholderScreen('Supervisor Dashboard'),
      ),
      GoRoute(
        path: '/agent/dashboard',
        builder: (_, __) => const _PlaceholderScreen('Agent Dashboard'),
      ),
    ],

    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page introuvable: ${state.error}')),
    ),
  );
});