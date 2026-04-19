// features/admin/screens/admin_create_forest_screen.dart
//
// Permet de :
//   1. Saisir le nom de la forêt
//   2. Dessiner le polygone sur la carte (clic point par point)
//   3. Soumettre à l'API

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../features/forest/providers/forest_provider.dart';

const _tunisiaCenter = LatLng(33.8869, 9.5375);

class AdminCreateForestScreen extends ConsumerStatefulWidget {
  const AdminCreateForestScreen({super.key});

  @override
  ConsumerState<AdminCreateForestScreen> createState() =>
      _AdminCreateForestScreenState();
}

class _AdminCreateForestScreenState
    extends ConsumerState<AdminCreateForestScreen> {
  final _nameCtrl    = TextEditingController();
  final _formKey     = GlobalKey<FormState>();
  final _mapController = MapController();

  // Drawing state
  final List<LatLng> _points      = [];
  bool               _isDrawing   = false;
  bool               _isSubmitting = false;
  String?            _errorMessage;

  // Min 3 points to close polygon
  bool get _canClose => _points.length >= 3;
  bool get _isClosed =>
      _points.length >= 3 &&
      _points.first.latitude  == _points.last.latitude &&
      _points.first.longitude == _points.last.longitude;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onMapTap(_, LatLng point) {
    if (!_isDrawing || _isClosed) return;
    setState(() => _points.add(point));
  }

  void _closePolygon() {
    if (!_canClose || _isClosed) return;
    setState(() => _points.add(_points.first));
  }

  void _undoLastPoint() {
    if (_points.isEmpty) return;
    setState(() => _points.removeLast());
  }

  void _clearDrawing() {
    setState(() => _points.clear());
  }

  Map<String, dynamic> _buildGeoJSON() {
    final coords = _points.map((p) => [p.longitude, p.latitude]).toList();
    return {
      'type': 'Polygon',
      'coordinates': [coords],
    };
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isClosed) {
      setState(() =>
          _errorMessage = 'Veuillez fermer le polygone (au moins 3 points).');
      return;
    }

    setState(() { _isSubmitting = true; _errorMessage = null; });

    try {
      final forest = await ref
          .read(forestListProvider.notifier)
          .createForest(
            name:    _nameCtrl.text.trim(),
            geojson: _buildGeoJSON(),
          );

      if (forest != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Forêt « ${forest.name} » créée'),
          ]),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ));
        context.go('/admin/forests');
      } else {
        final err = ref.read(forestListProvider).error;
        setState(() => _errorMessage = err ?? 'Erreur inconnue');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final closedPts = _isClosed ? _points : [];
    final openPts   = _isClosed ? <LatLng>[] : _points;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────
          _Header(
            nameCtrl:     _nameCtrl,
            formKey:      _formKey,
            isDrawing:    _isDrawing,
            isClosed:     _isClosed,
            canClose:     _canClose,
            pointCount:   _points.length,
            isSubmitting: _isSubmitting,
            errorMessage: _errorMessage,
            onDismissError: () => setState(() => _errorMessage = null),
            onToggleDraw: () => setState(() => _isDrawing = !_isDrawing),
            onClose:      _closePolygon,
            onUndo:       _undoLastPoint,
            onClear:      _clearDrawing,
            onSubmit:     _submit,
            onCancel:     () => context.go('/admin/forests'),
          ),

          // ── Map ────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _tunisiaCenter,
                    initialZoom:   7.0,
                    minZoom: 5.0,
                    maxZoom: 18.0,
                    onTap: _onMapTap,
                    // Change cursor when drawing
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.ghabetna.forest_app',
                    ),

                    // Closed polygon fill
                    if (closedPts.length >= 3)
                      PolygonLayer(polygons: [
                        Polygon(
                          points: closedPts as List<LatLng>,
                          color: const Color(0x552E7D32),
                          borderColor: AppColors.primaryDark,
                          borderStrokeWidth: 2.0,
                          isFilled: true,
                        ),
                      ]),

                    // Open polyline while drawing
                    if (openPts.length >= 2)
                      PolylineLayer(polylines: [
                        Polyline(
                          points: openPts as List<LatLng>,
                          color: AppColors.primaryMid,
                          strokeWidth: 2.0,
                          isDotted: true,
                        ),
                      ]),

                    // Points markers
                    MarkerLayer(
                      markers: _points
                          .asMap()
                          .entries
                          .map((e) {
                            final isFirst = e.key == 0;
                            final isLast  = e.key == _points.length - 1 &&
                                _isClosed;
                            return Marker(
                              point:  e.value,
                              width:  isFirst ? 20 : 14,
                              height: isFirst ? 20 : 14,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isFirst
                                      ? AppColors.primaryDark
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primaryDark,
                                    width: 2,
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList(),
                    ),

                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                            'OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),

                // ── Drawing hint overlay ──────────────────
                if (_isDrawing && _points.isEmpty)
                  const _DrawingHint(),

                // ── Point counter chip ────────────────────
                if (_points.isNotEmpty)
                  Positioned(
                    bottom: 48, left: 16,
                    child: _PointCounter(
                      count: _points.length,
                      isClosed: _isClosed,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  HEADER with toolbar
// ═══════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final TextEditingController nameCtrl;
  final GlobalKey<FormState>  formKey;
  final bool     isDrawing;
  final bool     isClosed;
  final bool     canClose;
  final int      pointCount;
  final bool     isSubmitting;
  final String?  errorMessage;
  final VoidCallback onDismissError;
  final VoidCallback onToggleDraw;
  final VoidCallback onClose;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _Header({
    required this.nameCtrl,
    required this.formKey,
    required this.isDrawing,
    required this.isClosed,
    required this.canClose,
    required this.pointCount,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onDismissError,
    required this.onToggleDraw,
    required this.onClose,
    required this.onUndo,
    required this.onClear,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title row ──────────────────────────────────
          Row(
            children: [
              GestureDetector(
                onTap: onCancel,
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.border, width: 0.5),
                  ),
                  child: const Icon(Icons.arrow_back,
                      size: 16, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Créer une forêt',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3)),
                  Text('Dessinez le polygone sur la carte',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),

          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(
                message: errorMessage!, onDismiss: onDismissError),
          ],

          const SizedBox(height: 14),

          // ── Controls row ────────────────────────────────
          Form(
            key: formKey,
            child: Row(
              children: [
                // Name field
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 40,
                    child: TextFormField(
                      controller: nameCtrl,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Champ requis'
                          : null,
                      decoration: InputDecoration(
                        hintText:  'Nom de la forêt *',
                        hintStyle: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.park_outlined,
                            size: 16, color: AppColors.textMuted),
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
                              color: AppColors.primaryMid,
                              width: 1.2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Draw toggle
                _ToolbarBtn(
                  label:   isDrawing ? 'Arrêter' : 'Dessiner',
                  icon:    isDrawing ? Icons.stop : Icons.edit_location_alt_outlined,
                  color:   isDrawing ? AppColors.warning : AppColors.primaryMid,
                  onTap:   onToggleDraw,
                ),
                const SizedBox(width: 6),

                // Close polygon
                _ToolbarBtn(
                  label:  'Fermer',
                  icon:   Icons.check_circle_outline,
                  color:  canClose && !isClosed
                      ? AppColors.success
                      : AppColors.textMuted,
                  onTap:  canClose && !isClosed ? onClose : null,
                ),
                const SizedBox(width: 6),

                // Undo
                _ToolbarBtn(
                  label:  'Annuler pt',
                  icon:   Icons.undo,
                  color:  pointCount > 0
                      ? AppColors.info
                      : AppColors.textMuted,
                  onTap:  pointCount > 0 ? onUndo : null,
                ),
                const SizedBox(width: 6),

                // Clear
                _ToolbarBtn(
                  label:  'Effacer',
                  icon:   Icons.delete_sweep_outlined,
                  color:  pointCount > 0
                      ? AppColors.danger
                      : AppColors.textMuted,
                  onTap:  pointCount > 0 ? onClear : null,
                ),

                const Spacer(),

                // Cancel
                OutlinedButton(
                  onPressed: isSubmitting ? null : onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(
                        color: AppColors.border, width: 0.8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Annuler',
                      style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),

                // Submit
                ElevatedButton.icon(
                  onPressed: isSubmitting ? null : onSubmit,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2))
                      : const Icon(Icons.save_outlined, size: 16),
                  label: Text(
                      isSubmitting ? 'Création...' : 'Enregistrer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isClosed
                        ? AppColors.primaryDark
                        : AppColors.textMuted,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Toolbar button ─────────────────────────────────────────────

class _ToolbarBtn extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback? onTap;

  const _ToolbarBtn({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: disabled
                ? AppColors.bgInput
                : color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: disabled
                  ? AppColors.border
                  : color.withOpacity(0.3),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: disabled ? AppColors.textMuted : color),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: disabled ? AppColors.textMuted : color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Drawing hint ───────────────────────────────────────────────

class _DrawingHint extends StatelessWidget {
  const _DrawingHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_outlined,
                color: Colors.white, size: 28),
            SizedBox(height: 8),
            Text(
              'Cliquez sur la carte pour ajouter des points',
              style: TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              'Appuyez sur « Fermer » pour terminer le polygone',
              style: TextStyle(
                  color: Colors.white70, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Point counter ──────────────────────────────────────────────

class _PointCounter extends StatelessWidget {
  final int  count;
  final bool isClosed;
  const _PointCounter({required this.count, required this.isClosed});

  @override
  Widget build(BuildContext context) {
    final color  = isClosed ? AppColors.success : AppColors.primaryMid;
    final label  = isClosed ? '✓ Polygone fermé' : '$count point${count != 1 ? 's' : ''}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white)),
    );
  }
}

// ── Error banner ───────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String       message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppColors.danger.withOpacity(0.3), width: 0.5),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline,
              size: 15, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.danger))),
          GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close,
                  size: 15, color: AppColors.danger)),
        ]),
      );
}