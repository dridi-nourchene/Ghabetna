// features/profile/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:agent_app/l10n/app_localizations.dart';
import 'package:agent_app/core/theme/app_colors.dart';
import 'package:agent_app/features/auth/providers/auth_provider.dart';
import 'package:agent_app/features/profile/models/agent_profile.dart';
import 'package:agent_app/features/profile/providers/profile_provider.dart';

/// Identité, affectation et superviseur de l'agent — même organisation que
/// l'écran Profil de public_user_app. La déconnexion est ici, en bas, et
/// non plus dans la barre de navigation.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context);
    final state = ref.watch(profileProvider);

    return RefreshIndicator(
      color:     AgentColors.primary,
      onRefresh: () => ref.read(profileProvider.notifier).load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          _Entete(nom: state.nom, initiales: state.initiales, l10n: l10n),
          const SizedBox(height: 22),

          _Section(
            titre: l10n.profileContact,
            lignes: [
              _Ligne(libelle: l10n.profileEmail, valeur: state.email),
              if (state.profile?.phone != null)
                _Ligne(libelle: l10n.profilePhone,
                    valeur: state.profile!.phone!),
            ],
          ),
          const SizedBox(height: 14),

          if (state.isLoading && state.profile == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(
                    color: AgentColors.primary, strokeWidth: 2.5),
              ),
            )
          else if (state.hasError && state.profile == null)
            _Erreur(
              message: l10n.profileLoadError,
              retry:   l10n.retry,
              onRetry: () => ref.read(profileProvider.notifier).load(),
            )
          else if (state.profile != null)
            ..._affectation(state.profile!, l10n),

          const SizedBox(height: 28),
          _BoutonDeconnexion(l10n: l10n),
        ],
      ),
    );
  }

  List<Widget> _affectation(AgentProfile p, AppLocalizations l10n) {
    if (!p.isAssigned) {
      return [
        _Section(
          titre: l10n.profileAssignment,
          lignes: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AgentColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.profileNotAssigned,
                      style: const TextStyle(
                          fontSize: 13, color: AgentColors.textSecondary)),
                ),
              ]),
            ),
          ],
        ),
      ];
    }

    return [
      _Section(
        titre: l10n.profileAssignment,
        lignes: [
          if (p.forestName != null)
            _Ligne(libelle: l10n.profileForest, valeur: p.forestName!,
                icone: Icons.park_outlined),
          _Ligne(libelle: l10n.profileParcelle, valeur: p.parcelleName!,
              icone: Icons.crop_square_rounded),
        ],
      ),
      if (p.superviseur != null) ...[
        const SizedBox(height: 14),
        _Section(
          titre: l10n.profileSupervisor,
          lignes: [
            _Ligne(libelle: l10n.profileSupervisor,
                valeur: p.superviseur!.nom,
                icone: Icons.person_outline),
            if (p.superviseur!.phone != null)
              _Ligne(libelle: l10n.profileSupervisorPhone,
                  valeur: p.superviseur!.phone!,
                  icone: Icons.phone_outlined),
          ],
        ),
      ],
    ];
  }
}

// ── En-tête ──────────────────────────────────────────────────

class _Entete extends StatelessWidget {
  final String           nom;
  final String           initiales;
  final AppLocalizations l10n;

  const _Entete({
    required this.nom,
    required this.initiales,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          width: 76, height: 76,
          decoration: const BoxDecoration(
            color: AgentColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(initiales,
              style: const TextStyle(
                  fontSize:   26,
                  fontWeight: FontWeight.w600,
                  color:      Colors.white)),
        ),
        const SizedBox(height: 12),
        Text(nom,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize:   18,
                fontWeight: FontWeight.w700,
                color:      AgentColors.textPrimary)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color:        AgentColors.primaryLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(l10n.profileRoleAgent,
              style: const TextStyle(
                  fontSize:   12,
                  fontWeight: FontWeight.w600,
                  color:      AgentColors.primary)),
        ),
      ]);
}

// ── Carte de section ─────────────────────────────────────────

class _Section extends StatelessWidget {
  final String       titre;
  final List<Widget> lignes;

  const _Section({required this.titre, required this.lignes});

  @override
  Widget build(BuildContext context) => Container(
        width:   double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8EDE8), width: 0.5),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre,
                style: const TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.w600,
                    color:      AgentColors.textSecondary)),
            const SizedBox(height: 8),
            ...lignes,
          ],
        ),
      );
}

class _Ligne extends StatelessWidget {
  final String    libelle;
  final String    valeur;
  final IconData? icone;

  const _Ligne({required this.libelle, required this.valeur, this.icone});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icone != null) ...[
              Icon(icone, size: 16, color: AgentColors.primaryMid),
              const SizedBox(width: 8),
            ],
            SizedBox(
              width: 120,
              child: Text(libelle,
                  style: const TextStyle(
                      fontSize: 12.5, color: AgentColors.textMuted)),
            ),
            Expanded(
              child: Text(valeur,
                  style: const TextStyle(
                      fontSize:   13.5,
                      fontWeight: FontWeight.w500,
                      color:      AgentColors.textPrimary)),
            ),
          ],
        ),
      );
}

class _Erreur extends StatelessWidget {
  final String       message;
  final String       retry;
  final VoidCallback onRetry;

  const _Erreur({
    required this.message,
    required this.retry,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(children: [
          const Icon(Icons.error_outline,
              color: AgentColors.danger, size: 32),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AgentColors.textSecondary)),
          TextButton(
            onPressed: onRetry,
            child: Text(retry,
                style: const TextStyle(color: AgentColors.primary)),
          ),
        ]),
      );
}

// ── Déconnexion ──────────────────────────────────────────────

class _BoutonDeconnexion extends ConsumerWidget {
  final AppLocalizations l10n;
  const _BoutonDeconnexion({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _confirmer(context, ref),
          icon: const Icon(Icons.logout_rounded,
              size: 18, color: AgentColors.danger),
          label: Text(l10n.navLogout,
              style: const TextStyle(
                  color:      AgentColors.danger,
                  fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: AgentColors.danger.withOpacity(0.4)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );

  void _confirmer(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.logoutTitle,
            style: const TextStyle(
                fontSize:   17,
                fontWeight: FontWeight.w700,
                color:      AgentColors.textPrimary)),
        content: Text(l10n.logoutMessage,
            style: const TextStyle(
                fontSize: 14, color: AgentColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.logoutCancel,
                style: const TextStyle(color: AgentColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AgentColors.primary,
              foregroundColor: Colors.white,
              elevation:       0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(l10n.logoutConfirm),
          ),
        ],
      ),
    );
  }
}
