// features/admin/screens/admin_map_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:forest_app/core/theme/app_colors.dart';
import 'package:forest_app/features/alert/models/alert_map_model.dart';
import 'package:forest_app/features/alert/providers/alert_map_provider.dart';
import 'package:forest_app/features/forest/models/forest_model.dart';
import 'package:forest_app/features/forest/providers/forest_provider.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;

class AdminMapScreen extends ConsumerStatefulWidget {
  const AdminMapScreen({super.key});

  @override
  ConsumerState<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends ConsumerState<AdminMapScreen> {
  final _mapController  = MapController();
  String? _selectedAlertId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(alertMapProvider.notifier).startPolling();
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

  // ── Résoudre la position de l'icône ──────────────────────
  // Si EXIF disponible → coordonnées précises
  // Sinon → centroïde de la forêt (déjà chargé)
  LatLng? _resolvePosition(
    AlertMapPoint point,
    List<Forest> forests,
  ) {
    // 1. EXIF présent → position précise
    if (point.hasExactLocation) {
      return LatLng(point.incidentLat!, point.incidentLng!);
    }

    // 2. Pas d'EXIF → chercher le centroïde de la forêt
    try {
      final forest = forests.firstWhere((f) => f.id == point.forestId);
      if (forest.centroidLat != null && forest.centroidLng != null) {
        return LatLng(forest.centroidLat!, forest.centroidLng!);
      }
    } catch (_) {
      // Forêt pas encore chargée
    }

    return null; // Pas encore de position disponible
  }

  @override
  Widget build(BuildContext context) {
    final alertState  = ref.watch(alertMapProvider);
    final forestState = ref.watch(forestListProvider);
    final forests     = forestState.forests;

    // Construire les polygones forêts
    final forestPolygons = forests.map((f) {
      final pts = f.geojson.latLngList
          .map((p) => LatLng(p[0], p[1]))
          .toList();
      if (pts.isEmpty) return null;
      return Polygon(
        points:            pts,
        color:             const Color(0x222E7D32),
        borderColor:       const Color(0xFF2E7D32),
        borderStrokeWidth: 1.2,
        isFilled:          true,
      );
    }).whereType<Polygon>().toList();

    // Construire les marqueurs alertes
    final alertMarkers = <Marker>[];
    for (final point in alertState.points) {
      final position = _resolvePosition(point, forests);
      if (position == null) continue; // Forêt pas encore chargée

      alertMarkers.add(Marker(
        point:  position,
        width:  40,
        height: 44,
        child: GestureDetector(
          onTap: () => _onAlertTap(point.id),
          child: _AlertTriangle(
            type:            point.type,
            status:          point.status,
            isSelected:      _selectedAlertId == point.id,
            isApproximate:   !point.hasExactLocation,
          ),
        ),
      ));
    }

    return Stack(
      children: [
        // ── Carte ────────────────────────────────────────────
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: LatLng(33.8869, 9.5375), // Centre Tunisie
            initialZoom:   7.0,
            minZoom:       4,
            maxZoom:       18,
          ),
          children: [
            TileLayer(
              urlTemplate:          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.ghabetna.forest_app',
            ),
            // Polygones forêts (fond vert clair)
            if (forestPolygons.isNotEmpty)
              PolygonLayer(polygons: forestPolygons),
            // Marqueurs alertes
            MarkerLayer(markers: alertMarkers),
          ],
        ),

        // ── Indicateur polling ────────────────────────────────
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

        // ── Popup détail alerte ───────────────────────────────
        if (_selectedAlertId != null)
          Positioned(
            top: 16, left: 16,
            child: _AlertDetailPanel(
              alertId:         _selectedAlertId!,
              onClose:         _closePopup,
              onStatusUpdated: () {
                ref.read(alertMapProvider.notifier).refreshNow();
              },
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  TRIANGLE ALERTE — toujours rouge, taille selon sélection
//  isApproximate → petite pastille "~" pour indiquer position approx
// ══════════════════════════════════════════════════════════════

class _AlertTriangle extends StatelessWidget {
  final AlertType   type;
  final AlertStatus status;
  final bool        isSelected;
  final bool        isApproximate; // position = centroïde forêt

  const _AlertTriangle({
    required this.type,
    required this.status,
    required this.isSelected,
    required this.isApproximate,
  });

  // Toujours rouge — nuance selon statut
  Color get _color => switch (status) {
        AlertStatus.en_cours => const Color(0xFFD32F2F), // rouge vif
        AlertStatus.traiter  => const Color(0xFF388E3C), // vert traité
        AlertStatus.rejeter  => const Color(0xFF9E9E9E), // gris rejeté
      };

  @override
  Widget build(BuildContext context) {
    final size = isSelected ? 42.0 : 32.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          size: Size(size, size),
          painter: _TrianglePainter(
            color:      _color,
            isSelected: isSelected,
          ),
          child: SizedBox(
            width:  size,
            height: size,
            child: Align(
              alignment: const Alignment(0, -0.1),
              child: Text(
                type.emoji,
                style: TextStyle(fontSize: isSelected ? 14 : 11),
              ),
            ),
          ),
        ),
        // Pastille "~" si position approximative
        if (isApproximate)
          Positioned(
            top:   -4,
            right: -4,
            child: Container(
              width:  14, height: 14,
              decoration: BoxDecoration(
                color:  const Color(0xFFFF8F00),
                shape:  BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Center(
                child: Text('~',
                    style: TextStyle(
                        fontSize:   8,
                        color:      Colors.white,
                        fontWeight: FontWeight.w700,
                        height:     1)),
              ),
            ),
          ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  final bool  isSelected;

  _TrianglePainter({required this.color, required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color      = Colors.black.withOpacity(0.25)
      ..style      = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = ui.Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    // Ombre décalée
    canvas.drawPath(path.shift(const Offset(1.5, 2.5)), shadowPaint);
    // Triangle plein
    canvas.drawPath(path, fillPaint);

    // Bordure blanche si sélectionné
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
  final int          alertCount;
  final DateTime?    lastRefresh;
  final bool         isLoading;
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
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: isLoading ? AppColors.warning : AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$alertCount alerte${alertCount != 1 ? 's' : ''} active${alertCount != 1 ? 's' : ''}',
                style: const TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.w600,
                    color:      AppColors.textPrimary),
              ),
              Text(_lastRefreshText,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textMuted)),
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
            _LegendRow(
              color: const Color(0xFFD32F2F),
              label: 'En cours',
            ),
            const SizedBox(height: 4),
            _LegendRow(
              color: const Color(0xFF388E3C),
              label: 'Traitée',
            ),
            const SizedBox(height: 6),
            // Explication pastille ~
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 14, height: 14,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF8F00),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('~',
                      style: TextStyle(
                          fontSize: 8,
                          color:    Colors.white,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 6),
              const Text('Position approx.',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textMuted)),
            ]),
          ],
        ),
      );
}

class _LegendRow extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendRow({required this.color, required this.label});

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
  final String       alertId;
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
    if (ok && mounted) {
      widget.onStatusUpdated();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         const Text('Statut mis à jour'),
        backgroundColor: AppColors.success,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(alertDetailProvider);

    return Container(
      width:       320,
      constraints: const BoxConstraints(maxHeight: 560),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.15),
            blurRadius: 24,
            offset:     const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    size: 15, color: AppColors.danger),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Détail de l\'alerte',
                    style: TextStyle(
                        fontSize:   14,
                        fontWeight: FontWeight.w600,
                        color:      AppColors.textPrimary)),
              ),
              GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.close,
                      size: 14, color: AppColors.textMuted),
                ),
              ),
            ]),
          ),

          // ── Contenu scrollable ───────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: state.isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: CircularProgressIndicator(
                            color: AppColors.primaryMid, strokeWidth: 2),
                      ),
                    )
                  : state.error != null
                      ? _ErrorState(message: state.error!)
                      : state.alert == null
                          ? const SizedBox.shrink()
                          : _AlertContent(
                              alert:             state.alert!,
                              commentController: _commentController,
                              isUpdating:        state.isUpdating,
                              onUpdate:          _updateStatus,
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contenu détail ─────────────────────────────────────────────

class _AlertContent extends StatelessWidget {
  final AlertDetail             alert;
  final TextEditingController   commentController;
  final bool                    isUpdating;
  final void Function(String)   onUpdate;

  const _AlertContent({
    required this.alert,
    required this.commentController,
    required this.isUpdating,
    required this.onUpdate,
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
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Type + statut ────────────────────────────────
          Row(children: [
            Text(alert.type.emoji,
                style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.type.label,
                      style: const TextStyle(
                          fontSize:   15,
                          fontWeight: FontWeight.w700,
                          color:      AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(alert.createdAt),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
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

          // ── Image ────────────────────────────────────────
          if (alert.imageUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                alert.imageUrl!,
                width:  double.infinity,
                height: 150,
                fit:    BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 50,
                  color:  AppColors.bgInput,
                  child:  const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
          ],

          // ── Description ──────────────────────────────────
          if (alert.description != null &&
              alert.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _Label('Description'),
            const SizedBox(height: 4),
            Text(alert.description!,
                style: const TextStyle(
                    fontSize: 12,
                    color:    AppColors.textSecondary,
                    height:   1.5)),
          ],

          const SizedBox(height: 12),
          Container(height: 0.5, color: AppColors.borderLight),
          const SizedBox(height: 12),

          // ── Localisation ─────────────────────────────────
          const _Label('Localisation'),
          const SizedBox(height: 6),

          // Source
          _InfoRow(
            icon:  Icons.location_on_outlined,
            color: alert.locationSource == LocationSource.exif
                ? AppColors.success
                : AppColors.warning,
            text: switch (alert.locationSource) {
              LocationSource.exif        => 'GPS photo (précis)',
              LocationSource.agent_gps   => 'GPS téléphone',
              LocationSource.forest_only => 'Position approx. (centroïde forêt)',
            },
          ),

          // Coordonnées incident si disponibles
          if (alert.incidentLat != null) ...[
            const SizedBox(height: 4),
            _InfoRow(
              icon:  Icons.my_location,
              color: AppColors.primaryMid,
              text:  'Incident : ${alert.incidentLat!.toStringAsFixed(5)}, '
                     '${alert.incidentLng!.toStringAsFixed(5)}',
            ),
          ],

          // Position agent si disponible
          if (alert.agentLat != null) ...[
            const SizedBox(height: 4),
            _InfoRow(
              icon:  Icons.person_pin_circle_outlined,
              color: AppColors.info,
              text:  'Agent : ${alert.agentLat!.toStringAsFixed(5)}, '
                     '${alert.agentLng!.toStringAsFixed(5)}',
            ),
          ],

          // Distance agent ↔ incident si les deux sont disponibles
          if (alert.distanceKm != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:        alert.distanceKm! > 5
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
                  size:  13,
                  color: alert.distanceKm! > 5
                      ? AppColors.danger
                      : AppColors.success,
                ),
                const SizedBox(width: 6),
                Text(
                  'Distance agent–incident : '
                  '${alert.distanceKm!.toStringAsFixed(1)} km'
                  '${alert.distanceKm! > 5 ? ' ⚠️ Suspect' : ''}',
                  style: TextStyle(
                      fontSize: 11,
                      color:    alert.distanceKm! > 5
                          ? AppColors.danger
                          : AppColors.success,
                      fontWeight: FontWeight.w500),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 12),
          Container(height: 0.5, color: AppColors.borderLight),
          const SizedBox(height: 12),

          // ── Commentaire admin existant ────────────────────
          if (alert.adminComment != null &&
              alert.adminComment!.isNotEmpty) ...[
            const _Label('Commentaire admin'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        AppColors.infoBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.info.withOpacity(0.3), width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.admin_panel_settings_outlined,
                      size: 13, color: AppColors.info),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(alert.adminComment!,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.info)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(height: 0.5, color: AppColors.borderLight),
            const SizedBox(height: 12),
          ],

          // ── Actions admin ─────────────────────────────────
          if (alert.status == AlertStatus.en_cours) ...[
            const _Label('Décision'),
            const SizedBox(height: 8),

            // Champ commentaire
            TextField(
              controller: commentController,
              maxLines:   2,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText:  'Commentaire (optionnel)...',
                hintStyle: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted),
                filled:    true,
                fillColor: AppColors.bgInput,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:   const BorderSide(
                      color: AppColors.border, width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:   const BorderSide(
                      color: AppColors.border, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:   const BorderSide(
                      color: AppColors.primaryMid, width: 1.2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                isDense: true,
              ),
            ),

            const SizedBox(height: 10),

            Row(children: [
              Expanded(
                child: _ActionBtn(
                  label:     'Traiter',
                  icon:      Icons.check_circle_outline,
                  color:     AppColors.success,
                  isLoading: isUpdating,
                  onTap:     () => onUpdate('traiter'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionBtn(
                  label:     'Rejeter',
                  icon:      Icons.cancel_outlined,
                  color:     AppColors.textMuted,
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
                border: Border.all(
                    color: _statusColor.withOpacity(0.3), width: 0.5),
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
      '${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

// ── Widgets utilitaires ────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize:      10,
          fontWeight:    FontWeight.w600,
          color:         AppColors.textSecondary,
          letterSpacing: 0.3));
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   text;
  const _InfoRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ),
      ]);
}

class _ActionBtn extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final bool         isLoading;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
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

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.danger, size: 32),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      );
}