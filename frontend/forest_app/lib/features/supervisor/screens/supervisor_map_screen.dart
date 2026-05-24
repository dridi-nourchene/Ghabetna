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

class SupervisorMapScreen extends ConsumerStatefulWidget {
  const SupervisorMapScreen({super.key});

  @override
  ConsumerState<SupervisorMapScreen> createState() =>
      _SupervisorMapScreenState();
}

class _SupervisorMapScreenState extends ConsumerState<SupervisorMapScreen> {
  final _mapController = MapController();
  String? _selectedAlertId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(alertMapProvider.notifier).startPolling();
      ref.read(forestListProvider.notifier).loadForests();
      // Charger toutes les parcelles des forêts
      ref.read(forestListProvider).forests.forEach((f) {
        ref.read(parcelleProvider.notifier).loadParcelles(f.id);
      });
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

  LatLng? _resolvePosition(AlertMapPoint point, List<Forest> forests) {
    if (point.hasExactLocation) {
      return LatLng(point.incidentLat!, point.incidentLng!);
    }
    try {
      final forest = forests.firstWhere((f) => f.id == point.forestId);
      if (forest.centroidLat != null && forest.centroidLng != null) {
        return LatLng(forest.centroidLat!, forest.centroidLng!);
      }
    } catch (_) {}
    return null;
  }

  // ── Chargement des parcelles quand les forêts arrivent ────────
  void _loadParcellesIfNeeded(List<Forest> forests) {
    final ps = ref.read(parcelleProvider);
    for (final f in forests) {
      if (!ps.byForest.containsKey(f.id) &&
          !ps.loadingIds.contains(f.id)) {
        ref.read(parcelleProvider.notifier).loadParcelles(f.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertState  = ref.watch(alertMapProvider);
    final forestState = ref.watch(forestListProvider);
    final ps          = ref.watch(parcelleProvider);
    final forests     = forestState.forests;

    // Déclencher le chargement des parcelles quand les forêts arrivent
    if (forests.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _loadParcellesIfNeeded(forests));
    }

    // ── Polygones forêts ────────────────────────────────────────
    final forestPolygons = forests.map((f) {
      final pts = f.geojson.latLngList
          .map((p) => LatLng(p[0], p[1]))
          .toList();
      if (pts.isEmpty) return null;
      return Polygon(
        points:            pts,
        color:             const Color(0x222E7D32),
        borderColor:       const Color(0xFF2E7D32),
        borderStrokeWidth: 1.5,
        isFilled:          true,
      );
    }).whereType<Polygon>().toList();

    // ── Polygones parcelles ─────────────────────────────────────
    final parcellePolygons = <Polygon>[];
    for (final fId in ps.byForest.keys) {
      for (final p in ps.forForest(fId)) {
        final pts = p.geojson.latLngList
            .map((pt) => LatLng(pt[0], pt[1]))
            .toList();
        if (pts.isEmpty) continue;
        parcellePolygons.add(Polygon(
          points:            pts,
          color:             const Color(0x333B82F6),
          borderColor:       const Color(0xFF2563EB),
          borderStrokeWidth: 1.2,
          isFilled:          true,
        ));
      }
    }

    // ── Marqueurs alertes ────────────────────────────────────────
    final alertMarkers = <Marker>[];
    for (final point in alertState.points) {
      final position = _resolvePosition(point, forests);
      if (position == null) continue;

      alertMarkers.add(Marker(
        point:  position,
        width:  40,
        height: 44,
        child: GestureDetector(
          onTap: () => _onAlertTap(point.id),
          child: _AlertTriangle(
            type:          point.type,
            status:        point.status,
            isSelected:    _selectedAlertId == point.id,
            isApproximate: !point.hasExactLocation,
          ),
        ),
      ));
    }

    return Stack(children: [

      // ── Carte ─────────────────────────────────────────────────
      FlutterMap(
        mapController: _mapController,
        options: const MapOptions(
          initialCenter: LatLng(33.8869, 9.5375),
          initialZoom:   7.0,
          minZoom:       4,
          maxZoom:       18,
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
            subdomains:           const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.ghabetna.forest_app',
            maxZoom:              19,
          ),
          if (forestPolygons.isNotEmpty)
            PolygonLayer(polygons: forestPolygons),
          if (parcellePolygons.isNotEmpty)
            PolygonLayer(polygons: parcellePolygons),
          MarkerLayer(markers: alertMarkers),
          const RichAttributionWidget(attributions: [
            TextSourceAttribution('© CartoDB © OpenStreetMap'),
          ]),
        ],
      ),

      // ── Indicateur polling ─────────────────────────────────────
      Positioned(
        top: 16, right: 16,
        child: _PollingIndicator(
          alertCount:  alertState.points.length,
          lastRefresh: alertState.lastRefresh,
          isLoading:   alertState.isLoading || forestState.isLoading,
          onRefresh:   () => ref.read(alertMapProvider.notifier).refreshNow(),
        ),
      ),

      // ── Légende ───────────────────────────────────────────────
      const Positioned(
        bottom: 24, left: 16,
        child: _Legend(),
      ),

      // ── Popup détail alerte (lecture seule) ────────────────────
      if (_selectedAlertId != null)
        Positioned(
          top: 16, left: 16,
          child: _AlertDetailPanel(
            alertId: _selectedAlertId!,
            onClose: _closePopup,
          ),
        ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
//  TRIANGLE ALERTE
// ══════════════════════════════════════════════════════════════

class _AlertTriangle extends StatelessWidget {
  final AlertType   type;
  final AlertStatus status;
  final bool        isSelected;
  final bool        isApproximate;

  const _AlertTriangle({
    required this.type,
    required this.status,
    required this.isSelected,
    required this.isApproximate,
  });

  Color get _color => switch (status) {
        AlertStatus.en_cours => const Color(0xFFD32F2F),
        AlertStatus.traiter  => const Color(0xFF388E3C),
        AlertStatus.rejeter  => const Color(0xFF9E9E9E),
      };

  @override
  Widget build(BuildContext context) {
    final size = isSelected ? 42.0 : 32.0;
    return Stack(clipBehavior: Clip.none, children: [
      CustomPaint(
        size:    Size(size, size),
        painter: _TrianglePainter(color: _color, isSelected: isSelected),
        child: SizedBox(
          width:  size,
          height: size,
          child: Align(
            alignment: const Alignment(0, -0.1),
            child: Text(type.emoji,
                style: TextStyle(fontSize: isSelected ? 14 : 11)),
          ),
        ),
      ),
      if (isApproximate)
        Positioned(
          top: -4, right: -4,
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
    ]);
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

    canvas.drawPath(path.shift(const Offset(1.5, 2.5)), shadowPaint);
    canvas.drawPath(path, fillPaint);

    if (isSelected) {
      canvas.drawPath(
        path,
        Paint()
          ..color       = Colors.white
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
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
            mainAxisSize:       MainAxisSize.min,
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
            // Forêt
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 14, height: 10,
                  decoration: BoxDecoration(
                    color:  const Color(0x222E7D32),
                    border: Border.all(
                        color: const Color(0xFF2E7D32), width: 1),
                    borderRadius: BorderRadius.circular(2),
                  )),
              const SizedBox(width: 6),
              const Text('Forêt',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textPrimary)),
            ]),
            const SizedBox(height: 4),
            // Parcelle
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 14, height: 10,
                  decoration: BoxDecoration(
                    color:  const Color(0x333B82F6),
                    border: Border.all(
                        color: const Color(0xFF2563EB), width: 1),
                    borderRadius: BorderRadius.circular(2),
                  )),
              const SizedBox(width: 6),
              const Text('Parcelle',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textPrimary)),
            ]),
            const SizedBox(height: 4),
            _LegendTriangle(
                color: const Color(0xFFD32F2F), label: 'Alerte en cours'),
            const SizedBox(height: 4),
            _LegendTriangle(
                color: const Color(0xFF388E3C), label: 'Alerte traitée'),
            const SizedBox(height: 6),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 14, height: 14,
                decoration: const BoxDecoration(
                    color: Color(0xFFFF8F00), shape: BoxShape.circle),
                child: const Center(
                  child: Text('~',
                      style: TextStyle(
                          fontSize:   8,
                          color:      Colors.white,
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

class _LegendTriangle extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendTriangle({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size:    const Size(16, 16),
            painter: _TrianglePainter(color: color, isSelected: false),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textPrimary)),
        ],
      );
}

// ══════════════════════════════════════════════════════════════
//  POPUP DÉTAIL ALERTE — lecture seule pour le superviseur
// ══════════════════════════════════════════════════════════════

class _AlertDetailPanel extends ConsumerWidget {
  final String       alertId;
  final VoidCallback onClose;

  const _AlertDetailPanel({
    required this.alertId,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(alertDetailProvider);

    return Container(
      width:       320,
      constraints: const BoxConstraints(maxHeight: 520),
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
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: AppColors.borderLight, width: 0.5)),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(16)),
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
                onTap: onClose,
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color:        AppColors.bgInput,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.close,
                      size: 14, color: AppColors.textMuted),
                ),
              ),
            ]),
          ),

          // ── Contenu ─────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: state.isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: CircularProgressIndicator(
                            color:       AppColors.primaryMid,
                            strokeWidth: 2),
                      ),
                    )
                  : state.error != null
                      ? _ErrorState(message: state.error!)
                      : state.alert == null
                          ? const SizedBox.shrink()
                          : _ReadOnlyAlertContent(alert: state.alert!),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contenu lecture seule ──────────────────────────────────────

class _ReadOnlyAlertContent extends StatelessWidget {
  final AlertDetail alert;
  const _ReadOnlyAlertContent({required this.alert});

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

          // ── Type + statut ──────────────────────────────
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
                  Text(_formatDate(alert.createdAt),
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textMuted)),
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

          // ── Image ──────────────────────────────────────
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

          // ── Description ────────────────────────────────
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

          // ── Localisation ───────────────────────────────
          const _Label('Localisation'),
          const SizedBox(height: 6),
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
          if (alert.incidentLat != null) ...[
            const SizedBox(height: 4),
            _InfoRow(
              icon:  Icons.my_location,
              color: AppColors.primaryMid,
              text:  'Incident : ${alert.incidentLat!.toStringAsFixed(5)}, '
                     '${alert.incidentLng!.toStringAsFixed(5)}',
            ),
          ],
          if (alert.agentLat != null) ...[
            const SizedBox(height: 4),
            _InfoRow(
              icon:  Icons.person_pin_circle_outlined,
              color: AppColors.info,
              text:  'Agent : ${alert.agentLat!.toStringAsFixed(5)}, '
                     '${alert.agentLng!.toStringAsFixed(5)}',
            ),
          ],
          if (alert.distanceKm != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
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
                  size:  13,
                  color: alert.distanceKm! > 5
                      ? AppColors.danger
                      : AppColors.success,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Distance : ${alert.distanceKm!.toStringAsFixed(1)} km'
                    '${alert.distanceKm! > 5 ? ' ⚠️ Suspect' : ''}',
                    style: TextStyle(
                        fontSize:   11,
                        color:      alert.distanceKm! > 5
                            ? AppColors.danger
                            : AppColors.success,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ]),
            ),
          ],

          // ── Commentaire admin ──────────────────────────
          if (alert.adminComment != null &&
              alert.adminComment!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(height: 0.5, color: AppColors.borderLight),
            const SizedBox(height: 12),
            const _Label('Commentaire admin'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
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
          ],

          // ── Statut final (lecture seule) ───────────────
          const SizedBox(height: 12),
          Container(height: 0.5, color: AppColors.borderLight),
          const SizedBox(height: 12),
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
                switch (alert.status) {
                  AlertStatus.en_cours => Icons.pending_outlined,
                  AlertStatus.traiter  => Icons.check_circle_outline,
                  AlertStatus.rejeter  => Icons.cancel_outlined,
                },
                size:  14,
                color: _statusColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Statut : ${alert.status.label}',
                style: TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.w500,
                    color:      _statusColor),
              ),
            ]),
          ),
        ],
      );

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

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
  const _InfoRow(
      {required this.icon, required this.color, required this.text});

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