// core/router/app_routes.dart

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
import '../../features/admin/screens/admin_forests_screen.dart';
import '../../features/admin/screens/admin_create_forest_screen.dart';
import '../../features/admin/screens/admin_edit_forest_screen.dart';
import '../../features/admin/screens/admin_create_parcelle_screen.dart';
import '../../features/admin/screens/admin_assign_agents_screen.dart';
import '../../features/admin/screens/admin_assign_superviseurs_screen.dart';
// --- SUPERVISEUR ───────────────────────────────────────────────
import '../../features/supervisor/screens/supervisor_shell.dart';
import '../../features/supervisor/screens/supervisor_map_screen.dart';
import '../../features/supervisor/screens/supervisor_historique_screen.dart';
import '../../features/supervisor/screens/supervisor_alert_detail_screen.dart';
import '../../features/admin/screens/admin_analytics_screen.dart';


//--- admin demande user ---------------------------------
import '../../features/dossier/screens/admin_dossiers_screen.dart';
import '../../features/dossier/screens/admin_dossier_detail_screen.dart';


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
  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final authState = ref.read(authProvider);

      if (authState.status == AuthStatus.initial)  return null;
      if (authState.status == AuthStatus.loading)  return null;
      if (authState.status == AuthStatus.error)    return null;

      final isLoggedIn     = authState.isAuthenticated;
      final isActivatePage = state.matchedLocation.startsWith('/activate');
      final isLoginPage    = state.matchedLocation == '/login' || isActivatePage;

      if (isActivatePage) return null;
      if (!isLoggedIn && !isLoginPage) return '/login';

      if (isLoggedIn && isLoginPage) {
        return switch (authState.role) {
          'admin'      => '/admin/dashboard',
          'supervisor' => '/supervisor/map',
          'agent'      => '/agent/dashboard',
          _            => '/login',
        };
      }
      return null;
    },

    routes: [
      GoRoute(
        path:    '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path:    '/activate',
        builder: (_, state) => ActivationScreen(
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),

      // ══════════════════════════════════════════════════════
      //  ADMIN shell
      // ══════════════════════════════════════════════════════
      ShellRoute(
        builder: (_, __, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path:    '/admin/dashboard',
            builder: (_, __) => const AdminDashboard(),
          ),
          GoRoute(
            path:    '/admin/users',
            builder: (_, __) => const AdminUsersScreen(),
          ),
          GoRoute(
            path:    '/admin/users/new',
            builder: (_, __) => const AdminCreateUserScreen(),
          ),
          GoRoute(
            path:    '/admin/users/:id',
            builder: (_, state) => AdminEditUserScreen(
              userId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path:    '/admin/forests',
            builder: (_, __) => const AdminForestsScreen(),
          ),
          GoRoute(
            path:    '/admin/forests/new',
            builder: (_, __) => const AdminCreateForestScreen(),
          ),
          GoRoute(
            path:    '/admin/forests/:forestId/edit',
            builder: (_, state) => AdminEditForestScreen(
              forestId: state.pathParameters['forestId']!,
            ),
          ),
          GoRoute(
            path:    '/admin/forests/:forestId/parcelles/new',
            builder: (_, state) => AdminCreateParcelleScreen(
              forestId: state.pathParameters['forestId']!,
            ),
          ),
          GoRoute(
            path:    '/admin/forests/:forestId/parcelles/:parcelleId/edit',
            builder: (_, state) => AdminCreateParcelleScreen(
              forestId: state.pathParameters['forestId']!,
            ),
          ),
          GoRoute(
            path:    '/admin/assign/agents',
            builder: (_, __) => const AdminAssignAgentsScreen(),
          ),
          GoRoute(
            path:    '/admin/assign/superviseurs',
            builder: (_, __) => const AdminAssignSuperveursScreen(),
          ),
          GoRoute(
            path:    '/admin/alerts',
            builder: (_, __) => const _PlaceholderScreen('Alertes'),
          ),
          GoRoute(
            path:    '/admin/reports',
            builder: (_, __) => const _PlaceholderScreen('Rapports'),
          ),
          GoRoute(
            path:    '/admin/settings',
            builder: (_, __) => const _PlaceholderScreen('Paramètres'),
          ),
          GoRoute(
          path:    '/admin/analytics',
          builder: (_, __) => const AdminAnalyticsScreen(),
        ),
          GoRoute(
            path:    '/admin/dossiers',
            builder: (_, __) => const AdminDossiersScreen(),
          ),
          GoRoute(
            path:    '/admin/dossiers/:profilId',
            builder: (_, state) => AdminDossierDetailScreen(
              profilId: state.pathParameters['profilId']!,
            ),
          ),
          
        ],
      ),

      // ══════════════════════════════════════════════════════
      //  SUPERVISEUR shell
      // ══════════════════════════════════════════════════════
      ShellRoute(
        builder: (_, __, child) => SupervisorShell(child: child),
        routes: [
          GoRoute(
            path:    '/supervisor/map',
            builder: (_, __) => const SupervisorMapScreen(),
          ),
          GoRoute(
            path:    '/supervisor/alerts',
            builder: (_, __) => const SupervisorAlertHistoryScreen(),
          ),
          GoRoute(
            path:    '/supervisor/forests',
            builder: (_, __) =>
                const _PlaceholderScreen('Forêts — vue superviseur'),
          ),
          GoRoute(
            path:    '/supervisor/settings',
            builder: (_, __) =>
                const _PlaceholderScreen('Paramètres superviseur'),
          ),
        ],
      ),

      // ── Page détail alerte superviseur (hors shell) ───────
      // Navigation push depuis la map ou l'historique
      GoRoute(
        path: '/supervisor/alert/:alertId',
        builder: (_, state) => SupervisorAlertDetailScreen(
          alertId: state.pathParameters['alertId']!,
        ),
      ),

      // ══════════════════════════════════════════════════════
      //  AGENT
      // ══════════════════════════════════════════════════════
      GoRoute(
        path:    '/agent/dashboard',
        builder: (_, __) => const _PlaceholderScreen('Agent Dashboard'),
      ),
    ],

    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page introuvable: ${state.error}')),
    ),
  );
  return router;
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated ||
          next.status == AuthStatus.unauthenticated) {
        notifyListeners();
      }
    });
  }
}