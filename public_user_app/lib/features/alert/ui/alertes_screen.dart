import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../data/alert_models.dart';
import '../providers/alert_provider.dart';

/// Historique des signalements du citoyen — GET /api/alerts/mine.
///
/// C'est l'onglet « Alertes » de la barre basse : le Scaffold et la barre
/// viennent de la coquille du routeur, cet écran ne porte que la liste.
class AlertesScreen extends ConsumerStatefulWidget {
  const AlertesScreen({super.key});

  @override
  ConsumerState<AlertesScreen> createState() => _AlertesScreenState();
}

class _AlertesScreenState extends ConsumerState<AlertesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mesAlertesProvider.notifier).charger();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mesAlertesProvider);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Text(
                  'Vos signalements',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () =>
                      ref.read(mesAlertesProvider.notifier).charger(),
                  icon: const Icon(Icons.refresh, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Expanded(child: _corps(state)),
        ],
      ),
    );
  }

  Widget _corps(MesAlertesState state) {
    if (state.chargement && state.alertes.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.authVert),
      );
    }

    if (state.erreur != null && state.alertes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            state.erreur!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    if (state.alertes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: const BoxDecoration(
                  color: AppColors.authVertFond,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_none_rounded,
                    size: 27, color: AppColors.authVert),
              ),
              const SizedBox(height: 18),
              const Text(
                'Aucun signalement pour l\'instant',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Les alertes que vous envoyez apparaîtront ici, '
                'avec leur statut de traitement.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, height: 1.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 22),
              TextButton.icon(
                onPressed: () => context.go('/signaler'),
                icon: const Icon(Icons.add, color: AppColors.authVert),
                label: const Text('Signaler une alerte',
                    style: TextStyle(color: AppColors.authVert)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.authVert,
      onRefresh: () => ref.read(mesAlertesProvider.notifier).charger(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        itemCount: state.alertes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _Carte(alerte: state.alertes[i]),
      ),
    );
  }
}

class _Carte extends StatelessWidget {
  const _Carte({required this.alerte});
  final AlertModel alerte;

  Color _couleurStatut(AlertStatus s) => switch (s) {
        AlertStatus.en_cours => const Color(0xFF9C6E00),
        AlertStatus.traiter => AppColors.authVert,
        AlertStatus.rejeter => AppColors.errorText,
      };

  Color _fondStatut(AlertStatus s) => switch (s) {
        AlertStatus.en_cours => const Color(0xFFFFF8E6),
        AlertStatus.traiter => AppColors.authVertFond,
        AlertStatus.rejeter => AppColors.errorBg,
      };

  String _date(DateTime d) {
    final jours = d.difference(DateTime.now()).inDays.abs();
    if (jours == 0) return 'Aujourd\'hui';
    if (jours == 1) return 'Hier';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppDims.card),
        border: Border.all(color: AppColors.border, width: 0.6),
        boxShadow: AppShadows.champ,
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.authVertFond,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(alerte.type.emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alerte.type.libelle,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _fondStatut(alerte.status),
                        borderRadius: BorderRadius.circular(AppDims.info),
                      ),
                      child: Text(
                        alerte.status.libelle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _couleurStatut(alerte.status),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  alerte.forestName ?? '—',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                if (alerte.description != null && alerte.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    alerte.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                  ),
                ],
                if (alerte.status == AlertStatus.rejeter &&
                    (alerte.supervisorComment?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Motif : ${alerte.supervisorComment}',
                    style: const TextStyle(
                        fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.errorText),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  _date(alerte.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
