// frontend/forest_app/lib/features/supervisor/screens/supervisor_historique_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../features/alert/models/alert_map_model.dart';
import '../../../features/alert/providers/alert_map_provider.dart';

// Alias pour le router
class SupervisorAlertHistoryScreen extends SupervisorHistoriqueScreen {
  const SupervisorAlertHistoryScreen({super.key});
}

class SupervisorHistoriqueScreen extends ConsumerStatefulWidget {
  const SupervisorHistoriqueScreen({super.key});

  @override
  ConsumerState<SupervisorHistoriqueScreen> createState() => _State();
}

class _State extends ConsumerState<SupervisorHistoriqueScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _rechercheCtrl = TextEditingController();
  String _recherche = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // ← GUARD
      ref.read(historiqueProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _rechercheCtrl.dispose();
    super.dispose();
  }

  /// Filtre côté client, appliqué par-dessus la liste déjà chargée pour
  /// l'onglet courant — le statut reste filtré côté serveur (onglets), la
  /// recherche affine seulement ce qui est déjà affiché. Un seul champ
  /// cherche à la fois dans le type, la forêt et l'agent : plus simple
  /// pour le superviseur que trois filtres séparés.
  List<AlertDetail> _filtrer(List<AlertDetail> alertes) {
    final q = _recherche.trim().toLowerCase();
    if (q.isEmpty) return alertes;
    return alertes.where((a) {
      final type = a.type.label.toLowerCase();
      final foret = (a.forestName ?? '').toLowerCase();
      final agent = (a.agentNom ?? '').toLowerCase();
      return type.contains(q) || foret.contains(q) || agent.contains(q);
    }).toList();
  }

  void _onTabChanged(int idx) {
    if (!mounted) return; // ← GUARD
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
        backgroundColor:        Colors.white,
        elevation:              0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Historique des alertes',
            style: TextStyle(
                fontSize:   17,
                fontWeight: FontWeight.w700,
                color:      AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh,
                color: AppColors.textMuted, size: 20),
            onPressed: () {
              if (!mounted) return; // ← GUARD
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
              border: Border(
                  bottom: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            child: TabBar(
              controller: _tabs,
              onTap:      _onTabChanged,
              labelStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w400),
              labelColor:           AppColors.primaryDark,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor:       AppColors.primaryDark,
              indicatorWeight:      2.5,
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
                      count: state.alerts
                          .where((a) => a.status == AlertStatus.en_cours)
                          .length,
                      color: AppColors.danger,
                    ),
                  ]),
                ),
                Tab(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Traitées'),
                    const SizedBox(width: 6),
                    _CountBadge(
                      count: state.alerts
                          .where((a) => a.status == AlertStatus.traiter)
                          .length,
                      color: AppColors.success,
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _barreRecherche(),
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primaryMid))
                : state.error != null
                    ? _ErrorState(
                        message: state.error!,
                        onRetry: () {
                          if (!mounted) return; // ← GUARD
                          ref.read(historiqueProvider.notifier).load();
                        },
                      )
                    : Builder(builder: (_) {
                        final filtres = _filtrer(state.alerts);
                        if (filtres.isEmpty) {
                          return _recherche.trim().isEmpty
                              ? const _EmptyState()
                              : const _AucunResultat();
                        }
                        return _AlertList(alerts: filtres);
                      }),
          ),
        ],
      ),
    );
  }

  Widget _barreRecherche() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          controller: _rechercheCtrl,
          onChanged: (v) => setState(() => _recherche = v),
          style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Rechercher par forêt, agent ou type…',
            hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            prefixIcon: const Icon(Icons.search, size: 19, color: AppColors.textMuted),
            suffixIcon: _recherche.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 17, color: AppColors.textMuted),
                    onPressed: () {
                      _rechercheCtrl.clear();
                      setState(() => _recherche = '');
                    },
                  ),
            filled: true,
            fillColor: AppColors.bgInput,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
//  LISTE
// ══════════════════════════════════════════════════════════════

class _AlertList extends StatelessWidget {
  final List<AlertDetail> alerts;
  const _AlertList({required this.alerts});

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding:     const EdgeInsets.all(16),
        itemCount:   alerts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
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

  bool get _urgente =>
      alert.isCritical && alert.status == AlertStatus.en_cours;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => context.push('/supervisor/alert/${alert.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:        _urgente ? const Color(0xFFFFF7F7) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: _urgente
                ? Border.all(color: AppColors.danger.withOpacity(0.45), width: 1.2)
                : Border.all(color: AppColors.border, width: 0.5),
            boxShadow: [
              BoxShadow(
                  color:      Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset:     const Offset(0, 2)),
            ],
          ),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color:        AppColors.danger.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                  child: Text(alert.type.emoji,
                      style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(alert.type.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize:   14,
                              fontWeight: FontWeight.w600,
                              color:      AppColors.textPrimary)),
                    ),
                    if (alert.isCritical) ...[
                      const SizedBox(width: 6),
                      const _InfoChip(
                        icon:  Icons.warning_amber_rounded,
                        label: 'Critique',
                        color: AppColors.danger,
                      ),
                    ],
                    if (alert.source == AlertSource.citoyen) ...[
                      const SizedBox(width: 6),
                      const _InfoChip(
                        icon:  Icons.hiking,
                        label: 'Citoyen',
                        color: AppColors.info,
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color:        _statusBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(alert.status.label,
                          style: TextStyle(
                              fontSize:   10,
                              fontWeight: FontWeight.w600,
                              color:      _statusColor)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(_formatDate(alert.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted)),
                  if (alert.description != null &&
                      alert.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      alert.description!.length > 60
                          ? '${alert.description!.substring(0, 60)}...'
                          : alert.description!,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    _LocationChip(alert: alert),
                    if (alert.agentLat != null && alert.agentLng != null)
                      _InfoChip(
                        icon: Icons.person_pin_circle_outlined,
                        label: 'Agent : ${alert.agentLat!.toStringAsFixed(4)}, '
                            '${alert.agentLng!.toStringAsFixed(4)}',
                        color: AppColors.primaryMid,
                      ),
                    if (alert.imageUrl != null)
                      const _InfoChip(
                        icon:  Icons.image_outlined,
                        label: 'Photo',
                        color: AppColors.info,
                      ),
                    if (alert.supervisorComment != null &&
                        alert.supervisorComment!.isNotEmpty)
                      const _InfoChip(
                        icon:  Icons.comment_outlined,
                        label: 'Commenté',
                        color: AppColors.primaryMid,
                      ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textMuted),
          ]),
        ),
      );

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

/// Précision de la localisation. Pour `forest_only` (ni EXIF ni GPS
/// téléphone n'ont abouti), on affiche le nom de la forêt choisie par le
/// signalant — jamais le mot "approximatif", qui suggérerait à tort une
/// position calculée alors qu'il n'y en a aucune.
class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.alert});
  final AlertDetail alert;

  @override
  Widget build(BuildContext context) => switch (alert.locationSource) {
        LocationSource.exif => const _InfoChip(
            icon: Icons.gps_fixed, label: 'GPS précis', color: AppColors.success),
        LocationSource.agent_gps => const _InfoChip(
            icon: Icons.location_on, label: 'GPS tél.', color: AppColors.info),
        LocationSource.forest_only => _InfoChip(
            icon:  Icons.park_outlined,
            label: alert.forestName ?? 'Forêt non précisée',
            color: AppColors.textMuted,
          ),
      };
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize:   9,
                  fontWeight: FontWeight.w600,
                  color:      color)),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════
//  COUNT BADGE
// ══════════════════════════════════════════════════════════════

class _CountBadge extends StatelessWidget {
  final int   count;
  final Color color;
  const _CountBadge(
      {required this.count, this.color = AppColors.textMuted});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$count',
          style: TextStyle(
              fontSize:   9,
              fontWeight: FontWeight.w700,
              color:      color)),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  ÉTATS VIDE / ERREUR
// ══════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.notifications_none,
              size: 56, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text('Aucune alerte',
              style: TextStyle(
                  fontSize:   15,
                  fontWeight: FontWeight.w600,
                  color:      AppColors.textSecondary)),
          SizedBox(height: 4),
          Text('Les alertes de vos forêts apparaîtront ici.',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textMuted)),
        ]),
      );
}

class _AucunResultat extends StatelessWidget {
  const _AucunResultat();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text('Aucun résultat',
              style: TextStyle(
                  fontSize:   14,
                  fontWeight: FontWeight.w600,
                  color:      AppColors.textSecondary)),
          SizedBox(height: 4),
          Text('Aucune alerte ne correspond à cette recherche.',
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
          const Icon(Icons.error_outline,
              color: AppColors.danger, size: 48),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMid,
              foregroundColor: Colors.white,
              elevation:       0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
      );
}