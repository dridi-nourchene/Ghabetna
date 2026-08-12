import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/chat/ui/chat_screen.dart';

void main() {
  runApp(const ProviderScope(child: PublicUserApp()));
}

class PublicUserApp extends StatelessWidget {
  const PublicUserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ghabetna',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const ChatScreen(),
    );
  }
}