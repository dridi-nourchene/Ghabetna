import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/auth/ui/inscription_screen.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/chat/ui/chat_screen.dart';
import 'theme.dart';

/// Routeur de l'application.
///
/// Le provider est reconstruit à chaque changement de statut
/// d'authentification : c'est ce qui déclenche la réévaluation de
/// [redirect]. Reconstruire le routeur remet la pile de navigation à zéro,
/// ce qui est exactement le comportement voulu à la connexion comme à la
/// déconnexion — on ne veut pas pouvoir revenir sur l'écran de login une
/// fois connecté.
final appRouterProvider = Provider<GoRouter>((ref) {
  final statut = ref.watch(authProvider.select((a) => a.statut));

  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/inscription',
        builder: (_, __) => const InscriptionScreen(),
      ),
      GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
    ],
    redirect: (context, state) {
      // Tant qu'on n'a pas lu le coffre sécurisé, on ne redirige pas.
      // Sans ce cas, la page de connexion apparaîtrait une fraction de
      // seconde avant d'être remplacée par le chat.
      if (statut == StatutAuth.inconnu) return null;

      final chemin = state.matchedLocation;
      final surAuth = chemin == '/login' || chemin == '/inscription';
      final connecte = statut == StatutAuth.connecte;

      if (!connecte && !surAuth) return '/login';
      if (connecte && surAuth) return '/chat';
      return null;
    },
  );
});

/// Affiché pendant la lecture du coffre sécurisé, puis remplacé par la
/// redirection. Quelques dizaines de millisecondes en pratique.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.authVert,
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.authBlanc),
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}
