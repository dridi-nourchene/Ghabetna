import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../features/alert/models/alert_map_model.dart';
import '../../../features/alert/providers/alert_map_provider.dart';

class SupervisorAlertDetailScreen extends ConsumerStatefulWidget {
  final String alertId;

  const SupervisorAlertDetailScreen({super.key, required this.alertId});

  @override
  ConsumerState<SupervisorAlertDetailScreen> createState() =>
      _SupervisorAlertDetailScreenState();
}

class _SupervisorAlertDetailScreenState
    extends ConsumerState<SupervisorAlertDetailScreen> {
  final _commentController = TextEditingController();
  bool _commentExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(alertDetailProvider.notifier).loadAlert(widget.alertId);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdateStatus(String status) async {
    final comment = _commentController.text.trim();
    final ok = await ref.read(alertDetailProvider.notifier).updateStatus(
          alertId: widget.alertId,
          status:  status,
          comment: comment.isNotEmpty ? comment : null,
        );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'traiter'
              ? '✅ Alerte marquée comme traitée'
              : '❌ Alerte rejetée'),
          backgroundColor:
              status == 'traiter' ? AppColors.success : AppColors.textMuted,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      // Refresh historique si on revient en arrière
      ref.read(historiqueProvider.notifier).load();
      ref.read(alertMapProvider.notifier).refreshNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(alertDetailProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Détail de l\'alerte',
          style: TextStyle(
              fontSize:   17,
              fontWeight: FontWeight.w700,
              color:      AppColors.textPrimary),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: AppColors.border),
        ),
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryMid))
          : state.error != null
              ? _ErrorView(
                  message: state.error!,
                  onRetry: () => ref
                      .read(alertDetailProvider.notifier)
                      .loadAlert(widget.alertId),
                )
              : state.alert == null
                  ? const SizedBox.shrink()
                  : _AlertContent(
                      alert:             state.alert!,
                      isUpdating:        state.isUpdating,
                      commentController: _commentController,
                      commentExpanded:   _commentExpanded,
                      onToggleComment:   () => setState(
                          () => _commentExpanded = !_commentExpanded),
                      onUpdateStatus:    _handleUpdateStatus,
                    ),
    );
  }
}

// ── Main content ──────────────────────────────────────────────

class _AlertContent extends StatelessWidget {
  final AlertDetail           alert;
  final bool                  isUpdating;
  final TextEditingController commentController;
  final bool                  commentExpanded;
  final VoidCallback          onToggleComment;
  final void Function(String) onUpdateStatus;

  const _AlertContent({
    required this.alert,
    required this.isUpdating,
    required this.commentController,
    required this.commentExpanded,
    required this.onToggleComment,
    required this.onUpdateStatus,
  });

  Color get _statusColor => switch (alert.status) {
        AlertStatus.en_cours => AppColors.danger,
        AlertStatus.traiter  => AppColors.success,
        AlertStatus.rejeter  => AppColors.textMuted,
      };

  Color get _statusBg => switch (alert.status) {
        AlertStatus.en_cours => AppColors.danger.withOpacity(0.08),
        AlertStatus.traiter  => AppColors.successBg,
        AlertStatus.rejeter  => AppColors.bgInput,
      };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header card ─────────────────────────────────
          _SectionCard(
            child: Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color:        AppColors.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(alert.type.emoji,
                      style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert.type.label,
                        style: const TextStyle(
                            fontSize:   18,
                            fontWeight: FontWeight.w700,
                            color:      AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(_formatDate(alert.createdAt),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color:        _statusBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _statusColor.withOpacity(0.3), width: 0.5),
                ),
                child: Text(alert.status.label,
                    style: TextStyle(
                        fontSize:   12,
                        fontWeight: FontWeight.w600,
                        color:      _statusColor)),
              ),
            ]),
          ),

          const SizedBox(height: 12),

          // ── Image ────────────────────────────────────────
          if (alert.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                alert.imageUrl!,
                width:  double.infinity,
                height: 220,
                fit:    BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color:        AppColors.bgInput,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: AppColors.textMuted, size: 32),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Description ──────────────────────────────────
          if (alert.description != null && alert.description!.isNotEmpty) ...[
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('Description'),
                  const SizedBox(height: 8),
                  Text(alert.description!,
                      style: const TextStyle(
                          fontSize: 14,
                          color:    AppColors.textSecondary,
                          height:   1.5)),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Localisation ─────────────────────────────────
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Label('Localisation'),
                const SizedBox(height: 10),
                _LocationRow(
                  icon:  alert.locationSource == LocationSource.exif
                      ? Icons.gps_fixed
                      : Icons.location_searching,
                  color: alert.locationSource == LocationSource.exif
                      ? AppColors.success
                      : AppColors.warning,
                  label: switch (alert.locationSource) {
                    LocationSource.exif        => 'GPS photo (précis)',
                    LocationSource.agent_gps   => 'GPS téléphone',
                    LocationSource.forest_only => 'Position approximative (centroïde forêt)',
                  },
                ),
                if (alert.incidentLat != null) ...[
                  const SizedBox(height: 6),
                  _LocationRow(
                    icon:  Icons.my_location,
                    color: AppColors.primaryMid,
                    label: 'Incident : ${alert.incidentLat!.toStringAsFixed(5)}, '
                           '${alert.incidentLng!.toStringAsFixed(5)}',
                  ),
                ],
                if (alert.agentLat != null) ...[
                  const SizedBox(height: 6),
                  _LocationRow(
                    icon:  Icons.person_pin_circle_outlined,
                    color: AppColors.info,
                    label: 'Agent : ${alert.agentLat!.toStringAsFixed(5)}, '
                           '${alert.agentLng!.toStringAsFixed(5)}',
                  ),
                ],
                if (alert.distanceKm != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: alert.distanceKm! > 5
                          ? AppColors.danger.withOpacity(0.08)
                          : AppColors.successBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: alert.distanceKm! > 5
                            ? AppColors.danger.withOpacity(0.3)
                            : AppColors.success.withOpacity(0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                        alert.distanceKm! > 5
                            ? Icons.warning_outlined
                            : Icons.check_circle_outline,
                        size:  14,
                        color: alert.distanceKm! > 5
                            ? AppColors.danger
                            : AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Distance agent ↔ incident : '
                        '${alert.distanceKm!.toStringAsFixed(1)} km'
                        '${alert.distanceKm! > 5 ? '  ⚠️ Suspect' : ''}',
                        style: TextStyle(
                            fontSize:   12,
                            fontWeight: FontWeight.w500,
                            color:      alert.distanceKm! > 5
                                ? AppColors.danger
                                : AppColors.success),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Commentaire superviseur existant ──────────────
          if (alert.supervisorComment != null &&
              alert.supervisorComment!.isNotEmpty) ...[
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('Commentaire superviseur'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:        AppColors.infoBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.info.withOpacity(0.3),
                          width: 0.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.supervisor_account_outlined,
                            size: 14, color: AppColors.info),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(alert.supervisorComment!,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.info,
                                  height: 1.4)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Actions (seulement si en_cours) ──────────────
          if (alert.status == AlertStatus.en_cours) ...[
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('Actions'),
                  const SizedBox(height: 12),

                  // ── Toggle commentaire ────────────────────
                  GestureDetector(
                    onTap: onToggleComment,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color:        AppColors.bgInput,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.border, width: 0.5),
                      ),
                      child: Row(children: [
                        const Icon(Icons.comment_outlined,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            commentExpanded
                                ? 'Masquer le commentaire'
                                : 'Ajouter un commentaire (optionnel)',
                            style: const TextStyle(
                                fontSize: 13,
                                color:    AppColors.textSecondary),
                          ),
                        ),
                        Icon(
                          commentExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size:  18,
                          color: AppColors.textMuted,
                        ),
                      ]),
                    ),
                  ),

                  // ── Champ commentaire ─────────────────────
                  if (commentExpanded) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller:  commentController,
                      maxLines:    3,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Votre commentaire...',
                        hintStyle: const TextStyle(
                            fontSize: 13, color: AppColors.textMuted),
                        filled:    true,
                        fillColor: AppColors.bgInput,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: AppColors.border, width: 0.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: AppColors.border, width: 0.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: AppColors.primaryMid, width: 1.2),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // ── Boutons Traiter / Rejeter ─────────────
                  Row(children: [
                    Expanded(
                      child: _ActionButton(
                        label:      'Traiter',
                        icon:       Icons.check_circle_outline,
                        color:      AppColors.success,
                        bg:         AppColors.successBg,
                        isLoading:  isUpdating,
                        onPressed:  () => onUpdateStatus('traiter'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        label:      'Rejeter',
                        icon:       Icons.cancel_outlined,
                        color:      AppColors.danger,
                        bg:         AppColors.danger.withOpacity(0.08),
                        isLoading:  isUpdating,
                        onPressed:  () => _confirmReject(context),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Statut final si déjà traité ───────────────────
          if (alert.status != AlertStatus.en_cours) ...[
            _SectionCard(
              child: Row(children: [
                Icon(
                  alert.status == AlertStatus.traiter
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  size:  18,
                  color: _statusColor,
                ),
                const SizedBox(width: 10),
                Text(
                  'Alerte ${alert.status.label.toLowerCase()} — aucune action possible',
                  style: TextStyle(
                      fontSize:   13,
                      color:      _statusColor,
                      fontWeight: FontWeight.w500),
                ),
              ]),
            ),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _confirmReject(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rejeter l\'alerte',
            style: TextStyle(
                fontSize:   17,
                fontWeight: FontWeight.w700,
                color:      AppColors.textPrimary)),
        content: const Text(
          'Voulez-vous vraiment rejeter cette alerte ?',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onUpdateStatus('rejeter');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation:       0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

// ── Section card ──────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width:   double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize:      11,
          fontWeight:    FontWeight.w600,
          color:         AppColors.textSecondary,
          letterSpacing: 0.3));
}

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  const _LocationRow(
      {required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ),
      ]);
}

class _ActionButton extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final Color        bg;
  final bool         isLoading;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? SizedBox(
                width:  14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: color))
            : Icon(icon, size: 16, color: color),
        label: Text(label,
            style: TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w600,
                color:      color)),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          elevation:       0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: color.withOpacity(0.3), width: 0.5),
          ),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.danger, size: 48),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
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
          ],
        ),
      );
}