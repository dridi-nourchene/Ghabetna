import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:agent_app/core/theme/app_colors.dart';
import 'package:agent_app/features/auth/providers/auth_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AgentColors.bgPage,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color:        AgentColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.park, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ghabetna',
                        style: TextStyle(
                            fontSize:      20,
                            fontWeight:    FontWeight.w700,
                            color:         AgentColors.textPrimary,
                            letterSpacing: -0.3)),
                    Text(
                      'Agent · ${auth.email ?? ''}',
                      style: const TextStyle(
                          fontSize: 12,
                          color:    AgentColors.textMuted),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.logout_outlined,
                      color: AgentColors.textMuted),
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ]),

              const SizedBox(height: 40),

              // ── Salutation ──────────────────────────────
              const Text('Bonjour 👋',
                  style: TextStyle(
                      fontSize:   26,
                      fontWeight: FontWeight.w700,
                      color:      AgentColors.textPrimary)),
              const SizedBox(height: 6),
              const Text('Que voulez-vous faire ?',
                  style: TextStyle(
                      fontSize: 15,
                      color:    AgentColors.textMuted)),

              const SizedBox(height: 40),

              // ── Carte Déclarer une alerte ───────────────
              _ActionCard(
                icon:      Icons.warning_amber_rounded,
                iconColor: const Color(0xFFE05C2A),
                iconBg:    const Color(0xFFFFF0EA),
                title:     'Déclarer une alerte',
                subtitle:  'Signaler un incendie, vol ou autre incident',
                onTap:     () => context.go('/create-alert'),
              ),

              const SizedBox(height: 16),

              // ── Carte Mes alertes ───────────────────────
              _ActionCard(
                icon:      Icons.list_alt_rounded,
                iconColor: AgentColors.primary,
                iconBg:    AgentColors.primaryLight,
                title:     'Mes alertes',
                subtitle:  'Consulter l\'historique de vos signalements',
                onTap:     () => context.go('/my-alerts'),
              ),

              const Spacer(),

              // ── Footer ──────────────────────────────────
              Center(
                child: Text(
                  'DGF — Direction Générale des Forêts',
                  style: TextStyle(
                      fontSize: 11,
                      color:    AgentColors.textMuted.withOpacity(0.6)),
                ),
              ),
            ],
          ),
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
            border: Border.all(
                color: const Color(0xFFE8EDE8), width: 0.5),
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
                          color:      AgentColors.textPrimary)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 13,
                          color:    AgentColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AgentColors.textMuted, size: 20),
          ]),
        ),
      );
}