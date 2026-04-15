// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart'; // ✅ AJOUT

import 'core/router/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// ✅ IMPORTANT pour les liens email
  setUrlStrategy(PathUrlStrategy());

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Ghabetna',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 31, 117, 34),
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}