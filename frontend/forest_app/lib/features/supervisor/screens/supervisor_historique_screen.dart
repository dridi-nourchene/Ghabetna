// lib/features/supervisor/screens/supervisor_historique_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../features/alert/models/alert_model.dart';
import '../../../features/alert/providers/supervisor_alert_provider.dart';

class SupervisorHistoriqueScreen extends ConsumerStatefulWidget {
  const SupervisorHistoriqueScreen({super.key});

  @override
  ConsumerState<SupervisorHistoriqueScreen> createState() => _State();
}

class _State extends ConsumerState<SupervisorHistoriqueScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(historiqueProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _onTabChanged(int idx) {
    final status = switch (idx) {
      1 => 'en_cours',
      2 => 'traiter',
      _ => null,
    };
    ref.read(historiqueProvider.notifier).load(status: status);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historiqueProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Historique des alertes',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textMuted, size: 20),
            onPressed: () {
              final status = switch (_tabs.index) {
                1 => 'en_cours',
                2 => 'traiter',
                _ => null,
              };
              ref.read(historiqueProvider.notifier).load(status: status);
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            child: TabBar(
              controller: _tabs,
              onTap: _onTabChanged,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              labelColor: AppColors.primaryDark,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primaryDark,
              indicatorWeight: 2.5,
              tabs: [
                Tab(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Toutes'),
                    const SizedBox(width: 6),
                    _CountBadge(count: state.alerts.length),
                  ]),
                ),
                Tab(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('En cours'),
                    const SizedBox(width: 6),
                    _CountBadge(
                      count: state.alerts.where((a) => a.status == AlertStatus.en_cours).length,
                      color: AppColors.danger,
                    ),
                  ]),
                ),
                Tab(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Traitées'),
                    const SizedBox(width: 6),
                    _CountBadge(
                      count: state.alerts.where((a) => a.status == AlertStatus.traiter).length,
                      color: AppColors.success,
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryMid))
          : state.error != null
              ? _ErrorState(
                  message: state.error!,
                  onRetry: () => ref.read(historiqueProvider.notifier).load(),
                )
              : state.alerts.isEmpty
                  ? const _EmptyState()
                  : _AlertList(alerts: state.alerts),
    );
  }
}


// ══════════════════════════════════════════════════════════════
//  LISTE DES ALERTES
// ══════════════════════════════════════════════════════════════

class _AlertList extends StatelessWidget {
  final List<AlertDetail> alerts;
  const _AlertList({required this.alerts});

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: alerts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _AlertCard(alert: alerts[i]),
      );
}

class _AlertCard extends StatelessWidget {
  final AlertDetail alert;
  const _AlertCard({required this.alert});

  Color get _statusColor => switch (alert.status) {
        AlertStatus.en_cours => AppColors.danger,
        AlertStatus.traiter  => AppColors.success,
        AlertStatus.rejeter  => AppColors.textMuted,
      };

  Color get _statusBg => switch (alert.status) {
        AlertStatus.en_cours => AppColors.danger.withOpacity(0.07),
        AlertStatus.traiter  => AppColors.successBg,
        AlertStatus.rejeter  => AppColors.bgInput,
      };

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => context.push('/supervisor/alert/${alert.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 0.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(children: [
            // Emoji
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(alert.type.emoji, style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 14),

            // Infos
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(alert.type.label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const Spacer(),
                  // Statut pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(alert.status.label,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _statusColor)),
                  ),
                ]),
                const SizedBox(height: 4),

                // Date
                Text(_formatDate(alert.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),

                // Description courte
                if (alert.description != null && alert.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    alert.description!.length > 60
                        ? '${alert.description!.substring(0, 60)}...'
                        : alert.description!,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],

                // Indicateurs extras
                const SizedBox(height: 6),
                Row(children: [
                  // Position
                  _InfoChip(
                    icon: alert.locationSource == LocationSource.exif
                        ? Icons.gps_fixed
                        : Icons.location_searching,
                    label: alert.locationSource == LocationSource.exif ? 'GPS précis' : 'Approx.',
                    color: alert.locationSource == LocationSource.exif
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  // Image
                  if (alert.imageUrl != null)
                    const _InfoChip(
                      icon:  Icons.image_outlined,
                      label: 'Photo',
                      color: AppColors.info,
                    ),
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
          ]),
        ),
      );

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
        ]),
      );
}


// ══════════════════════════════════════════════════════════════
//  COUNT BADGE
// ══════════════════════════════════════════════════════════════

class _CountBadge extends StatelessWidget {
  final int   count;
  final Color color;
  const _CountBadge({required this.count, this.color = AppColors.textMuted});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$count',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }
}


// ══════════════════════════════════════════════════════════════
//  STATES
// ══════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.notifications_none, size: 56, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text('Aucune alerte', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          SizedBox(height: 4),
          Text('Les alertes de vos forêts apparaîtront ici.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ]),
      );
}

class _ErrorState extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMid,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
      );
}