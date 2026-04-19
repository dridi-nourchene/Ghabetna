// features/admin/screens/admin_edit_forest_screen.dart
//
// Charge la forêt existante depuis le provider,
// pré-remplit le nom et affiche le polygone actuel.
// L'admin peut soit juste changer le nom, soit
// aussi redessiner un nouveau polygone.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../features/forest/models/forest_model.dart';
import '../../../features/forest/providers/forest_provider.dart';

const _tunisiaCenter = LatLng(33.8869, 9.5375);

class AdminEditForestScreen extends ConsumerStatefulWidget {
  final String forestId;
  const AdminEditForestScreen({super.key, required this.forestId});

  @override
  ConsumerState<AdminEditForestScreen> createState() =>
      _AdminEditForestScreenState();
}

class _AdminEditForestScreenState
    extends ConsumerState<AdminEditForestScreen> {
  final _nameCtrl      = TextEditingController();
  final _formKey       = GlobalKey<FormState>();
  final _mapController = MapController();

  List<LatLng>  _points         = [];
  bool          _isDrawing      = false;
  bool          _polygonChanged = false;
  bool          _isSubmitting   = false;
  String?       _errorMessage;
  bool          _initialized    = false;
  Forest?       _originalForest;

  bool get _isClosed =>
      _points.length >= 3 &&
      _points.first.latitude  == _points.last.latitude &&
      _points.first.longitude == _points.last.longitude;

  bool get _canClose => _points.length >= 3 && !_isClosed;

  void _initFromForest(Forest forest) {
    if (_initialized) return;
    _originalForest = forest;
    _nameCtrl.text  = forest.name;
    _points = forest.geojson.latLngList
        .map((p) => LatLng(p[0], p[1]))
        .toList();
    _initialized = true;

    // Fly to forest
    if (forest.centroidLat != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(
          LatLng(forest.centroidLat!, forest.centroidLng!),
          11.0,
        );
      });
    }
  }

  void _onMapTap(_, LatLng point) {
    if (!_isDrawing) return;
    if (_isClosed && !_polygonChanged) {
      // Start fresh polygon
      setState(() {
        _points = [point];
        _polygonChanged = true;
      });
      return;
    }
    if (_isClosed) return;
    setState(() => _points.add(point));
  }

  void _startRedraw() {
    setState(() {
      _points = [];
      _isDrawing = true;
      _polygonChanged = true;
    });
  }

  void _closePolygon() {
    if (!_canClose) return;
    setState(() => _points.add(_points.first));
  }

  void _undoLastPoint() {
    if (_points.isEmpty) return;
    setState(() => _points.removeLast());
  }

  void _resetPolygon() {
    if (_originalForest == null) return;
    setState(() {
      _points = _originalForest!.geojson.latLngList
          .map((p) => LatLng(p[0], p[1]))
          .toList();
      _isDrawing      = false;
      _polygonChanged = false;
    });
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
          _errorMessage = 'Veuillez fermer le polygone.');
      return;
    }

    setState(() { _isSubmitting = true; _errorMessage = null; });

    try {
      final updated = await ref
          .read(forestListProvider.notifier)
          .updateForest(
            widget.forestId,
            name:    _nameCtrl.text.trim(),
            geojson: _polygonChanged ? _buildGeoJSON() : null,
          );

      if (updated != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Forêt « ${updated.name} » mise à jour'),
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
    final forestState = ref.watch(forestListProvider);
    Forest? forest;
    try {
      forest = forestState.forests
          .firstWhere((f) => f.id == widget.forestId);
    } catch (_) {
      forest = null;
    }

    if (forest == null && !forestState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(forestListProvider.notifier).loadForests();
      });
    }

    if (forest == null && forestState.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryMid),
        ),
      );
    }

    if (forest == null) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.park_outlined,
                size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('Forêt introuvable',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/admin/forests'),
              child: const Text('Retour'),
            ),
          ]),
        ),
      );
    }

    _initFromForest(forest);

    final closedPts = _isClosed ? _points : <LatLng>[];
    final openPts   = _isClosed ? <LatLng>[] : _points;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────
          _EditHeader(
            nameCtrl:        _nameCtrl,
            formKey:         _formKey,
            forestName:      forest.name,
            isDrawing:       _isDrawing,
            isClosed:        _isClosed,
            canClose:        _canClose,
            polygonChanged:  _polygonChanged,
            pointCount:      _points.length,
            isSubmitting:    _isSubmitting,
            errorMessage:    _errorMessage,
            onDismissError:  () => setState(() => _errorMessage = null),
            onStartRedraw:   _startRedraw,
            onResetPolygon:  _resetPolygon,
            onClosePolygon:  _closePolygon,
            onUndo:          _undoLastPoint,
            onSubmit:        _submit,
            onCancel:        () => context.go('/admin/forests'),
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
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.ghabetna.forest_app',
                    ),

                    // Closed polygon
                    if (closedPts.length >= 3)
                      PolygonLayer(polygons: [
                        Polygon(
                          points: closedPts,
                          color: _polygonChanged
                              ? const Color(0x55FF6F00)
                              : const Color(0x552E7D32),
                          borderColor: _polygonChanged
                              ? AppColors.warning
                              : AppColors.primaryDark,
                          borderStrokeWidth: 2.0,
                          isFilled: true,
                        ),
                      ]),

                    // Open polyline
                    if (openPts.length >= 2)
                      PolylineLayer(polylines: [
                        Polyline(
                          points: openPts,
                          color: AppColors.primaryMid,
                          strokeWidth: 2.0,
                          isDotted: true,
                        ),
                      ]),

                    // Point markers
                    MarkerLayer(
                      markers: _points
                          .asMap()
                          .entries
                          .map((e) => Marker(
                                point:  e.value,
                                width:  e.key == 0 ? 20 : 12,
                                height: e.key == 0 ? 20 : 12,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: e.key == 0
                                        ? AppColors.primaryDark
                                        : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppColors.primaryDark,
                                        width: 2),
                                  ),
                                ),
                              ))
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

                // Redraw hint
                if (_isDrawing && _points.isEmpty)
                  const Center(
                    child: _RedrawHint(),
                  ),

                // Polygon changed badge
                if (_polygonChanged)
                  Positioned(
                    top: 12, left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(children: [
                        Icon(Icons.edit, size: 12, color: Colors.white),
                        SizedBox(width: 5),
                        Text('Polygone modifié',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ]),
                    ),
                  ),

                if (_points.isNotEmpty && _isDrawing)
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

// ── Edit Header ────────────────────────────────────────────────

class _EditHeader extends StatelessWidget {
  final TextEditingController nameCtrl;
  final GlobalKey<FormState>  formKey;
  final String   forestName;
  final bool     isDrawing;
  final bool     isClosed;
  final bool     canClose;
  final bool     polygonChanged;
  final int      pointCount;
  final bool     isSubmitting;
  final String?  errorMessage;
  final VoidCallback onDismissError;
  final VoidCallback onStartRedraw;
  final VoidCallback onResetPolygon;
  final VoidCallback onClosePolygon;
  final VoidCallback onUndo;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _EditHeader({
    required this.nameCtrl,
    required this.formKey,
    required this.forestName,
    required this.isDrawing,
    required this.isClosed,
    required this.canClose,
    required this.polygonChanged,
    required this.pointCount,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onDismissError,
    required this.onStartRedraw,
    required this.onResetPolygon,
    required this.onClosePolygon,
    required this.onUndo,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Modifier la forêt',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3)),
                  Text(forestName,
                      style: const TextStyle(
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

          Form(
            key: formKey,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 40,
                    child: TextFormField(
                      controller: nameCtrl,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textPrimary),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Champ requis'
                              : null,
                      decoration: InputDecoration(
                        hintText:  'Nom de la forêt *',
                        hintStyle: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
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
                              color: AppColors.primaryMid, width: 1.2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Redraw
                if (!isDrawing)
                  _EditToolBtn(
                    label: 'Redessiner',
                    icon:  Icons.draw_outlined,
                    color: AppColors.warning,
                    onTap: onStartRedraw,
                  ),

                // Close polygon
                if (isDrawing && canClose) ...[
                  const SizedBox(width: 6),
                  _EditToolBtn(
                    label: 'Fermer',
                    icon:  Icons.check_circle_outline,
                    color: AppColors.success,
                    onTap: onClosePolygon,
                  ),
                ],

                // Undo
                if (isDrawing && pointCount > 0) ...[
                  const SizedBox(width: 6),
                  _EditToolBtn(
                    label: 'Annuler pt',
                    icon:  Icons.undo,
                    color: AppColors.info,
                    onTap: onUndo,
                  ),
                ],

                // Reset to original
                if (polygonChanged) ...[
                  const SizedBox(width: 6),
                  _EditToolBtn(
                    label: 'Réinitialiser',
                    icon:  Icons.restore,
                    color: AppColors.textSecondary,
                    onTap: onResetPolygon,
                  ),
                ],

                const Spacer(),

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

                ElevatedButton.icon(
                  onPressed: isSubmitting ? null : onSubmit,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_outlined, size: 16),
                  label: Text(isSubmitting ? 'Mise à jour...' : 'Enregistrer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
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

class _EditToolBtn extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;

  const _EditToolBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        ),
      );
}

class _RedrawHint extends StatelessWidget {
  const _RedrawHint();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_outlined, color: Colors.white, size: 28),
            SizedBox(height: 8),
            Text('Cliquez pour ajouter des points',
                style: TextStyle(color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      );
}

class _PointCounter extends StatelessWidget {
  final int  count;
  final bool isClosed;
  const _PointCounter({required this.count, required this.isClosed});

  @override
  Widget build(BuildContext context) {
    final color = isClosed ? AppColors.success : AppColors.warning;
    final label = isClosed
        ? '✓ Polygone fermé'
        : '$count point${count != 1 ? 's' : ''}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
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
          const Icon(Icons.error_outline, size: 15, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(child: Text(message,
              style: const TextStyle(fontSize: 12, color: AppColors.danger))),
          GestureDetector(onTap: onDismiss,
              child: const Icon(Icons.close, size: 15, color: AppColors.danger)),
        ]),
      );
}