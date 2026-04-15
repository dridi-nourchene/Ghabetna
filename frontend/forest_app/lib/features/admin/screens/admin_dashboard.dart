import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';

// ═══════════════════════════════════════════════════════════════
//  AdminDashboard
// ═══════════════════════════════════════════════════════════════

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête page ────────────────────────────────────
          const Text('Dashboard',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3)),
          const SizedBox(height: 3),
          const Text('Surveille et gère les forêts algériennes.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 20),

          // ── Stat cards ──────────────────────────────────────
          const _StatsRow(),
          const SizedBox(height: 18),

          // ── Ligne du bas : utilisateurs + alertes ───────────
          const _BottomRow(),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
//  STAT CARDS
// ───────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Row(
        children: [
          // Card verte (primary)
          Expanded(
            flex: 12,
            child: _StatCard.primary(
              label: 'Utilisateurs actifs',
              value: '47',
              sub: '↑ Augmenté ce mois',
              onTap: () => context.go('/admin/users'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 10,
            child: _StatCard.white(
              label: 'Forêts gérées',
              value: '12',
              sub: '8 wilayas couvertes',
              subColor: AppColors.textMuted,
              onTap: () => context.go('/admin/forests'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 10,
            child: _StatCard.white(
              label: 'Alertes actives',
              value: '5',
              sub: '3 incendies · 2 intrusions',
              subColor: AppColors.danger,
              onTap: () => context.go('/admin/alerts'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 10,
            child: _StatCard.white(
              label: 'Comptes en attente',
              value: '8',
              sub: 'À activer par email',
              subColor: AppColors.warning,
              onTap: () => context.go('/admin/users'),
            ),
          ),
        ],
      );
    });
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color? subColor;
  final bool isPrimary;
  final VoidCallback? onTap;

  const _StatCard._({
    required this.label,
    required this.value,
    required this.sub,
    required this.isPrimary,
    this.subColor,
    this.onTap,
  });

  factory _StatCard.primary({
    required String label,
    required String value,
    required String sub,
    VoidCallback? onTap,
  }) =>
      _StatCard._(
          label: label,
          value: value,
          sub: sub,
          isPrimary: true,
          onTap: onTap);

  factory _StatCard.white({
    required String label,
    required String value,
    required String sub,
    Color? subColor,
    VoidCallback? onTap,
  }) =>
      _StatCard._(
          label: label,
          value: value,
          sub: sub,
          isPrimary: false,
          subColor: subColor,
          onTap: onTap);

  @override
  Widget build(BuildContext context) {
    final bg = isPrimary ? AppColors.primaryDark : AppColors.bgCard;
    final labelColor =
        isPrimary ? Colors.white.withOpacity(0.55) : AppColors.textSecondary;
    final valueColor = isPrimary ? Colors.white : AppColors.textPrimary;
    final resolvedSubColor = isPrimary
        ? Colors.white.withOpacity(0.5)
        : (subColor ?? AppColors.textMuted);
    final arrowBg = isPrimary
        ? Colors.white.withOpacity(0.15)
        : AppColors.primaryLight;
    final arrowColor =
        isPrimary ? Colors.white.withOpacity(0.7) : AppColors.primaryMid;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary ? AppColors.primaryDark : AppColors.border,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(label,
                      style: TextStyle(fontSize: 11, color: labelColor)),
                ),
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: arrowBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_outward,
                      size: 13, color: arrowColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                    height: 1)),
            const SizedBox(height: 8),
            Text(sub,
                style: TextStyle(fontSize: 11, color: resolvedSubColor)),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
//  BOTTOM ROW
// ───────────────────────────────────────────────────────────────

class _BottomRow extends StatelessWidget {
  const _BottomRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _UsersCard()),
        const SizedBox(width: 12),
        Expanded(child: _AlertsCard()),
      ],
    );
  }
}

// ── Users card ────────────────────────────────────────────────

class _UsersCard extends StatelessWidget {
  static const _users = [
    _UserRow(initials: 'KA', name: 'Karim Amrani',   role: 'Superviseur · Forêt Chréa',    status: UserStatus.active),
    _UserRow(initials: 'SB', name: 'Sara Benali',    role: 'Agent · Forêt Theniet',         status: UserStatus.pending),
    _UserRow(initials: 'YM', name: 'Yacine Meziane', role: 'Agent · Forêt Beni-Salah',     status: UserStatus.active),
    _UserRow(initials: 'NL', name: 'Nadia Lahlou',   role: 'Superviseur · Forêt Akfadou',  status: UserStatus.newUser),
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          AppCardHeader(
            title: 'Derniers utilisateurs',
            linkLabel: 'Voir tous →',
            onLinkTap: () => context.go('/admin/users'),
          ),
          const SizedBox(height: 12),
          ..._users,
        ],
      ),
    );
  }
}

enum UserStatus { active, pending, newUser }

class _UserRow extends StatelessWidget {
  final String initials;
  final String name;
  final String role;
  final UserStatus status;

  const _UserRow({
    required this.initials,
    required this.name,
    required this.role,
    required this.status,
  });

  Color get _avatarBg => switch (status) {
        UserStatus.active  => AppColors.successBg,
        UserStatus.pending => AppColors.warningBg,
        UserStatus.newUser => AppColors.infoBg,
      };

  Color get _avatarFg => switch (status) {
        UserStatus.active  => AppColors.primaryMid,
        UserStatus.pending => const Color(0xFF92400E),
        UserStatus.newUser => AppColors.info,
      };

  StatusPill get _pill => switch (status) {
        UserStatus.active  => StatusPill.active(),
        UserStatus.pending => StatusPill.pending(),
        UserStatus.newUser => StatusPill.newUser(),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
            top: BorderSide(color: AppColors.borderLight, width: 0.5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: _avatarBg,
            child: Text(initials,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _avatarFg)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                Text(role,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ),
          _pill,
        ],
      ),
    );
  }
}

// ── Alerts card ───────────────────────────────────────────────

class _AlertsCard extends StatelessWidget {
  static const _alerts = [
    _AlertRow(
      color: AppColors.danger,
      text: 'Incendie détecté — Partition N3, Chréa',
      time: 'Il y a 14 min · Agent A12 · Photo jointe',
    ),
    _AlertRow(
      color: AppColors.danger,
      text: 'Intrusion détectée — Theniet El Had',
      time: 'Il y a 1h 22min · Capteur IoT',
    ),
    _AlertRow(
      color: AppColors.warning,
      text: 'Température anormale — Beni-Salah Est',
      time: 'Il y a 3h · Seuil dépassé 42°C',
    ),
    _AlertRow(
      color: AppColors.success,
      text: 'Alerte résolue — Akfadou, Partition S1',
      time: "Aujourd'hui 09:17 · Clôturée",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          AppCardHeader(
            title: 'Alertes récentes',
            linkLabel: 'Voir toutes →',
            onLinkTap: () => context.go('/admin/alerts'),
          ),
          const SizedBox(height: 12),
          ..._alerts,
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final Color color;
  final String text;
  final String time;

  const _AlertRow({
    required this.color,
    required this.text,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
            top: BorderSide(color: AppColors.borderLight, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8, height: 8,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(time,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}