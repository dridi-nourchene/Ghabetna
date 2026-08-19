import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_router.dart';
import 'core/theme.dart';
import 'features/auth/providers/auth_provider.dart';

void main() {
  runApp(const ProviderScope(child: PublicUserApp()));
}

class PublicUserApp extends ConsumerWidget {
  const PublicUserApp({super.key});

  // Sans ces trois delegates, l'application ne dispose que des libellés
  // anglais fournis par défaut : showDatePicker ne trouve pas de
  // MaterialLocalizations en français et lève une exception avant même de
  // s'ouvrir. C'est ce qui rendait les champs de date inertes.
  //
  // Déclarés ici une seule fois puis réutilisés par les deux MaterialApp,
  // sinon le sélecteur redeviendrait anglais sur l'un des deux chemins.
  static const _delegates = <LocalizationsDelegate<dynamic>>[
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const _locales = [Locale('fr')];

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
        locale: const Locale('fr'),
        supportedLocales: _locales,
        localizationsDelegates: _delegates,
        home: const SplashScreen(),
      );
    }

    return MaterialApp.router(
      title: 'Ghabetna',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('fr'),
      supportedLocales: _locales,
      localizationsDelegates: _delegates,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}