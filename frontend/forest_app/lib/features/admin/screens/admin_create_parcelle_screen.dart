// features/admin/screens/admin_create_parcelle_screen.dart
//
// Crée une parcelle DANS une forêt donnée.
// La forêt parente est affichée en vert foncé sur la carte.
// La parcelle en cours de dessin s'affiche en vert clair.
// Validation côté back : parcelle doit être dans la forêt.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../features/forest/providers/forest_provider.dart';

class AdminCreateParcelleScreen extends ConsumerStatefulWidget {
  final String forestId;
  const AdminCreateParcelleScreen({super.key, required this.forestId});

  @override
  ConsumerState<AdminCreateParcelleScreen> createState() =>
      _AdminCreateParcelleScreenState();
}

class _AdminCreateParcelleScreenState
    extends ConsumerState<AdminCreateParcelleScreen> {
  final _nameCtrl      = TextEditingController();
  final _formKey       = GlobalKey<FormState>();
  final _mapController = MapController();

  final List<LatLng> _points      = [];
  bool               _isDrawing   = false;
  bool               _isSubmitting = false;
  String?            _errorMessage;

  bool get _isClosed =>
      _points.length >= 3 &&
      _points.first.latitude  == _points.last.latitude &&
      _points.first.longitude == _points.last.longitude;

  bool get _canClose => _points.length >= 3 && !_isClosed;

  @override
  void initState() {
    super.initState();
    // Load forest if not already in state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(forestListProvider);
      if (state.forests.isEmpty) {
        ref.read(forestListProvider.notifier).loadForests();
      }
    });
  }

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
    if (!_canClose) return;
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
          _errorMessage = 'Veuillez fermer le polygone de la parcelle.');
      return;
    }

    setState(() { _isSubmitting = true; _errorMessage = null; });

    try {
      final p = await ref
          .read(parcelleProvider.notifier)
          .createParcelle(
            forestId: widget.forestId,
            name:     _nameCtrl.text.trim(),
            geojson:  _buildGeoJSON(),
          );

      if (p != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Parcelle « ${p.name} » créée'),
          ]),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ));
        context.go('/admin/forests');
      } else {
        final err = ref.read(parcelleProvider).error;
        setState(() => _errorMessage = err ?? 'Erreur inconnue');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final forestState = ref.watch(forestListProvider);
    final forest = forestState.forests
        .where((f) => f.id == widget.forestId)
        .firstOrNull;

    // Build forest polygon points
    List<LatLng> forestPts = [];
    if (forest != null) {
      forestPts = forest.geojson.latLngList
          .map((p) => LatLng(p[0], p[1]))
          .toList();
    }

    final closedPts = _isClosed ? _points : <LatLng>[];
    final openPts   = _isClosed ? <LatLng>[] : _points;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/admin/forests'),
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
                        const Text('Nouvelle parcelle',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.3)),
                        Text(
                          forest != null
                              ? 'Forêt : ${forest.name}'
                              : 'Chargement...',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(
                      message: _errorMessage!,
                      onDismiss: () =>
                          setState(() => _errorMessage = null)),
                ],

                const SizedBox(height: 14),

                // Info banner — forest boundary
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.infoBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.info.withOpacity(0.3),
                        width: 0.5),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline,
                        size: 14, color: AppColors.info),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'La parcelle doit être entièrement à l\'intérieur de la forêt parente (zone verte foncée).',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.info),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 12),

                Form(
                  key: _formKey,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 40,
                          child: TextFormField(
                            controller: _nameCtrl,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Champ requis'
                                    : null,
                            decoration: InputDecoration(
                              hintText: 'Nom de la parcelle *',
                              hintStyle: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted),
                              prefixIcon: const Icon(
                                  Icons.crop_square_outlined,
                                  size: 16,
                                  color: AppColors.textMuted),
                              filled:    true,
                              fillColor: AppColors.bgInput,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: AppColors.border,
                                    width: 0.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: AppColors.border,
                                    width: 0.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: AppColors.primaryMid,
                                    width: 1.2),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      _ToolbarBtn(
                        label: _isDrawing ? 'Arrêter' : 'Dessiner',
                        icon:  _isDrawing
                            ? Icons.stop
                            : Icons.edit_location_alt_outlined,
                        color: _isDrawing
                            ? AppColors.warning
                            : AppColors.primaryMid,
                        onTap: () =>
                            setState(() => _isDrawing = !_isDrawing),
                      ),
                      const SizedBox(width: 6),
                      _ToolbarBtn(
                        label: 'Fermer',
                        icon:  Icons.check_circle_outline,
                        color: _canClose
                            ? AppColors.success
                            : AppColors.textMuted,
                        onTap: _canClose ? _closePolygon : null,
                      ),
                      const SizedBox(width: 6),
                      _ToolbarBtn(
                        label: 'Annuler pt',
                        icon:  Icons.undo,
                        color: _points.isNotEmpty
                            ? AppColors.info
                            : AppColors.textMuted,
                        onTap: _points.isNotEmpty ? _undoLastPoint : null,
                      ),
                      const SizedBox(width: 6),
                      _ToolbarBtn(
                        label: 'Effacer',
                        icon:  Icons.delete_sweep_outlined,
                        color: _points.isNotEmpty
                            ? AppColors.danger
                            : AppColors.textMuted,
                        onTap: _points.isNotEmpty ? _clearDrawing : null,
                      ),

                      const Spacer(),

                      OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => context.go('/admin/forests'),
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
                        onPressed: _isSubmitting ? null : _submit,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2))
                            : const Icon(Icons.save_outlined,
                                size: 16),
                        label: Text(_isSubmitting
                            ? 'Création...'
                            : 'Enregistrer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isClosed
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
          ),

          // ── Map ────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: forest?.centroidLat != null
                        ? LatLng(forest!.centroidLat!,
                            forest.centroidLng!)
                        : const LatLng(33.8869, 9.5375),
                    initialZoom: forest != null ? 11.0 : 7.0,
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

                    // Parent forest (reference)
                    if (forestPts.length >= 3)
                      PolygonLayer(polygons: [
                        Polygon(
                          points: forestPts,
                          color: const Color(0x332E7D32),
                          borderColor: AppColors.primaryDark,
                          borderStrokeWidth: 2.0,
                          isFilled: true,
                        ),
                      ]),

                    // New parcelle — closed
                    if (closedPts.length >= 3)
                      PolygonLayer(polygons: [
                        Polygon(
                          points: closedPts,
                          color: const Color(0x7781C784),
                          borderColor: const Color(0xFF388E3C),
                          borderStrokeWidth: 2.0,
                          isFilled: true,
                        ),
                      ]),

                    // New parcelle — open line
                    if (openPts.length >= 2)
                      PolylineLayer(polylines: [
                        Polyline(
                          points: openPts,
                          color: const Color(0xFF388E3C),
                          strokeWidth: 2.0,
                          isDotted: true,
                        ),
                      ]),

                    MarkerLayer(
                      markers: _points
                          .asMap()
                          .entries
                          .map((e) => Marker(
                                point:  e.value,
                                width:  e.key == 0 ? 18 : 12,
                                height: e.key == 0 ? 18 : 12,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: e.key == 0
                                        ? const Color(0xFF388E3C)
                                        : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF388E3C),
                                      width: 2,
                                    ),
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

                if (_isDrawing && _points.isEmpty)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
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
                            'Cliquez à l\'intérieur de la forêt\npour ajouter des points',
                            style: TextStyle(
                                color: Colors.white, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_points.isNotEmpty)
                  Positioned(
                    bottom: 48, left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: (_isClosed
                            ? AppColors.success
                            : const Color(0xFF388E3C))
                            .withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _isClosed
                            ? '✓ Parcelle fermée'
                            : '${_points.length} point${_points.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
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
              color: disabled ? AppColors.border : color.withOpacity(0.3),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15,
                  color: disabled ? AppColors.textMuted : color),
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