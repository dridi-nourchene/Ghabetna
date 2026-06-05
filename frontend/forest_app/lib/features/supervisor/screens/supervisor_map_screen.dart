import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;
import '../../../../core/theme/app_colors.dart';
import '../../../features/alert/models/alert_map_model.dart';
import '../../../features/alert/providers/alert_map_provider.dart';
import '../../../features/forest/models/forest_model.dart';
import '../../../features/forest/widgets/zoom_panel.dart';
import '../providers/supervisor_forest_provider.dart';

class SupervisorMapScreen extends ConsumerStatefulWidget {
  const SupervisorMapScreen({super.key});

  @override
  ConsumerState<SupervisorMapScreen> createState() =>
      _SupervisorMapScreenState();
}

class _SupervisorMapScreenState extends ConsumerState<SupervisorMapScreen> {
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(alertMapProvider.notifier).startPolling();
      // ← utiliser supervisorForestProvider au lieu de forestListProvider
      ref.read(supervisorForestProvider.notifier).loadForests();
    });
  }

  @override
  void dispose() {
    ref.read(alertMapProvider.notifier).stopPolling();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final alertState      = ref.watch(alertMapProvider);
    // ← supervisorForestProvider au lieu de forestListProvider
    final supervisorState = ref.watch(supervisorForestProvider);
    final forests         = supervisorState.forests;

    // ── Polygones forêts (seulement celles du superviseur) ──
    final forestPolygons = forests.map((f) {
      final pts = f.geojson.latLngList
          .map((p) => LatLng(p[0], p[1]))
          .toList();
      if (pts.isEmpty) return null;
      return Polygon(
        points:            pts,
        // même style que admin_forests_screen
        color:             const Color(0x222E7D32),
        borderColor:       const Color(0xFF2E7D32),
        borderStrokeWidth: 1.8,
        isFilled:          true,
      );
    }).whereType<Polygon>().toList();

    // ── Polygones parcelles (seulement parcelles des forêts du superviseur) ──
    final parcellePolygons = <Polygon>[];
    for (final f in forests) {
      for (final p in supervisorState.parcellesFor(f.id)) {
        final pts = p.geojson.latLngList
            .map((pt) => LatLng(pt[0], pt[1]))
            .toList();
        if (pts.isEmpty) continue;
        parcellePolygons.add(Polygon(
          points:            pts,
          // même style que admin_forests_screen
          color:             const Color(0x333B82F6),
          borderColor:       const Color(0xFF2563EB),
          borderStrokeWidth: 1.5,
          isFilled:          true,
        ));
      }
    }

    // ── Labels forêts (markers) ──────────────────────────────
    final forestLabelMarkers = forests
        .where((f) => f.centroidLat != null)
        .map((f) => Marker(
              point:  LatLng(f.centroidLat!, f.centroidLng!),
              width:  160,
              height: 40,
              child: _ForestLabel(name: f.name),
            ))
        .toList();

    // ── Markers alertes ──────────────────────────────────────
    final alertMarkers = <Marker>[];
    for (final point in alertState.points) {
      final position = _resolvePosition(point, forests);
      if (position == null) continue;

      alertMarkers.add(Marker(
        point:  position,
        width:  40,
        height: 44,
        child: GestureDetector(
          onTap: () => context.push('/supervisor/alert/${point.id}'),
          child: _AlertTriangle(
            type:          point.type,
            status:        point.status,
            isApproximate: !point.hasExactLocation,
          ),
        ),
      ));
    }

    final isLoading = supervisorState.isLoading || alertState.isLoading;

    return Stack(children: [
      FlutterMap(
        mapController: _mapController,
        options: const MapOptions(
          initialCenter: LatLng(33.8869, 9.5375),
          initialZoom:   7.0,
          minZoom:       4,
          maxZoom:       19,
        ),
        children: [
          // ← même tile que admin (CartoDB Voyager)
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
          MarkerLayer(markers: forestLabelMarkers),
          MarkerLayer(markers: alertMarkers),
          const RichAttributionWidget(attributions: [
            TextSourceAttribution('© CartoDB © OpenStreetMap'),
          ]),
        ],
      ),

      // ── Indicateur chargement ──────────────────────────────
      if (isLoading)
        const Positioned(
          top: 12, left: 0, right: 0,
          child: Center(
            child: _LoadingChip(),
          ),
        ),

      // ── Polling indicator + refresh ────────────────────────
      Positioned(
        top: 16, right: 16,
        child: _PollingIndicator(
          alertCount:  alertState.points.length,
          lastRefresh: alertState.lastRefresh,
          isLoading:   isLoading,
          onRefresh:   () {
            ref.read(alertMapProvider.notifier).refreshNow();
            ref.read(supervisorForestProvider.notifier).loadForests();
          },
        ),
      ),

      // ── Légende ────────────────────────────────────────────
      const Positioned(
        bottom: 24, left: 16,
        child: _Legend(),
      ),

      // ── Zoom controls ──────────────────────────────────────
      Positioned(
        right: 14,
        bottom: 40,
        child: ZoomPanel(mapController: _mapController),
      ),

      // ── Message si aucune forêt assignée ──────────────────
      if (!isLoading && forests.isEmpty)
        Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color:      Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset:     const Offset(0, 4),
                ),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.park_outlined,
                  size: 40, color: AppColors.primaryMid),
              const SizedBox(height: 12),
              const Text(
                'Aucune forêt assignée',
                style: TextStyle(
                    fontSize:   16,
                    fontWeight: FontWeight.w700,
                    color:      AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Aucune forêt ne vous a encore été assignée.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color:    AppColors.textMuted),
              ),
            ]),
          ),
        ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
//  FOREST LABEL (même style que admin)
// ══════════════════════════════════════════════════════════════

class _ForestLabel extends StatelessWidget {
  final String name;
  const _ForestLabel({required this.name});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2E7D32), width: 1.2),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.12),
              blurRadius: 6,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.park_outlined,
              size: 12, color: Color(0xFF2E7D32)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              name,
              overflow:  TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize:   11,
                  fontWeight: FontWeight.w600,
                  color:      Color(0xFF1A4731)),
            ),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════
//  TRIANGLE ALERTE
// ══════════════════════════════════════════════════════════════

class _AlertTriangle extends StatelessWidget {
  final AlertType   type;
  final AlertStatus status;
  final bool        isApproximate;

  const _AlertTriangle({
    required this.type,
    required this.status,
    required this.isApproximate,
  });

  Color get _color => switch (status) {
        AlertStatus.en_cours => const Color(0xFFD32F2F),
        AlertStatus.traiter  => const Color(0xFF388E3C),
        AlertStatus.rejeter  => const Color(0xFF9E9E9E),
      };

  @override
  Widget build(BuildContext context) {
    const size = 34.0;
    return Stack(clipBehavior: Clip.none, children: [
      CustomPaint(
        size:    const Size(size, size),
        painter: _TrianglePainter(color: _color),
        child: const SizedBox(width: size, height: size),
      ),
      Positioned(
        top: size * 0.15,
        left: 0, right: 0,
        child: Center(
          child: Text(type.emoji,
              style: const TextStyle(fontSize: 12)),
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
  _TrianglePainter({required this.color});

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
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

// ══════════════════════════════════════════════════════════════
//  LOADING CHIP
// ══════════════════════════════════════════════════════════════

class _LoadingChip extends StatelessWidget {
  const _LoadingChip();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color:      Colors.black.withOpacity(0.1),
                blurRadius: 8),
          ],
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primaryMid),
          ),
          SizedBox(width: 8),
          Text('Chargement...',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ]),
      );
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
            const SizedBox(height: 6),
            // Forêt
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 16, height: 16,
                decoration: BoxDecoration(
                  color:  const Color(0x222E7D32),
                  border: Border.all(
                      color: const Color(0xFF2E7D32), width: 1.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Forêt assignée',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textPrimary)),
            ]),
            const SizedBox(height: 4),
            // Parcelle
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 16, height: 16,
                decoration: BoxDecoration(
                  color:  const Color(0x333B82F6),
                  border: Border.all(
                      color: const Color(0xFF2563EB), width: 1.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
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
            painter: _TrianglePainter(color: color),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textPrimary)),
        ],
      );
}