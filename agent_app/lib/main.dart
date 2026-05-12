// main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_app/core/router/app_routers.dart';

void main() {
  runApp(const ProviderScope(child: AgentApp()));
}

class AgentApp extends ConsumerWidget {
  const AgentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title:            'Ghabetna Agent',
      debugShowCheckedModeBanner: false,
      routerConfig:     router,
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