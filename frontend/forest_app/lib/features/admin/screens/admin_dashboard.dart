import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../providers/dashboard_stats_provider.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  String _selectedKpi = 'active_users'; // sélectionné par défaut

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardStatsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardStatsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dashboard',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3)),
          const SizedBox(height: 3),
          const Text('Surveille et gère les forêts tunisiennes.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 20),

          _StatsRow(
            stats: state.stats,
            isLoading: state.isLoading,
            selectedKpi: _selectedKpi,
            onSelect: (key) => setState(() => _selectedKpi = key),
          ),
          const SizedBox(height: 18),

          _BottomRow(stats: state.stats, isLoading: state.isLoading),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
//  STAT CARDS — sélecteur, "Utilisateurs actifs" en 1ère position
// ───────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final DashboardStats stats;
  final bool isLoading;
  final String selectedKpi;
  final ValueChanged<String> onSelect;

  const _StatsRow({
    required this.stats,
    required this.isLoading,
    required this.selectedKpi,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final v = (int n) => isLoading ? '—' : '$n';

    return Row(
      children: [
        Expanded(
          flex: 12,
          child: _StatCard(
            kpiKey: 'active_users',
            label: 'Utilisateurs actifs',
            value: v(stats.activeUsers),
            sub: 'Comptes activés',
            isSelected: selectedKpi == 'active_users',
            onTap: () => onSelect('active_users'),
            onArrowTap: () => context.go('/admin/users'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 10,
          child: _StatCard(
            kpiKey: 'pending_users',
            label: 'Comptes en attente',
            value: v(stats.pendingUsers),
            sub: 'À activer par email',
            subColor: AppColors.warning,
            isSelected: selectedKpi == 'pending_users',
            onTap: () => onSelect('pending_users'),
            onArrowTap: () => context.go('/admin/users'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 10,
          child: _StatCard(
            kpiKey: 'forests',
            label: 'Forêts gérées',
            value: v(stats.forestsCount),
            sub: ' ',
            subColor: AppColors.textMuted,
            isSelected: selectedKpi == 'forests',
            onTap: () => onSelect('forests'),
            onArrowTap: () => context.go('/admin/forests'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 10,
          child: _StatCard(
            kpiKey: 'parcelles',
            label: 'Parcelles gérées',
            value: v(stats.parcellesCount),
            sub: ' ',
            subColor: AppColors.textMuted,
            isSelected: selectedKpi == 'parcelles',
            onTap: () => onSelect('parcelles'),
            // FIX : /admin/parcels n'existe pas — parcelles vivent
            // dans l'onglet "Parcelles" de /admin/forests
            onArrowTap: () => context.go('/admin/forests'),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatefulWidget {
  final String kpiKey;
  final String label;
  final String value;
  final String sub;
  final Color? subColor;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onArrowTap;

  const _StatCard({
    required this.kpiKey,
    required this.label,
    required this.value,
    required this.sub,
    required this.isSelected,
    required this.onTap,
    required this.onArrowTap,
    this.subColor,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;

    // Priorité : sélectionné > survolé > défaut
    final bg = isSelected
        ? AppColors.primaryDark
        : _hovering
            ? AppColors.primaryLight
            : AppColors.bgCard;

    final borderColor = isSelected
        ? AppColors.primaryDark
        : _hovering
            ? AppColors.primaryMid.withOpacity(0.4)
            : AppColors.border;

    final labelColor = isSelected ? Colors.white.withOpacity(0.55) : AppColors.textSecondary;
    final valueColor = isSelected ? Colors.white : AppColors.textPrimary;
    final resolvedSubColor =
        isSelected ? Colors.white.withOpacity(0.5) : (widget.subColor ?? AppColors.textMuted);
    final arrowBg = isSelected ? Colors.white.withOpacity(0.15) : AppColors.primaryLight;
    final arrowColor = isSelected ? Colors.white.withOpacity(0.7) : AppColors.primaryMid;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit:  (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: Text(widget.label, style: TextStyle(fontSize: 11, color: labelColor))),
                  // Flèche = navigation, tap isolé du reste de la card
                  GestureDetector(
                    onTap: widget.onArrowTap,
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(color: arrowBg, shape: BoxShape.circle),
                      child: Icon(Icons.arrow_outward, size: 13, color: arrowColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(widget.value,
                  style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w700, color: valueColor, height: 1)),
              const SizedBox(height: 8),
              Text(widget.sub, style: TextStyle(fontSize: 11, color: resolvedSubColor)),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
//  BOTTOM ROW
// ───────────────────────────────────────────────────────────────

class _BottomRow extends StatelessWidget {
  final DashboardStats stats;
  final bool isLoading;
  const _BottomRow({required this.stats, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _RecentUsersCard(users: stats.recentUsers, isLoading: isLoading)),
        const SizedBox(width: 12),
        Expanded(child: _RiskForestsCard(forests: stats.riskForests, isLoading: isLoading)),
      ],
    );
  }
}

// ── 5 derniers utilisateurs ──────────────────────────────────

class _RecentUsersCard extends StatelessWidget {
  final List<RecentUser> users;
  final bool isLoading;
  const _RecentUsersCard({required this.users, required this.isLoading});

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
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (users.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Aucun utilisateur pour l\'instant',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ),
            )
          else
            ...users.map((u) => _UserRow(user: u)),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final RecentUser user;
  const _UserRow({required this.user});

  (Color, Color) get _avatarColors => switch (user.status) {
        'active'   => (AppColors.successBg, AppColors.primaryMid),
        'inactive' => (AppColors.warningBg, const Color(0xFF92400E)),
        'banned'   => (AppColors.dangerBg,  AppColors.danger),
        _          => (AppColors.infoBg,    AppColors.info),
      };

  Widget get _pill => switch (user.status) {
        'active'   => StatusPill.active(),
        'inactive' => StatusPill.pending(),
        'banned'   => const StatusPill(label: 'Banni', bg: AppColors.dangerBg, fg: AppColors.danger),
        _          => StatusPill.newUser(),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _avatarColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderLight, width: 0.5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: bg,
            child: Text(user.initials,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                Text(user.roleLabel,
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ),
          _pill,
        ],
      ),
    );
  }
}

// ── Top 5 forêts à risque (agrégé, sans détail d'alerte) ────────

class _RiskForestsCard extends StatelessWidget {
  final List<RiskForest> forests;
  final bool isLoading;
  const _RiskForestsCard({required this.forests, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          AppCardHeader(
            title: 'Top forêts à risque',
            linkLabel: 'Analytics →',
            onLinkTap: () => context.go('/admin/analytics'),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (forests.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Aucune alerte enregistrée',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ),
            )
          else
            ...forests.map((f) => _RiskForestRow(forest: f)),
        ],
      ),
    );
  }
}

class _RiskForestRow extends StatelessWidget {
  final RiskForest forest;
  const _RiskForestRow({required this.forest});

  @override
  Widget build(BuildContext context) {
    final total = forest.rejectedCount + forest.confirmedCount;
    final riskColor = forest.rejectedCount > forest.confirmedCount
        ? AppColors.danger
        : (forest.rejectedCount > 0 ? AppColors.warning : AppColors.success);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderLight, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8, height: 8,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(color: riskColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(forest.forestName,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  '${forest.rejectedCount} rejetées · ${forest.confirmedCount} confirmées/en cours',
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Text('$total',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}