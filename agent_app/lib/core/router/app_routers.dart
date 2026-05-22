// lib/core/router/app_routers.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:agent_app/features/auth/providers/auth_provider.dart';
import 'package:agent_app/features/auth/screens/login_screen.dart';
import 'package:agent_app/features/alert/screens/create_alert_screen.dart';
import 'package:agent_app/features/alert/screens/my_alerts_screen.dart';
import 'package:agent_app/core/widgets/main_scaffold.dart';
import 'package:agent_app/core/theme/app_colors.dart';

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
      GoRoute(
        path:    '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainScaffold(child: child, location: state.matchedLocation);
        },
        routes: [
          GoRoute(
            path:    '/home',
            builder: (_, __) => const HomeBody(),
          ),
          GoRoute(
            path:    '/create-alert',
            builder: (_, __) => const CreateAlertBody(),
          ),
          GoRoute(
            path:    '/my-alerts',
            builder: (_, __) => const MyAlertsBody(),
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page introuvable: ${state.error}')),
    ),
  );
});

class HomeBody extends StatelessWidget {
  const HomeBody({super.key});
  @override
  Widget build(BuildContext context) => const _HomeContent();
}

class CreateAlertBody extends StatelessWidget {
  const CreateAlertBody({super.key});
  @override
  Widget build(BuildContext context) => const CreateAlertScreen();
}

class MyAlertsBody extends StatelessWidget {
  const MyAlertsBody({super.key});
  @override
  Widget build(BuildContext context) => const MyAlertsScreen();
}

// ── Home Content ─────────────────────────────────────────────
class _HomeContent extends ConsumerWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ── Salutation ──────────────────────────────
            Text(l10n.homeGreeting,
                style: const TextStyle(
                    fontSize:   26,
                    fontWeight: FontWeight.w700,
                    color:      Color(0xFF1A2E1A))),
            const SizedBox(height: 6),
            Text(l10n.homeQuestion,
                style: const TextStyle(
                    fontSize: 15,
                    color:    Color(0xFF8FA896))),

            const SizedBox(height: 40),

            // ── Carte Déclarer une alerte ───────────────
            _ActionCard(
              icon:      Icons.warning_amber_rounded,
              iconColor: const Color(0xFFE05C2A),
              iconBg:    const Color(0xFFFFF0EA),
              title:     l10n.homeCreateAlert,
              subtitle:  l10n.homeCreateAlertSub,
              onTap:     () => context.go('/create-alert'),
            ),

            const SizedBox(height: 16),

            // ── Carte Mes alertes ───────────────────────
            _ActionCard(
              icon:      Icons.list_alt_rounded,
              iconColor: const Color(0xFF1A4731),
              iconBg:    const Color(0xFFE8F5EE),
              title:     l10n.homeMyAlerts,
              subtitle:  l10n.homeMyAlertsSub,
              onTap:     () => context.go('/my-alerts'),
            ),

            const Spacer(),

            Center(
              child: Text(
                l10n.loginFooter,
                style: TextStyle(
                    fontSize: 11,
                    color:    const Color(0xFF8FA896).withOpacity(0.6)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final Color    iconBg;
  final String   title;
  final String   subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8EDE8), width: 0.5),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset:     const Offset(0, 4),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color:        iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize:   16,
                          fontWeight: FontWeight.w600,
                          color:      Color(0xFF1A2E1A))),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 13,
                          color:    Color(0xFF8FA896))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Color(0xFF8FA896), size: 20),
          ]),
        ),
      );
}

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}