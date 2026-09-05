import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/accueil/ui/accueil_screen.dart';
import '../features/alert/ui/alertes_screen.dart';
import '../features/alert/ui/signaler_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/profil/ui/profil_screen.dart';
import '../features/auth/ui/inscription_screen.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/chat/ui/chat_screen.dart';
import 'theme.dart';
import 'widgets/barre_navigation.dart';
import 'widgets/ecran_a_venir.dart';

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

      // ── Les cinq onglets ──────────────────────────────────────────
      // Ils partagent une coquille : un Scaffold unique qui porte la barre
      // basse. Sans ShellRoute, chaque écran devrait redessiner la barre et
      // elle clignoterait à chaque changement d'onglet.
      ShellRoute(
        builder: (context, state, child) => _CoquilleCitoyen(
          chemin: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
          GoRoute(path: '/alertes', builder: (_, __) => const AlertesScreen()),
          GoRoute(path: '/accueil', builder: (_, __) => const AccueilScreen()),
          GoRoute(
            path: '/documents',
            builder: (_, __) => const EcranAVenir(
              titre: 'Documents',
              description:
                  'Les textes qui s\'appliquent à votre spécialité, '
                  'et les pièces de votre dossier.',
              icone: Icons.description_outlined,
            ),
          ),
          GoRoute(path: '/profil', builder: (_, __) => const ProfilScreen()),
        ],
      ),

      // ── Hors coquille ─────────────────────────────────────────────
      // Signaler est une ACTION, pas une destination : elle prend l'écran
      // entier, se termine par un envoi ou un abandon, et ramène d'où l'on
      // vient. Lui laisser la barre basse inviterait à en sortir en plein
      // formulaire, en perdant la saisie.
      GoRoute(path: '/signaler', builder: (_, __) => const SignalerScreen()),
    ],
    redirect: (context, state) {
      // Tant qu'on n'a pas lu le coffre sécurisé, on ne redirige pas.
      // Sans ce cas, la page de connexion apparaîtrait une fraction de
      // seconde avant d'être remplacée par l'accueil.
      if (statut == StatutAuth.inconnu) return null;

      final chemin = state.matchedLocation;
      final surAuth = chemin == '/login' || chemin == '/inscription';
      final connecte = statut == StatutAuth.connecte;

      if (!connecte && !surAuth) return '/login';

      // Le point d'arrivée après connexion est l'accueil, plus le chat :
      // l'assistant est devenu un onglet parmi cinq.
      if (connecte && surAuth) return '/accueil';
      return null;
    },
  );
});

/// Scaffold partagé par les cinq onglets.
class _CoquilleCitoyen extends StatelessWidget {
  const _CoquilleCitoyen({required this.chemin, required this.child});

  final String chemin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Le clavier ouvert fait disparaître la barre. Deux raisons :
    //
    //  1. Dans le chat, la barre de saisie doit rester collée au clavier.
    //     Une barre d'onglets intercalée entre les deux est illisible.
    //  2. Sur un petit écran, clavier + saisie + cinq onglets ne laissent
    //     plus assez de place pour voir ce qu'on écrit.
    //
    // Rien ne se perd : l'utilisateur ferme le clavier et la barre revient.
    final clavierOuvert = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.surface0,

      // false : sans cela le Scaffold remonterait la barre au-dessus du
      // clavier au lieu de la masquer, et ChatScreen — qui a son propre
      // Scaffold — gérerait le décalage une seconde fois.
      resizeToAvoidBottomInset: false,

      body: child,
      bottomNavigationBar: clavierOuvert
          ? null
          : BarreNavigation(
              cheminActif: chemin,
              // go et non push : les onglets sont des destinations, pas des
              // pages empilées. push ferait grossir la pile à chaque
              // aller-retour et le bouton retour Android remonterait tout
              // l'historique d'onglets avant de quitter.
              onSelect: (route) {
                if (route != chemin) context.go(route);
              },
            ),
    );
  }
}

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