import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:forest_app/core/theme/app_colors.dart';
import 'package:forest_app/features/alert/models/alert_map_model.dart';
import 'package:forest_app/features/alert/providers/alert_map_provider.dart';
import 'package:forest_app/features/forest/providers/forest_provider.dart';

class AdminMapScreen extends ConsumerStatefulWidget {
  const AdminMapScreen({super.key});

  @override
  ConsumerState<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends ConsumerState<AdminMapScreen> {
  final _mapController   = MapController();
  String? _selectedAlertId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Démarrer le polling alertes
      ref.read(alertMapProvider.notifier).startPolling();
      // Charger les forêts pour les polygones
      ref.read(forestListProvider.notifier).loadForests();
    });
  }

  @override
  void dispose() {
    ref.read(alertMapProvider.notifier).stopPolling();
    super.dispose();
  }

  void _onAlertTap(String alertId) {
    setState(() => _selectedAlertId = alertId);
    ref.read(alertDetailProvider.notifier).loadAlert(alertId);
  }

  void _closePopup() {
    setState(() => _selectedAlertId = null);
    ref.read(alertDetailProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final alertState  = ref.watch(alertMapProvider);
    final forestState = ref.watch(forestListProvider);

    return Stack(
      children: [
        // ── Map principale ───────────────────────────────────
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: LatLng(28.0339, 1.6596), // Centre Algérie
            initialZoom:   5.5,
            minZoom:       3,
            maxZoom:       18,
          ),
          children: [
            // Fond de carte
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.ghabetna.forest',
            ),

            // Polygones des forêts (gris clair)
            PolygonLayer(polygons: [
              // TODO: ajouter les polygones forêts depuis forestState
              // when forest GeoJSON is loaded
            ]),

            // Marqueurs alertes — triangles
            MarkerLayer(
              markers: alertState.points.map((point) {
                return Marker(
                  point:  LatLng(point.latitude, point.longitude),
                  width:  40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () => _onAlertTap(point.id),
                    child: _AlertTriangle(
                      type:       point.type,
                      status:     point.status,
                      isSelected: _selectedAlertId == point.id,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // ── Barre d'état polling ─────────────────────────────
        Positioned(
          top: 16, right: 16,
          child: _PollingIndicator(
            alertCount:  alertState.points.length,
            lastRefresh: alertState.lastRefresh,
            isLoading:   alertState.isLoading,
            onRefresh:   () => ref.read(alertMapProvider.notifier).refreshNow(),
          ),
        ),

        // ── Légende ──────────────────────────────────────────
        const Positioned(
          bottom: 24, left: 16,
          child: _Legend(),
        ),

        // ── Popup détail alerte ──────────────────────────────
        if (_selectedAlertId != null)
          Positioned(
            top: 16, left: 16,
            child: _AlertDetailPanel(
              alertId: _selectedAlertId!,
              onClose: _closePopup,
              onStatusUpdated: () {
                // Rafraîchir la map après mise à jour statut
                ref.read(alertMapProvider.notifier).refreshNow();
              },
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  TRIANGLE ALERTE
// ══════════════════════════════════════════════════════════════

class _AlertTriangle extends StatelessWidget {
  final AlertType   type;
  final AlertStatus status;
  final bool        isSelected;

  const _AlertTriangle({
    required this.type,
    required this.status,
    required this.isSelected,
  });

  Color get _color => switch (status) {
        AlertStatus.en_cours => const Color(0xFFE05C2A), // orange-rouge
        AlertStatus.traiter  => const Color(0xFF1D9E75), // vert
        AlertStatus.rejeter  => Colors.grey,             // ne devrait pas apparaître
      };

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: CustomPaint(
          size: Size(isSelected ? 40 : 32, isSelected ? 40 : 32),
          painter: _TrianglePainter(
            color:      _color,
            isSelected: isSelected,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                type.emoji,
                style: TextStyle(fontSize: isSelected ? 14 : 11),
              ),
            ),
          ),
        ),
      );
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  final bool  isSelected;

  _TrianglePainter({required this.color, required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color   = color
      ..style   = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color      = Colors.black.withOpacity(0.2)
      ..style      = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    // Ombre
    canvas.drawPath(path.shift(const Offset(1, 2)), shadowPaint);
    // Triangle
    canvas.drawPath(path, paint);

    // Bordure si sélectionné
    if (isSelected) {
      final borderPaint = Paint()
        ..color       = Colors.white
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawPath(path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(_TrianglePainter old) =>
      old.color != color || old.isSelected != isSelected;
}

// ══════════════════════════════════════════════════════════════
//  POLLING INDICATOR
// ══════════════════════════════════════════════════════════════

class _PollingIndicator extends StatelessWidget {
  final int       alertCount;
  final DateTime? lastRefresh;
  final bool      isLoading;
  final VoidCallback onRefresh;

  const _PollingIndicator({
    required this.alertCount,
    required this.lastRefresh,
    required this.isLoading,
    required this.onRefresh,
  });

  String get _lastRefreshText {
    if (lastRefresh == null) return 'Chargement...';
    final diff = DateTime.now().difference(lastRefresh!);
    if (diff.inSeconds < 60) return 'Actualisé il y a ${diff.inSeconds}s';
    return 'Actualisé il y a ${diff.inMinutes}min';
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          // Indicateur actif
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: isLoading
                  ? AppColors.warning
                  : AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$alertCount alerte${alertCount != 1 ? 's' : ''} actives',
                style: const TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.w600,
                    color:      AppColors.textPrimary),
              ),
              Text(
                _lastRefreshText,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onRefresh,
            child: isLoading
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primaryMid))
                : const Icon(Icons.refresh,
                    size: 16, color: AppColors.textMuted),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════
//  LÉGENDE
// ══════════════════════════════════════════════════════════════

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:        Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.08),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Légende',
                style: TextStyle(
                    fontSize:   11,
                    fontWeight: FontWeight.w600,
                    color:      AppColors.textSecondary)),
            const SizedBox(height: 8),
            _LegendItem(color: const Color(0xFFE05C2A), label: 'En cours'),
            const SizedBox(height: 4),
            _LegendItem(color: const Color(0xFF1D9E75), label: 'Traitée'),
          ],
        ),
      );
}

class _LegendItem extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: const Size(16, 16),
            painter: _TrianglePainter(color: color, isSelected: false),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textPrimary)),
        ],
      );
}

// ══════════════════════════════════════════════════════════════
//  POPUP DÉTAIL ALERTE
// ══════════════════════════════════════════════════════════════

class _AlertDetailPanel extends ConsumerStatefulWidget {
  final String   alertId;
  final VoidCallback onClose;
  final VoidCallback onStatusUpdated;

  const _AlertDetailPanel({
    required this.alertId,
    required this.onClose,
    required this.onStatusUpdated,
  });

  @override
  ConsumerState<_AlertDetailPanel> createState() => _AlertDetailPanelState();
}

class _AlertDetailPanelState extends ConsumerState<_AlertDetailPanel> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String status) async {
    final ok = await ref.read(alertDetailProvider.notifier).updateStatus(
          alertId: widget.alertId,
          status:  status,
          comment: _commentController.text.trim().isEmpty
              ? null
              : _commentController.text.trim(),
        );

    if (ok) {
      widget.onStatusUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         const Text('Statut mis à jour'),
          backgroundColor: AppColors.success,
          behavior:        SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(alertDetailProvider);

    return Container(
      width:  300,
      constraints: const BoxConstraints(maxHeight: 520),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset:     const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Header ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: Color(0xFFE8EDE8), width: 0.5)),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 16, color: AppColors.primaryMid),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Détail de l\'alerte',
                    style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color:      AppColors.textPrimary)),
              ),
              GestureDetector(
                onTap: widget.onClose,
                child: const Icon(Icons.close,
                    size: 16, color: AppColors.textMuted),
              ),
            ]),
          ),

          // ── Contenu ───────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: state.isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                            color: AppColors.primaryMid, strokeWidth: 2),
                      ),
                    )
                  : state.alert == null
                      ? const Text('Erreur chargement',
                          style: TextStyle(color: AppColors.textMuted))
                      : _AlertDetailContent(
                          alert:              state.alert!,
                          commentController:  _commentController,
                          isUpdating:         state.isUpdating,
                          onUpdate:           _updateStatus,
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertDetailContent extends StatelessWidget {
  final AlertDetail         alert;
  final TextEditingController commentController;
  final bool                isUpdating;
  final void Function(String) onUpdate;

  const _AlertDetailContent({
    required this.alert,
    required this.commentController,
    required this.isUpdating,
    required this.onUpdate,
  });

  Color get _statusColor => switch (alert.status) {
        AlertStatus.en_cours => const Color(0xFFE05C2A),
        AlertStatus.traiter  => const Color(0xFF1D9E75),
        AlertStatus.rejeter  => Colors.grey,
      };

  Color get _statusBg => switch (alert.status) {
        AlertStatus.en_cours => const Color(0xFFFFF0EA),
        AlertStatus.traiter  => const Color(0xFFE8F5EE),
        AlertStatus.rejeter  => const Color(0xFFF5F5F5),
      };

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Type + statut
          Row(children: [
            Text(alert.type.emoji,
                style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(alert.type.label,
                style: const TextStyle(
                    fontSize:   14,
                    fontWeight: FontWeight.w600,
                    color:      AppColors.textPrimary)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:        _statusBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(alert.status.label,
                  style: TextStyle(
                      fontSize:   10,
                      fontWeight: FontWeight.w600,
                      color:      _statusColor)),
            ),
          ]),

          // Image
          if (alert.imageUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                alert.imageUrl!,
                width:  double.infinity,
                height: 140,
                fit:    BoxFit.cover,
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
          ],

          // Description
          if (alert.description != null &&
              alert.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _Label('Description'),
            const SizedBox(height: 4),
            Text(alert.description!,
                style: const TextStyle(
                    fontSize: 12,
                    color:    AppColors.textSecondary,
                    height:   1.4)),
          ],

          // Coordonnées
          const SizedBox(height: 12),
          const _Label('Localisation'),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.location_on_outlined,
                size: 12, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              '${alert.latitude.toStringAsFixed(5)}, '
              '${alert.longitude.toStringAsFixed(5)}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textMuted),
            ),
          ]),

          // Date
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.access_time,
                size: 12, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              _formatDate(alert.createdAt),
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textMuted),
            ),
          ]),

          // Commentaire admin existant
          if (alert.adminComment != null &&
              alert.adminComment!.isNotEmpty) ...[
            const SizedBox(height: 12),
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
                      size: 13, color: Color(0xFF4B6CB7)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(alert.adminComment!,
                        style: const TextStyle(
                            fontSize: 11,
                            color:    Color(0xFF4B6CB7))),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE8EDE8)),
          const SizedBox(height: 14),

          // ── Actions admin ──────────────────────────────────
          if (alert.status == AlertStatus.en_cours) ...[
            const _Label('Commentaire (optionnel)'),
            const SizedBox(height: 6),
            TextField(
              controller: commentController,
              maxLines:   2,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText:  'Ajouter un commentaire...',
                hintStyle: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted),
                filled:    true,
                fillColor: const Color(0xFFF5F7F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:   const BorderSide(
                      color: Color(0xFFE8EDE8), width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:   const BorderSide(
                      color: Color(0xFFE8EDE8), width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: AppColors.primaryMid, width: 1),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _ActionButton(
                  label:     'Traiter',
                  color:     AppColors.success,
                  icon:      Icons.check_circle_outline,
                  isLoading: isUpdating,
                  onTap:     () => onUpdate('traiter'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label:     'Rejeter',
                  color:     const Color(0xFF9E9E9E),
                  icon:      Icons.cancel_outlined,
                  isLoading: isUpdating,
                  onTap:     () => onUpdate('rejeter'),
                ),
              ),
            ]),
          ] else ...[
            // Alerte déjà traitée/rejetée
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color:        _statusBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(
                  alert.status == AlertStatus.traiter
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  size:  14,
                  color: _statusColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Alerte ${alert.status.label.toLowerCase()}',
                  style: TextStyle(
                      fontSize:   12,
                      fontWeight: FontWeight.w500,
                      color:      _statusColor),
                ),
              ]),
            ),
          ],
        ],
      );

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year} ${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize:   10,
          fontWeight: FontWeight.w600,
          color:      AppColors.textSecondary,
          letterSpacing: 0.3));
}

class _ActionButton extends StatelessWidget {
  final String     label;
  final Color      color;
  final IconData   icon;
  final bool       isLoading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
        onPressed: isLoading ? null : onTap,
        icon: isLoading
            ? const SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Icon(icon, size: 14),
        label: Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor:         color,
          foregroundColor:         Colors.white,
          disabledBackgroundColor: color.withOpacity(0.4),
          elevation:               0,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      );
}