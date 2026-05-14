// core/router/app_routes.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:agent_app/features/auth/providers/auth_provider.dart';
import 'package:agent_app/features/auth/screens/login_screen.dart';
import 'package:agent_app/features/home/screens/home_screen.dart';
import 'package:agent_app/features/alert/screens/create_alert_screen.dart';
import 'package:agent_app/features/alert/screens/my_alerts_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final auth       = ref.read(authProvider);
      final isLoggedIn = auth.isAuthenticated;
      final isLogin    = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLogin) return '/login';
      if (isLoggedIn  &&  isLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login',        builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/home',         builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/create-alert', builder: (_, __) => const CreateAlertScreen()),
      GoRoute(path: '/my-alerts',    builder: (_, __) => const MyAlertsScreen()),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page introuvable: ${state.error}')),
    ),
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}