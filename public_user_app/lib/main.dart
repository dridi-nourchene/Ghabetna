import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_router.dart';
import 'core/theme.dart';
import 'features/auth/providers/auth_provider.dart';

void main() {
  runApp(const ProviderScope(child: PublicUserApp()));
}

class PublicUserApp extends ConsumerWidget {
  const PublicUserApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statut = ref.watch(authProvider.select((a) => a.statut));

    // Le routeur n'est monté qu'une fois le coffre sécurisé lu. Le monter
    // avant afficherait la connexion puis la remplacerait aussitôt par le
    // chat pour un citoyen déjà connecté — un clignotement désagréable.
    if (statut == StatutAuth.inconnu) {
      return MaterialApp(
        title: 'Ghabetna',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const SplashScreen(),
      );
    }

    return MaterialApp.router(
      title: 'Ghabetna',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
