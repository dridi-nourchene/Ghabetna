// lib/core/widgets/
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_app/core/providers/locale_provider.dart';

class LangToggle extends ConsumerWidget {
  const LangToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';

    return GestureDetector(
      onTap: () => ref.read(localeProvider.notifier).toggle(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
        width: 90,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2EE),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Labels FR / AR ─────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'FR',
                    style: TextStyle(
                      fontSize:   11,
                      fontWeight: FontWeight.w700,
                      color: !isArabic
                          ? Colors.transparent
                          : const Color(0xFF4A6454),
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'AR',
                    style: TextStyle(
                      fontSize:   11,
                      fontWeight: FontWeight.w700,
                      color: isArabic
                          ? Colors.transparent
                          : const Color(0xFF4A6454),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            // ── Thumb glissant ─────────────────────────
            AnimatedAlign(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOut,
              alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.all(3),
                width: 44,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color:      Colors.black.withOpacity(0.12),
                      blurRadius: 6,
                      offset:     const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      isArabic ? 'AR' : 'FR',
                      key: ValueKey(isArabic),
                      style: const TextStyle(
                        fontSize:   11,
                        fontWeight: FontWeight.w800,
                        color:      Color(0xFF1A4731),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}