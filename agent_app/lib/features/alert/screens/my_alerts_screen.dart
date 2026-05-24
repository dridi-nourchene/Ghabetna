// features/alert/screens/my_alerts_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_app/l10n/app_localizations.dart';
import 'package:agent_app/core/theme/app_colors.dart';
import 'package:agent_app/features/alert/models/alert_model.dart';
import 'package:agent_app/features/alert/providers/alert_provider.dart';

class MyAlertsScreen extends ConsumerStatefulWidget {
  const MyAlertsScreen({super.key});

  @override
  ConsumerState<MyAlertsScreen> createState() => _MyAlertsScreenState();
}

class _MyAlertsScreenState extends ConsumerState<MyAlertsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myAlertsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context)!;
    final state = ref.watch(myAlertsProvider);

    return state.isLoading
        ? const Center(
            child: CircularProgressIndicator(
                color: AgentColors.primary, strokeWidth: 2))
        : state.error != null
            ? _ErrorView(
                message: state.error!,
                retryLabel: l10n.myAlertsRetry,
                onRetry: () => ref.read(myAlertsProvider.notifier).load(),
              )
            : state.alerts.isEmpty
                ? _EmptyView(l10n: l10n)
                : RefreshIndicator(
                    color:    AgentColors.primary,
                    onRefresh: () =>
                        ref.read(myAlertsProvider.notifier).load(),
                    child: ListView.builder(
                      padding:     const EdgeInsets.all(16),
                      itemCount:   state.alerts.length,
                      itemBuilder: (_, i) =>
                          _AlertCard(alert: state.alerts[i], l10n: l10n),
                    ),
                  );
  }
}

// ── Alert Card ───────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final AlertModel       alert;
  final AppLocalizations l10n;
  const _AlertCard({required this.alert, required this.l10n});

  Color get _statusColor => switch (alert.status) {
        AlertStatus.en_cours => const Color(0xFFE05C2A),
        AlertStatus.traiter  => const Color(0xFF1D9E75),
        AlertStatus.rejeter  => const Color(0xFF9E9E9E),
      };

  Color get _statusBg => switch (alert.status) {
        AlertStatus.en_cours => const Color(0xFFFFF0EA),
        AlertStatus.traiter  => const Color(0xFFE8F5EE),
        AlertStatus.rejeter  => const Color(0xFFF5F5F5),
      };

  String _statusLabel() => switch (alert.status) {
        AlertStatus.en_cours => l10n.alertStatusEnCours,
        AlertStatus.traiter  => l10n.alertStatusTraiter,
        AlertStatus.rejeter  => l10n.alertStatusRejeter,
      };

  String _typeLabel() => switch (alert.type) {
        AlertType.incendie   => l10n.alertTypeIncendie,
        AlertType.vol        => l10n.alertTypeVol,
        AlertType.inondation => l10n.alertTypeInondation,
        AlertType.glissement => l10n.alertTypeGlissement,
        AlertType.maladie    => l10n.alertTypeMaladie,
        AlertType.autre      => l10n.alertTypeAutre,
      };

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8EDE8), width: 0.5),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (alert.imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14)),
                child: Image.network(
                  alert.imageUrl!,
                  width:     double.infinity,
                  height:    140,
                  fit:       BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 60,
                    color:  const Color(0xFFF5F5F5),
                    child:  const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Color(0xFFBDBDBD)),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(alert.type.emoji,
                        style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(_typeLabel(),
                        style: const TextStyle(
                            fontSize:   15,
                            fontWeight: FontWeight.w600,
                            color:      AgentColors.textPrimary)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:        _statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_statusLabel(),
                          style: TextStyle(
                              fontSize:   11,
                              fontWeight: FontWeight.w600,
                              color:      _statusColor)),
                    ),
                  ]),

                  if (alert.description != null &&
                      alert.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(alert.description!,
                        style: const TextStyle(
                            fontSize: 13,
                            color:    AgentColors.textSecondary),
                        maxLines:  2,
                        overflow:  TextOverflow.ellipsis),
                  ],

                  if (alert.adminComment != null &&
                      alert.adminComment!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:        const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.admin_panel_settings_outlined,
                              size: 14, color: Color(0xFF4B6CB7)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(alert.adminComment!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color:    Color(0xFF4B6CB7))),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  Row(children: [
                    const Icon(Icons.access_time,
                        size: 12, color: AgentColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(alert.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: AgentColors.textMuted),
                    ),
                    const SizedBox(width: 12),
                    if (alert.agentLat != null && alert.agentLng != null) ...[
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: AgentColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${alert.agentLat!.toStringAsFixed(4)}, '
                        '${alert.agentLng!.toStringAsFixed(4)}',
                        style: const TextStyle(
                            fontSize: 11, color: AgentColors.textMuted),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ],
        ),
      );

  String _formatDate(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24)  return '${diff.inHours}h';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Empty View ───────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final AppLocalizations l10n;
  const _EmptyView({required this.l10n});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_outlined,
                size: 64,
                color: AgentColors.textMuted.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(l10n.myAlertsEmpty,
                style: const TextStyle(
                    fontSize:   16,
                    fontWeight: FontWeight.w600,
                    color:      AgentColors.textSecondary)),
            const SizedBox(height: 6),
            Text(l10n.myAlertsEmptySub,
                style: const TextStyle(
                    fontSize: 13, color: AgentColors.textMuted)),
          ],
        ),
      );
}

// ── Error View ───────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String       message;
  final String       retryLabel;
  final VoidCallback onRetry;
  const _ErrorView({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AgentColors.danger),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AgentColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AgentColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(retryLabel),
            ),
          ],
        ),
      );
}