// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:agent_app/core/router/app_routers.dart';
import 'package:agent_app/core/providers/locale_provider.dart';

void main() {
  runApp(const ProviderScope(child: AgentApp()));
}

class AgentApp extends ConsumerWidget {
  const AgentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title:                      'Ghabetna Agent',
      debugShowCheckedModeBanner: false,
      routerConfig:               router,

      // ── Localisation ──────────────────────────────────
      locale: locale,
      supportedLocales: const [
        Locale('fr'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: ThemeData(
        useMaterial3:     true,
        fontFamily:       'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor:   const Color(0xFF1A4731),
          brightness:  Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A2E1A),
          elevation:       0,
          centerTitle:     true,
        ),
      ),
    );
  }
}