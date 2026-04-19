// features/admin/screens/admin_forests_screen.dart
//
// CHANGEMENTS v2 :
//   - Tuiles satellite (ESRI World Imagery) au lieu d'OSM vert
//   - Formulaire création/édition dans la sidebar (pas de topbar séparée)
//   - Panel sidebar gère 3 modes : LIST | CREATE_FOREST | CREATE_PARCELLE

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../features/forest/models/forest_model.dart';
import '../../../features/forest/providers/forest_provider.dart';

// ── Tunisie center ─────────────────────────────────────────────
const _tunisiaCenter = LatLng(33.8869, 9.5375);
const _initialZoom   = 7.0;

// ── Satellite tile URL (ESRI — pas de clé requise) ─────────────
const _satelliteUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/'
    'World_Imagery/MapServer/tile/{z}/{y}/{x}';

// ── Couleurs polygones sur fond satellite ──────────────────────
const _forestFill    = Color(0x6622C55E);   // vert néon semi-transparent
const _forestBorder  = Color(0xFF22C55E);
const _parcelleFill  = Color(0x6660A5FA);   // bleu semi-transparent
const _parcelleBorder= Color(0xFF60A5FA);
const _hoverFill     = Color(0x88FCD34D);
const _hoverBorder   = Color(0xFFFCD34D);

// ── Panel mode ─────────────────────────────────────────────────
enum _PanelMode { list, createForest, createParcelle, editForest }

class AdminForestsScreen extends ConsumerStatefulWidget {
  const AdminForestsScreen({super.key});

  @override
  ConsumerState<AdminForestsScreen> createState() => _AdminForestsScreenState();
}

class _AdminForestsScreenState extends ConsumerState<AdminForestsScreen> {
  final _mapController = MapController();

  // Panel
  bool        _panelOpen      = true;
  _PanelMode  _panelMode      = _PanelMode.list;
  String?     _expandedForestId;

  // Drawing state (shared between create forest & create parcelle)
  final List<LatLng> _drawPoints = [];
  bool               _isDrawing  = false;
  String?            _drawingForestId; // for parcelle mode

  // Hover / tooltip
  String?   _hoveredForestId;
  String?   _hoveredParcelleId;
  Forest?   _tooltipForest;
  Parcelle? _tooltipParcelle;
  Offset    _tooltipOffset = Offset.zero;

  // Form state
  final _nameCtrl        = TextEditingController();
  final _formKey         = GlobalKey<FormState>();
  bool    _isSubmitting  = false;
  String? _formError;

  // Edit mode
  Forest? _editingForest;
  bool    _polygonChanged = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(forestListProvider.notifier).loadForests();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Drawing helpers ───────────────────────────────────────────

  bool get _isClosed =>
      _drawPoints.length >= 3 &&
      _drawPoints.first.latitude  == _drawPoints.last.latitude &&
      _drawPoints.first.longitude == _drawPoints.last.longitude;

  bool get _canClose => _drawPoints.length >= 3 && !_isClosed;

  void _onMapTap(_, LatLng point) {
    if (!_isDrawing || _isClosed) return;
    setState(() => _drawPoints.add(point));
  }

  void _closePolygon() {
    if (!_canClose) return;
    setState(() => _drawPoints.add(_drawPoints.first));
  }

  void _undoPoint() {
    if (_drawPoints.isEmpty) return;
    setState(() => _drawPoints.removeLast());
  }

  void _clearDraw() => setState(() { _drawPoints.clear(); _isDrawing = false; });

  Map<String, dynamic> _buildGeoJSON() {
    final coords = _drawPoints.map((p) => [p.longitude, p.latitude]).toList();
    return {'type': 'Polygon', 'coordinates': [coords]};
  }

  // ── Panel mode transitions ─────────────────────────────────────

  void _openCreateForest() {
    _nameCtrl.clear();
    _drawPoints.clear();
    setState(() {
      _panelMode      = _PanelMode.createForest;
      _panelOpen      = true;
      _isDrawing      = false;
      _isSubmitting   = false;
      _formError      = null;
      _editingForest  = null;
      _polygonChanged = false;
    });
  }

  void _openEditForest(Forest forest) {
    _nameCtrl.text = forest.name;
    final pts = forest.geojson.latLngList
        .map((p) => LatLng(p[0], p[1]))
        .toList();
    setState(() {
      _drawPoints.clear();
      _drawPoints.addAll(pts);
      _panelMode      = _PanelMode.editForest;
      _panelOpen      = true;
      _isDrawing      = false;
      _isSubmitting   = false;
      _formError      = null;
      _editingForest  = forest;
      _polygonChanged = false;
      _tooltipForest  = null;
    });
    // Fly to forest
    if (forest.centroidLat != null) {
      _mapController.move(
          LatLng(forest.centroidLat!, forest.centroidLng!), 11.0);
    }
  }

  void _openCreateParcelle(Forest forest) {
    _nameCtrl.clear();
    _drawPoints.clear();
    setState(() {
      _panelMode       = _PanelMode.createParcelle;
      _panelOpen       = true;
      _isDrawing       = false;
      _isSubmitting    = false;
      _formError       = null;
      _drawingForestId = forest.id;
    });
    // Fly to forest
    if (forest.centroidLat != null) {
      _mapController.move(
          LatLng(forest.centroidLat!, forest.centroidLng!), 11.0);
    }
  }

  void _backToList() {
    _drawPoints.clear();
    _nameCtrl.clear();
    setState(() {
      _panelMode      = _PanelMode.list;
      _isDrawing      = false;
      _formError      = null;
      _editingForest  = null;
      _polygonChanged = false;
    });
  }

  // ── Submit create forest ───────────────────────────────────────

  Future<void> _submitCreateForest() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isClosed) {
      setState(() => _formError =
          'Fermez le polygone avant d\'enregistrer (min. 3 points).');
      return;
    }
    setState(() { _isSubmitting = true; _formError = null; });
    try {
      final forest = await ref
          .read(forestListProvider.notifier)
          .createForest(name: _nameCtrl.text.trim(), geojson: _buildGeoJSON());

      if (forest != null && mounted) {
        _showSuccess('Forêt « ${forest.name} » créée');
        _backToList();
      } else {
        setState(() =>
            _formError = ref.read(forestListProvider).error ?? 'Erreur');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Submit edit forest ─────────────────────────────────────────

  Future<void> _submitEditForest() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isClosed) {
      setState(() => _formError = 'Fermez le polygone avant d\'enregistrer.');
      return;
    }
    setState(() { _isSubmitting = true; _formError = null; });
    try {
      final updated = await ref
          .read(forestListProvider.notifier)
          .updateForest(
            _editingForest!.id,
            name:    _nameCtrl.text.trim(),
            geojson: _polygonChanged ? _buildGeoJSON() : null,
          );

      if (updated != null && mounted) {
        _showSuccess('Forêt « ${updated.name} » mise à jour');
        _backToList();
      } else {
        setState(() =>
            _formError = ref.read(forestListProvider).error ?? 'Erreur');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Submit create parcelle ─────────────────────────────────────

  Future<void> _submitCreateParcelle() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isClosed) {
      setState(() => _formError = 'Fermez le polygone de la parcelle.');
      return;
    }
    setState(() { _isSubmitting = true; _formError = null; });
    try {
      final p = await ref
          .read(parcelleProvider.notifier)
          .createParcelle(
            forestId: _drawingForestId!,
            name:     _nameCtrl.text.trim(),
            geojson:  _buildGeoJSON(),
          );

      if (p != null && mounted) {
        _showSuccess('Parcelle « ${p.name} » créée');
        _backToList();
      } else {
        setState(() =>
            _formError = ref.read(parcelleProvider).error ?? 'Erreur');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Delete forest ──────────────────────────────────────────────

  Future<void> _confirmDeleteForest(Forest forest) async {
    final ok = await _showDeleteDialog(
      title: 'Supprimer la forêt',
      name:  forest.name,
      extra: 'Toutes ses parcelles seront supprimées.',
    );
    if (ok == true) {
      await ref.read(forestListProvider.notifier).deleteForest(forest.id);
      setState(() { _tooltipForest = null; _hoveredForestId = null; });
    }
  }

  Future<void> _confirmDeleteParcelle(Parcelle p) async {
    final ok = await _showDeleteDialog(
      title: 'Supprimer la parcelle',
      name:  p.name,
    );
    if (ok == true) {
      await ref.read(parcelleProvider.notifier)
          .deleteParcelle(p.id, p.forestId);
      setState(() { _tooltipParcelle = null; _hoveredParcelleId = null; });
    }
  }

  Future<bool?> _showDeleteDialog({
    required String title,
    required String name,
    String? extra,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (_) => _DeleteDialog(title: title, name: name, extra: extra),
      );

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(msg),
      ]),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ── Expand / fly ───────────────────────────────────────────────

  void _toggleExpand(String forestId) {
    setState(() {
      _expandedForestId =
          _expandedForestId == forestId ? null : forestId;
    });
    if (_expandedForestId == forestId) {
      final ps = ref.read(parcelleProvider);
      if (!ps.byForest.containsKey(forestId)) {
        ref.read(parcelleProvider.notifier).loadParcelles(forestId);
      }
    }
  }

  void _flyTo(Forest f) {
    if (f.centroidLat != null) {
      _mapController.move(LatLng(f.centroidLat!, f.centroidLng!), 12.0);
    }
  }

  // ── Polygon layers ─────────────────────────────────────────────

  List<Polygon> _buildPolygons(
      List<Forest> forests, ParcelleState ps) {
    final polygons = <Polygon>[];

    for (final f in forests) {
      final pts = f.geojson.latLngList
          .map((p) => LatLng(p[0], p[1]))
          .toList();
      if (pts.isEmpty) continue;
      final hov = _hoveredForestId == f.id;
      polygons.add(Polygon(
        points:            pts,
        color:             hov ? _hoverFill    : _forestFill,
        borderColor:       hov ? _hoverBorder  : _forestBorder,
        borderStrokeWidth: hov ? 2.5 : 1.8,
        isFilled:          true,
      ));

      for (final p in ps.forForest(f.id)) {
        final pPts = p.geojson.latLngList
            .map((pt) => LatLng(pt[0], pt[1]))
            .toList();
        if (pPts.isEmpty) continue;
        final pHov = _hoveredParcelleId == p.id;
        polygons.add(Polygon(
          points:            pPts,
          color:             pHov ? _hoverFill    : _parcelleFill,
          borderColor:       pHov ? _hoverBorder  : _parcelleBorder,
          borderStrokeWidth: pHov ? 2.5 : 1.5,
          isFilled:          true,
        ));
      }
    }

    // Drawing preview
    final closedDraw = _isClosed ? _drawPoints : <LatLng>[];
    if (closedDraw.length >= 3) {
      final isForest = _panelMode == _PanelMode.createForest ||
          _panelMode == _PanelMode.editForest;
      polygons.add(Polygon(
        points:            closedDraw,
        color:             isForest
            ? const Color(0x7722C55E)
            : const Color(0x7760A5FA),
        borderColor:       isForest
            ? _forestBorder
            : _parcelleBorder,
        borderStrokeWidth: 2.0,
        isFilled:          true,
      ));
    }

    // Parent forest highlight in parcelle mode
    if (_panelMode == _PanelMode.createParcelle &&
        _drawingForestId != null) {
      try {
        final pf = forests.firstWhere((f) => f.id == _drawingForestId);
        final pts = pf.geojson.latLngList
            .map((p) => LatLng(p[0], p[1]))
            .toList();
        if (pts.length >= 3) {
          polygons.add(Polygon(
            points:            pts,
            color:             const Color(0x2222C55E),
            borderColor:       _forestBorder,
            borderStrokeWidth: 2.5,
            isFilled:          true,
          ));
        }
      } catch (_) {}
    }

    return polygons;
  }

  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final forestState = ref.watch(forestListProvider);
    final ps          = ref.watch(parcelleProvider);
    final forests     = forestState.forests;

    ref.listen<ForestListState>(forestListProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.error!),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
        ref.read(forestListProvider.notifier).clearError();
      }
    });

    final openPts = _isClosed ? <LatLng>[] : _drawPoints;

    return Stack(children: [
      // ── MAP ──────────────────────────────────────────────────
      FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _tunisiaCenter,
          initialZoom:   _initialZoom,
          minZoom: 4.0,
          maxZoom: 19.0,
          onTap: _onMapTap,
        ),
        children: [
          // Satellite tiles
          TileLayer(
            urlTemplate:         _satelliteUrl,
            userAgentPackageName:'com.ghabetna.forest_app',
            maxZoom:             19,
          ),

          // Polygons (forests + parcelles + drawing preview)
          PolygonLayer(polygons: _buildPolygons(forests, ps)),

          // Open polyline while drawing
          if (openPts.length >= 2)
            PolylineLayer(polylines: [
              Polyline(
                points:      openPts,
                color:       _panelMode == _PanelMode.createParcelle
                    ? _parcelleBorder
                    : _forestBorder,
                strokeWidth: 2.0,
                isDotted:    true,
              ),
            ]),

          // Draw point markers
          if (_drawPoints.isNotEmpty)
            MarkerLayer(
              markers: _drawPoints.asMap().entries.map((e) {
                final isFirst = e.key == 0;
                return Marker(
                  point:  e.value,
                  width:  isFirst ? 20 : 12,
                  height: isFirst ? 20 : 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isFirst ? Colors.white : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _panelMode == _PanelMode.createParcelle
                            ? _parcelleBorder
                            : _forestBorder,
                        width: 2.5,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

          // Forest centroid markers (hover targets)
          for (final f in forests)
            if (f.centroidLat != null)
              MarkerLayer(markers: [
                Marker(
                  point:  LatLng(f.centroidLat!, f.centroidLng!),
                  width:  36, height: 36,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (e) => setState(() {
                      _hoveredForestId   = f.id;
                      _hoveredParcelleId = null;
                      _tooltipForest     = f;
                      _tooltipParcelle   = null;
                      _tooltipOffset     = e.position;
                    }),
                    onExit: (_) =>
                        setState(() => _hoveredForestId = null),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _tooltipForest   = f;
                          _tooltipParcelle = null;
                          _tooltipOffset   = Offset(
                            MediaQuery.of(context).size.width / 2,
                            MediaQuery.of(context).size.height / 2,
                          );
                        });
                      },
                      child: _ForestMarker(isHovered: _hoveredForestId == f.id),
                    ),
                  ),
                ),
              ]),

          // Parcelle centroid markers
          for (final fId in ps.byForest.keys)
            for (final p in ps.forForest(fId))
              if (p.centroidLat != null)
                MarkerLayer(markers: [
                  Marker(
                    point:  LatLng(p.centroidLat!, p.centroidLng!),
                    width:  28, height: 28,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (e) => setState(() {
                        _hoveredParcelleId = p.id;
                        _hoveredForestId   = null;
                        _tooltipParcelle   = p;
                        _tooltipForest     = null;
                        _tooltipOffset     = e.position;
                      }),
                      onExit: (_) =>
                          setState(() => _hoveredParcelleId = null),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _tooltipParcelle = p;
                            _tooltipForest   = null;
                            _tooltipOffset   = Offset(
                              MediaQuery.of(context).size.width / 2,
                              MediaQuery.of(context).size.height / 2,
                            );
                          });
                        },
                        child: _ParcelleMarker(
                            isHovered: _hoveredParcelleId == p.id),
                      ),
                    ),
                  ),
                ]),

          const RichAttributionWidget(
            attributions: [
              TextSourceAttribution('Esri, Maxar, Earthstar Geographics'),
            ],
          ),
        ],
      ),

      // ── SIDE PANEL ────────────────────────────────────────────
      Positioned(
        top: 0, bottom: 0, right: 0,
        child: _SidePanel(
          isOpen:           _panelOpen,
          mode:             _panelMode,
          // list props
          forests:          forests,
          parcelleState:    ps,
          isLoading:        forestState.isLoading,
          expandedForestId: _expandedForestId,
          deletingIds:      forestState.deletingIds,
          onTogglePanel:    () => setState(() => _panelOpen = !_panelOpen),
          onForestTap:      _flyTo,
          onForestExpand:   _toggleExpand,
          onForestEdit:     _openEditForest,
          onForestDelete:   _confirmDeleteForest,
          onParcelleEdit:   (p) {/* TODO edit parcelle */},
          onParcelleDelete: _confirmDeleteParcelle,
          onCreateForest:   _openCreateForest,
          onCreateParcelle: _openCreateParcelle,
          // form props
          nameCtrl:         _nameCtrl,
          formKey:          _formKey,
          isDrawing:        _isDrawing,
          isClosed:         _isClosed,
          canClose:         _canClose,
          pointCount:       _drawPoints.length,
          isSubmitting:     _isSubmitting,
          formError:        _formError,
          polygonChanged:   _polygonChanged,
          editingForest:    _editingForest,
          onDismissError:   () => setState(() => _formError = null),
          onToggleDraw:     () => setState(() => _isDrawing = !_isDrawing),
          onClosePolygon:   _closePolygon,
          onUndoPoint:      _undoPoint,
          onClearDraw:      _clearDraw,
          onStartRedraw:    () => setState(() {
            _drawPoints.clear();
            _isDrawing      = true;
            _polygonChanged = true;
          }),
          onResetPolygon:   () {
            if (_editingForest == null) return;
            final pts = _editingForest!.geojson.latLngList
                .map((p) => LatLng(p[0], p[1]))
                .toList();
            setState(() {
              _drawPoints.clear();
              _drawPoints.addAll(pts);
              _isDrawing      = false;
              _polygonChanged = false;
            });
          },
          onSubmitCreate:   _submitCreateForest,
          onSubmitEdit:     _submitEditForest,
          onSubmitParcelle: _submitCreateParcelle,
          onBack:           _backToList,
          drawingForestName: _drawingForestId != null
              ? forests.where((f) => f.id == _drawingForestId)
                  .map((f) => f.name)
                  .firstOrNull
              : null,
        ),
      ),

      // ── TOOLTIP ───────────────────────────────────────────────
      if (_tooltipForest != null)
        _MapTooltip(
          offset:   _tooltipOffset,
          title:    _tooltipForest!.name,
          subtitle: _tooltipForest!.areaLabel,
          icon:     Icons.park_outlined,
          color:    const Color(0xFF22C55E),
          onEdit:   () { _openEditForest(_tooltipForest!); },
          onDelete: () => _confirmDeleteForest(_tooltipForest!),
          onClose:  () => setState(() => _tooltipForest = null),
        ),

      if (_tooltipParcelle != null)
        _MapTooltip(
          offset:   _tooltipOffset,
          title:    _tooltipParcelle!.name,
          subtitle: _tooltipParcelle!.areaLabel,
          icon:     Icons.crop_square_outlined,
          color:    const Color(0xFF60A5FA),
          onEdit:   () {/* TODO */},
          onDelete: () => _confirmDeleteParcelle(_tooltipParcelle!),
          onClose:  () => setState(() => _tooltipParcelle = null),
        ),

      // ── Loading chip ──────────────────────────────────────────
      if (forestState.isLoading)
        const Positioned(
          top: 12, left: 0, right: 0,
          child: Center(child: _LoadingChip()),
        ),

      // ── Drawing hint ──────────────────────────────────────────
      if (_isDrawing && _drawPoints.isEmpty)
        const Center(child: _DrawingHint()),

      // ── Draw counter chip ─────────────────────────────────────
      if (_drawPoints.isNotEmpty)
        Positioned(
          bottom: 32, left: 16,
          child: _DrawCounter(
            count:    _drawPoints.length,
            isClosed: _isClosed,
            isParc:   _panelMode == _PanelMode.createParcelle,
          ),
        ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
//  SIDE PANEL  — contient LIST ou FORM selon le mode
// ═══════════════════════════════════════════════════════════════

class _SidePanel extends StatefulWidget {
  // panel toggle
  final bool        isOpen;
  final _PanelMode  mode;
  final VoidCallback onTogglePanel;

  // list
  final List<Forest>    forests;
  final ParcelleState   parcelleState;
  final bool            isLoading;
  final String?         expandedForestId;
  final Set<String>     deletingIds;
  final void Function(Forest)    onForestTap;
  final void Function(String)    onForestExpand;
  final void Function(Forest)    onForestEdit;
  final void Function(Forest)    onForestDelete;
  final void Function(Parcelle)  onParcelleEdit;
  final void Function(Parcelle)  onParcelleDelete;
  final VoidCallback             onCreateForest;
  final void Function(Forest)    onCreateParcelle;

  // form
  final TextEditingController  nameCtrl;
  final GlobalKey<FormState>   formKey;
  final bool       isDrawing;
  final bool       isClosed;
  final bool       canClose;
  final int        pointCount;
  final bool       isSubmitting;
  final String?    formError;
  final bool       polygonChanged;
  final Forest?    editingForest;
  final String?    drawingForestName;
  final VoidCallback onDismissError;
  final VoidCallback onToggleDraw;
  final VoidCallback onClosePolygon;
  final VoidCallback onUndoPoint;
  final VoidCallback onClearDraw;
  final VoidCallback onStartRedraw;
  final VoidCallback onResetPolygon;
  final VoidCallback onSubmitCreate;
  final VoidCallback onSubmitEdit;
  final VoidCallback onSubmitParcelle;
  final VoidCallback onBack;

  const _SidePanel({
    required this.isOpen,
    required this.mode,
    required this.onTogglePanel,
    required this.forests,
    required this.parcelleState,
    required this.isLoading,
    required this.expandedForestId,
    required this.deletingIds,
    required this.onForestTap,
    required this.onForestExpand,
    required this.onForestEdit,
    required this.onForestDelete,
    required this.onParcelleEdit,
    required this.onParcelleDelete,
    required this.onCreateForest,
    required this.onCreateParcelle,
    required this.nameCtrl,
    required this.formKey,
    required this.isDrawing,
    required this.isClosed,
    required this.canClose,
    required this.pointCount,
    required this.isSubmitting,
    required this.formError,
    required this.polygonChanged,
    required this.editingForest,
    required this.drawingForestName,
    required this.onDismissError,
    required this.onToggleDraw,
    required this.onClosePolygon,
    required this.onUndoPoint,
    required this.onClearDraw,
    required this.onStartRedraw,
    required this.onResetPolygon,
    required this.onSubmitCreate,
    required this.onSubmitEdit,
    required this.onSubmitParcelle,
    required this.onBack,
  });

  @override
  State<_SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<_SidePanel> {
  String _search = '';

  List<Forest> get _filtered {
    if (_search.isEmpty) return widget.forests;
    return widget.forests
        .where((f) => f.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Toggle tab
        Padding(
          padding: const EdgeInsets.only(top: 80),
          child: GestureDetector(
            onTap: widget.onTogglePanel,
            child: Container(
              width: 26,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(-2, 0),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isOpen
                        ? Icons.chevron_right
                        : Icons.chevron_left,
                    color: Colors.white, size: 16,
                  ),
                  const SizedBox(height: 8),
                  RotatedBox(
                    quarterTurns: 1,
                    child: Text(
                      'FORÊTS',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.7),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Panel body
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          width: widget.isOpen ? 310 : 0,
          child: widget.isOpen
              ? Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F1A12), // dark green-black for satellite
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x30000000),
                        blurRadius: 20,
                        offset: Offset(-4, 0),
                      ),
                    ],
                  ),
                  child: widget.mode == _PanelMode.list
                      ? _ListContent(
                          forests:          _filtered,
                          allForests:       widget.forests,
                          parcelleState:    widget.parcelleState,
                          isLoading:        widget.isLoading,
                          expandedForestId: widget.expandedForestId,
                          deletingIds:      widget.deletingIds,
                          search:           _search,
                          onSearchChanged:  (v) => setState(() => _search = v),
                          onForestTap:      widget.onForestTap,
                          onForestExpand:   widget.onForestExpand,
                          onForestEdit:     widget.onForestEdit,
                          onForestDelete:   widget.onForestDelete,
                          onParcelleEdit:   widget.onParcelleEdit,
                          onParcelleDelete: widget.onParcelleDelete,
                          onCreateForest:   widget.onCreateForest,
                          onCreateParcelle: widget.onCreateParcelle,
                        )
                      : _FormContent(
                          mode:             widget.mode,
                          nameCtrl:         widget.nameCtrl,
                          formKey:          widget.formKey,
                          isDrawing:        widget.isDrawing,
                          isClosed:         widget.isClosed,
                          canClose:         widget.canClose,
                          pointCount:       widget.pointCount,
                          isSubmitting:     widget.isSubmitting,
                          formError:        widget.formError,
                          polygonChanged:   widget.polygonChanged,
                          editingForest:    widget.editingForest,
                          drawingForestName:widget.drawingForestName,
                          onDismissError:   widget.onDismissError,
                          onToggleDraw:     widget.onToggleDraw,
                          onClosePolygon:   widget.onClosePolygon,
                          onUndoPoint:      widget.onUndoPoint,
                          onClearDraw:      widget.onClearDraw,
                          onStartRedraw:    widget.onStartRedraw,
                          onResetPolygon:   widget.onResetPolygon,
                          onSubmitCreate:   widget.onSubmitCreate,
                          onSubmitEdit:     widget.onSubmitEdit,
                          onSubmitParcelle: widget.onSubmitParcelle,
                          onBack:           widget.onBack,
                        ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ── List content ───────────────────────────────────────────────

class _ListContent extends StatelessWidget {
  final List<Forest>  forests;
  final List<Forest>  allForests;
  final ParcelleState parcelleState;
  final bool          isLoading;
  final String?       expandedForestId;
  final Set<String>   deletingIds;
  final String        search;
  final void Function(String)    onSearchChanged;
  final void Function(Forest)    onForestTap;
  final void Function(String)    onForestExpand;
  final void Function(Forest)    onForestEdit;
  final void Function(Forest)    onForestDelete;
  final void Function(Parcelle)  onParcelleEdit;
  final void Function(Parcelle)  onParcelleDelete;
  final VoidCallback             onCreateForest;
  final void Function(Forest)    onCreateParcelle;

  const _ListContent({
    required this.forests,
    required this.allForests,
    required this.parcelleState,
    required this.isLoading,
    required this.expandedForestId,
    required this.deletingIds,
    required this.search,
    required this.onSearchChanged,
    required this.onForestTap,
    required this.onForestExpand,
    required this.onForestEdit,
    required this.onForestDelete,
    required this.onParcelleEdit,
    required this.onParcelleDelete,
    required this.onCreateForest,
    required this.onCreateParcelle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: const BoxDecoration(
          color: Color(0xFF1A3020),
          border: Border(
              bottom: BorderSide(color: Color(0xFF2A4030), width: 0.5)),
        ),
        child: Row(children: [
          const Icon(Icons.park_outlined,
              color: Color(0xFF22C55E), size: 18),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Forêts · Tunisie',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: Colors.white)),
            Text('${allForests.length} forêt${allForests.length != 1 ? 's' : ''}',
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.5))),
          ]),
          const Spacer(),
          _SatBtn(
            label: '+ Forêt',
            color: const Color(0xFF22C55E),
            onTap: onCreateForest,
          ),
        ]),
      ),

      // Search
      Padding(
        padding: const EdgeInsets.all(12),
        child: _SatSearchField(
          value: search, onChanged: onSearchChanged),
      ),

      // List
      Expanded(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF22C55E), strokeWidth: 2))
            : forests.isEmpty
                ? _EmptyList(hasSearch: search.isNotEmpty)
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: forests.length,
                    itemBuilder: (_, i) {
                      final f = forests[i];
                      return _ForestItem(
                        forest:           f,
                        isDeleting:       deletingIds.contains(f.id),
                        isExpanded:       expandedForestId == f.id,
                        parcelles:        parcelleState.forForest(f.id),
                        isLoadingParc:    parcelleState.loadingIds.contains(f.id),
                        onTap:            () => onForestTap(f),
                        onExpand:         () => onForestExpand(f.id),
                        onEdit:           () => onForestEdit(f),
                        onDelete:         () => onForestDelete(f),
                        onParcelleEdit:   onParcelleEdit,
                        onParcelleDelete: onParcelleDelete,
                        onCreateParcelle: () => onCreateParcelle(f),
                      );
                    },
                  ),
      ),
    ]);
  }
}

// ── Form content ───────────────────────────────────────────────

class _FormContent extends StatelessWidget {
  final _PanelMode             mode;
  final TextEditingController  nameCtrl;
  final GlobalKey<FormState>   formKey;
  final bool     isDrawing;
  final bool     isClosed;
  final bool     canClose;
  final int      pointCount;
  final bool     isSubmitting;
  final String?  formError;
  final bool     polygonChanged;
  final Forest?  editingForest;
  final String?  drawingForestName;
  final VoidCallback onDismissError;
  final VoidCallback onToggleDraw;
  final VoidCallback onClosePolygon;
  final VoidCallback onUndoPoint;
  final VoidCallback onClearDraw;
  final VoidCallback onStartRedraw;
  final VoidCallback onResetPolygon;
  final VoidCallback onSubmitCreate;
  final VoidCallback onSubmitEdit;
  final VoidCallback onSubmitParcelle;
  final VoidCallback onBack;

  const _FormContent({
    required this.mode,
    required this.nameCtrl,
    required this.formKey,
    required this.isDrawing,
    required this.isClosed,
    required this.canClose,
    required this.pointCount,
    required this.isSubmitting,
    required this.formError,
    required this.polygonChanged,
    required this.editingForest,
    required this.drawingForestName,
    required this.onDismissError,
    required this.onToggleDraw,
    required this.onClosePolygon,
    required this.onUndoPoint,
    required this.onClearDraw,
    required this.onStartRedraw,
    required this.onResetPolygon,
    required this.onSubmitCreate,
    required this.onSubmitEdit,
    required this.onSubmitParcelle,
    required this.onBack,
  });

  String get _title => switch (mode) {
        _PanelMode.createForest   => 'Nouvelle forêt',
        _PanelMode.editForest     => 'Modifier la forêt',
        _PanelMode.createParcelle => 'Nouvelle parcelle',
        _PanelMode.list           => '',
      };

  String get _subtitle => switch (mode) {
        _PanelMode.createForest   => 'Dessinez le polygone sur la carte',
        _PanelMode.editForest     => editingForest?.name ?? '',
        _PanelMode.createParcelle =>
            drawingForestName != null ? 'Forêt : $drawingForestName' : '',
        _PanelMode.list => '',
      };

  Color get _accentColor => mode == _PanelMode.createParcelle
      ? const Color(0xFF60A5FA)
      : const Color(0xFF22C55E);

  VoidCallback get _onSubmit => switch (mode) {
        _PanelMode.createForest   => onSubmitCreate,
        _PanelMode.editForest     => onSubmitEdit,
        _PanelMode.createParcelle => onSubmitParcelle,
        _PanelMode.list           => onBack,
      };

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A3020),
          border: Border(
              bottom: BorderSide(
                  color: _accentColor.withOpacity(0.3), width: 0.5)),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                    color: Colors.white.withOpacity(0.15), width: 0.5),
              ),
              child: const Icon(Icons.arrow_back,
                  size: 15, color: Colors.white70),
            ),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: Colors.white)),
            if (_subtitle.isNotEmpty)
              Text(_subtitle,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.5))),
          ]),
          const Spacer(),
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              mode == _PanelMode.createParcelle
                  ? Icons.crop_square_outlined
                  : Icons.park_outlined,
              size: 14,
              color: _accentColor,
            ),
          ),
        ]),
      ),

      // Form body
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Error banner
                if (formError != null) ...[
                  _DarkErrorBanner(
                      message: formError!, onDismiss: onDismissError),
                  const SizedBox(height: 14),
                ],

                // Info for parcelle
                if (mode == _PanelMode.createParcelle) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF60A5FA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF60A5FA).withOpacity(0.3),
                          width: 0.5),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline,
                          size: 13, color: Color(0xFF60A5FA)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dessinez à l\'intérieur de la forêt parente (contour vert).',
                          style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF93C5FD)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                ],

                // Polygon changed badge
                if (mode == _PanelMode.editForest && polygonChanged) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppColors.warning.withOpacity(0.4),
                          width: 0.5),
                    ),
                    child: const Row(children: [
                      Icon(Icons.edit, size: 11, color: AppColors.warning),
                      SizedBox(width: 6),
                      Text('Polygone modifié',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  const SizedBox(height: 14),
                ],

                // Name label
                Text('Nom *',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.6))),
                const SizedBox(height: 6),

                // Name field
                TextFormField(
                  controller: nameCtrl,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.white),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Champ requis'
                      : null,
                  decoration: InputDecoration(
                    hintText: mode == _PanelMode.createParcelle
                        ? 'Ex : Parcelle Nord-Est'
                        : 'Ex : Forêt de Béja',
                    hintStyle: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.3)),
                    prefixIcon: Icon(
                      mode == _PanelMode.createParcelle
                          ? Icons.crop_square_outlined
                          : Icons.park_outlined,
                      size: 16,
                      color: _accentColor.withOpacity(0.7),
                    ),
                    filled:    true,
                    fillColor: Colors.white.withOpacity(0.07),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                          width: 0.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                          width: 0.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: _accentColor, width: 1.2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: AppColors.danger, width: 0.8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    isDense: true,
                  ),
                ),

                const SizedBox(height: 20),

                // Draw tools label
                Text('Polygone *',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.6))),
                const SizedBox(height: 10),

                // Drawing tools grid
                _DrawToolsGrid(
                  isDrawing:      isDrawing,
                  isClosed:       isClosed,
                  canClose:       canClose,
                  pointCount:     pointCount,
                  polygonChanged: polygonChanged,
                  isEditMode:     mode == _PanelMode.editForest,
                  accentColor:    _accentColor,
                  onToggleDraw:   onToggleDraw,
                  onClosePolygon: onClosePolygon,
                  onUndoPoint:    onUndoPoint,
                  onClearDraw:    onClearDraw,
                  onStartRedraw:  onStartRedraw,
                  onResetPolygon: onResetPolygon,
                ),

                const SizedBox(height: 16),

                // Status indicator
                _PolygonStatus(
                  pointCount: pointCount,
                  isClosed:   isClosed,
                  isDrawing:  isDrawing,
                  accentColor:_accentColor,
                ),

                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isSubmitting ? null : _onSubmit,
                    icon: isSubmitting
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_outlined, size: 16),
                    label: Text(isSubmitting
                        ? 'Enregistrement...'
                        : 'Enregistrer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isClosed
                          ? _accentColor
                          : Colors.white.withOpacity(0.15),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Cancel
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: isSubmitting ? null : onBack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white60,
                      side: BorderSide(
                          color: Colors.white.withOpacity(0.15), width: 0.8),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                    ),
                    child: const Text('Annuler', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ]);
  }
}

// ── Drawing tools grid ─────────────────────────────────────────

class _DrawToolsGrid extends StatelessWidget {
  final bool     isDrawing;
  final bool     isClosed;
  final bool     canClose;
  final int      pointCount;
  final bool     polygonChanged;
  final bool     isEditMode;
  final Color    accentColor;
  final VoidCallback onToggleDraw;
  final VoidCallback onClosePolygon;
  final VoidCallback onUndoPoint;
  final VoidCallback onClearDraw;
  final VoidCallback onStartRedraw;
  final VoidCallback onResetPolygon;

  const _DrawToolsGrid({
    required this.isDrawing,
    required this.isClosed,
    required this.canClose,
    required this.pointCount,
    required this.polygonChanged,
    required this.isEditMode,
    required this.accentColor,
    required this.onToggleDraw,
    required this.onClosePolygon,
    required this.onUndoPoint,
    required this.onClearDraw,
    required this.onStartRedraw,
    required this.onResetPolygon,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Edit mode : redraw / reset
        if (isEditMode) ...[
          if (!isDrawing)
            _DrawBtn(
              label:  'Redessiner',
              icon:   Icons.draw_outlined,
              color:  AppColors.warning,
              active: true,
              onTap:  onStartRedraw,
            ),
          if (polygonChanged)
            _DrawBtn(
              label:  'Réinitialiser',
              icon:   Icons.restore,
              color:  Colors.white54,
              active: true,
              onTap:  onResetPolygon,
            ),
        ],

        // Create mode : draw toggle
        if (!isEditMode || isDrawing)
          _DrawBtn(
            label:  isDrawing ? 'Arrêter' : 'Dessiner',
            icon:   isDrawing ? Icons.stop : Icons.edit_location_alt_outlined,
            color:  isDrawing ? AppColors.warning : accentColor,
            active: true,
            onTap:  onToggleDraw,
          ),

        // Close polygon
        _DrawBtn(
          label:  'Fermer',
          icon:   Icons.check_circle_outline,
          color:  canClose ? AppColors.success : Colors.white24,
          active: canClose,
          onTap:  canClose ? onClosePolygon : null,
        ),

        // Undo
        _DrawBtn(
          label:  'Annuler',
          icon:   Icons.undo,
          color:  pointCount > 0 ? AppColors.info : Colors.white24,
          active: pointCount > 0,
          onTap:  pointCount > 0 ? onUndoPoint : null,
        ),

        // Clear
        _DrawBtn(
          label:  'Effacer',
          icon:   Icons.delete_sweep_outlined,
          color:  pointCount > 0 ? AppColors.danger : Colors.white24,
          active: pointCount > 0,
          onTap:  pointCount > 0 ? onClearDraw : null,
        ),
      ],
    );
  }
}

class _DrawBtn extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final bool         active;
  final VoidCallback? onTap;

  const _DrawBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? color.withOpacity(0.15)
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: active
                  ? color.withOpacity(0.4)
                  : Colors.white.withOpacity(0.08),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: active ? color : Colors.white24),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: active ? color : Colors.white24)),
            ],
          ),
        ),
      );
}

class _PolygonStatus extends StatelessWidget {
  final int   pointCount;
  final bool  isClosed;
  final bool  isDrawing;
  final Color accentColor;
  const _PolygonStatus({
    required this.pointCount,
    required this.isClosed,
    required this.isDrawing,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (pointCount == 0) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: Colors.white.withOpacity(0.08), width: 0.5),
        ),
        child: const Row(children: [
          Icon(Icons.mouse_outlined, size: 13, color: Colors.white38),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Appuyez sur Dessiner puis cliquez sur la carte',
              style: TextStyle(fontSize: 10, color: Colors.white38),
            ),
          ),
        ]),
      );
    }

    final (statusText, color) = isClosed
        ? ('✓ Polygone fermé — $pointCount points', AppColors.success)
        : isDrawing
            ? ('$pointCount point${pointCount != 1 ? 's' : ''} — cliquez pour continuer',
                accentColor)
            : ('$pointCount points — appuyez sur Fermer', AppColors.warning);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Row(children: [
        Icon(
          isClosed ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 13, color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(statusText,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}

// ── Forest item ────────────────────────────────────────────────

class _ForestItem extends StatelessWidget {
  final Forest            forest;
  final bool              isDeleting;
  final bool              isExpanded;
  final List<Parcelle>    parcelles;
  final bool              isLoadingParc;
  final VoidCallback      onTap;
  final VoidCallback      onExpand;
  final VoidCallback      onEdit;
  final VoidCallback      onDelete;
  final void Function(Parcelle) onParcelleEdit;
  final void Function(Parcelle) onParcelleDelete;
  final VoidCallback      onCreateParcelle;

  const _ForestItem({
    required this.forest,
    required this.isDeleting,
    required this.isExpanded,
    required this.parcelles,
    required this.isLoadingParc,
    required this.onTap,
    required this.onExpand,
    required this.onEdit,
    required this.onDelete,
    required this.onParcelleEdit,
    required this.onParcelleDelete,
    required this.onCreateParcelle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isDeleting ? 0.4 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Column(children: [
        // Forest row
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF1E3528), width: 0.5)),
            ),
            child: Row(children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.park_outlined,
                    size: 15, color: Color(0xFF22C55E)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(forest.name,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: Colors.white),
                        overflow: TextOverflow.ellipsis),
                    Text(forest.areaLabel,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white38)),
                  ],
                ),
              ),
              _SatIconBtn(
                icon: Icons.edit_outlined,
                color: const Color(0xFF22C55E),
                onTap: isDeleting ? null : onEdit,
              ),
              const SizedBox(width: 4),
              _SatIconBtn(
                icon: Icons.delete_outline,
                color: AppColors.danger,
                onTap: isDeleting ? null : onDelete,
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onExpand,
                child: Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18, color: Colors.white38,
                ),
              ),
            ]),
          ),
        ),

        // Parcelles
        if (isExpanded)
          Container(
            color: const Color(0xFF0A1410),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                child: Row(children: [
                  Text('Parcelles',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.4),
                          letterSpacing: 0.8)),
                  const Spacer(),
                  GestureDetector(
                    onTap: onCreateParcelle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF60A5FA).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: const Color(0xFF60A5FA).withOpacity(0.3),
                            width: 0.5),
                      ),
                      child: const Row(children: [
                        Icon(Icons.add, size: 10, color: Color(0xFF60A5FA)),
                        SizedBox(width: 3),
                        Text('Ajouter',
                            style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFF60A5FA),
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ]),
              ),
              if (isLoadingParc)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF60A5FA)),
                  ),
                )
              else if (parcelles.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
                  child: Text('Aucune parcelle',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.25),
                          fontStyle: FontStyle.italic)),
                )
              else
                ...parcelles.map((p) => _ParcelleItem(
                      parcelle: p,
                      onEdit:   () => onParcelleEdit(p),
                      onDelete: () => onParcelleDelete(p),
                    )),
            ]),
          ),
      ]),
    );
  }
}

class _ParcelleItem extends StatelessWidget {
  final Parcelle     parcelle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ParcelleItem({required this.parcelle, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(22, 7, 14, 7),
        decoration: const BoxDecoration(
          border: Border(
              top: BorderSide(color: Color(0xFF1A2B1F), width: 0.5)),
        ),
        child: Row(children: [
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(
                color: Color(0xFF60A5FA), shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(parcelle.name,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: Colors.white70),
                  overflow: TextOverflow.ellipsis),
              Text(parcelle.areaLabel,
                  style: const TextStyle(
                      fontSize: 9, color: Colors.white30)),
            ]),
          ),
          _SatIconBtn(
            icon: Icons.edit_outlined,
            color: const Color(0xFF60A5FA),
            onTap: onEdit, size: 22,
          ),
          const SizedBox(width: 4),
          _SatIconBtn(
            icon: Icons.delete_outline,
            color: AppColors.danger,
            onTap: onDelete, size: 22,
          ),
        ]),
      );
}

// ── Small components ───────────────────────────────────────────

class _SatBtn extends StatelessWidget {
  final String label;
  final Color  color;
  final VoidCallback onTap;
  const _SatBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: color.withOpacity(0.4), width: 0.5),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w700)),
        ),
      );
}

class _SatIconBtn extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final VoidCallback? onTap;
  final double   size;
  const _SatIconBtn({required this.icon, required this.color, this.onTap, this.size = 26});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.25), width: 0.5),
          ),
          child: Icon(icon, size: size * 0.55, color: color),
        ),
      );
}

class _SatSearchField extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;
  const _SatSearchField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 34,
        child: TextField(
          onChanged: onChanged,
          style: const TextStyle(fontSize: 12, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Rechercher...',
            hintStyle: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3)),
            prefixIcon: Icon(Icons.search, size: 14,
                color: Colors.white.withOpacity(0.3)),
            filled:    true,
            fillColor: Colors.white.withOpacity(0.07),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.1), width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.1), width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(
                  color: Color(0xFF22C55E), width: 1.0),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 0),
            isDense: true,
          ),
        ),
      );
}

class _EmptyList extends StatelessWidget {
  final bool hasSearch;
  const _EmptyList({required this.hasSearch});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.park_outlined, size: 36,
                color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 10),
            Text(
              hasSearch ? 'Aucun résultat' : 'Aucune forêt',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.4)),
            ),
            if (!hasSearch) ...[
              const SizedBox(height: 4),
              Text('Créez la première forêt.',
                  style: TextStyle(
                      fontSize: 11, color: Colors.white.withOpacity(0.2))),
            ],
          ]),
        ),
      );
}

// ── Markers ────────────────────────────────────────────────────

class _ForestMarker extends StatelessWidget {
  final bool isHovered;
  const _ForestMarker({required this.isHovered});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: isHovered
              ? const Color(0xFFFCD34D)
              : const Color(0xFF22C55E),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 6, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.park, size: 16, color: Colors.white),
      );
}

class _ParcelleMarker extends StatelessWidget {
  final bool isHovered;
  const _ParcelleMarker({required this.isHovered});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: isHovered
              ? const Color(0xFFFCD34D)
              : const Color(0xFF60A5FA),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 4, offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Icon(Icons.crop_square, size: 12, color: Colors.white),
      );
}

// ── Map tooltip ────────────────────────────────────────────────

class _MapTooltip extends StatelessWidget {
  final Offset offset;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClose;
  const _MapTooltip({
    required this.offset,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onEdit,
    required this.onDelete,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final dx = offset.dx.clamp(8.0, MediaQuery.of(context).size.width - 230.0);
    final dy = (offset.dy - 130).clamp(8.0, MediaQuery.of(context).size.height - 150.0);
    return Positioned(
      left: dx, top: dy,
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF0F1A12),
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 0.8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 13, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: Colors.white),
                      overflow: TextOverflow.ellipsis),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.4))),
                ]),
              ),
              GestureDetector(
                  onTap: onClose,
                  child: Icon(Icons.close, size: 14,
                      color: Colors.white.withOpacity(0.4))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _TipBtn(
                  label: 'Modifier', icon: Icons.edit_outlined,
                  color: color, onTap: onEdit)),
              const SizedBox(width: 8),
              Expanded(child: _TipBtn(
                  label: 'Supprimer', icon: Icons.delete_outline,
                  color: AppColors.danger, onTap: onDelete)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _TipBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _TipBtn({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: color.withOpacity(0.3), width: 0.5),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      );
}

// ── Misc ───────────────────────────────────────────────────────

class _LoadingChip extends StatelessWidget {
  const _LoadingChip();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1A12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFF22C55E).withOpacity(0.4), width: 0.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3),
                blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF22C55E))),
          SizedBox(width: 8),
          Text('Chargement des forêts...',
              style: TextStyle(fontSize: 11, color: Colors.white60)),
        ]),
      );
}

class _DrawingHint extends StatelessWidget {
  const _DrawingHint();
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.white.withOpacity(0.15), width: 0.5),
          ),
          child: const Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.touch_app_outlined, color: Colors.white70, size: 28),
            SizedBox(height: 8),
            Text('Cliquez sur la carte pour placer des points',
                style: TextStyle(color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center),
            SizedBox(height: 4),
            Text('Puis appuyez sur Fermer pour finaliser',
                style: TextStyle(color: Colors.white54, fontSize: 10),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _DrawCounter extends StatelessWidget {
  final int count;
  final bool isClosed;
  final bool isParc;
  const _DrawCounter({required this.count, required this.isClosed, required this.isParc});

  @override
  Widget build(BuildContext context) {
    final color = isClosed
        ? AppColors.success
        : isParc ? const Color(0xFF60A5FA) : const Color(0xFF22C55E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3),
              blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Text(
        isClosed ? '✓ $count points' : '$count pt${count != 1 ? 's' : ''}',
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

class _DarkErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _DarkErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.12),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: AppColors.danger.withOpacity(0.4), width: 0.5),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 14, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(child: Text(message,
              style: const TextStyle(fontSize: 11, color: AppColors.danger))),
          GestureDetector(onTap: onDismiss,
              child: const Icon(Icons.close, size: 14, color: AppColors.danger)),
        ]),
      );
}

class _DeleteDialog extends StatelessWidget {
  final String title;
  final String name;
  final String? extra;
  const _DeleteDialog({required this.title, required this.name, this.extra});

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: const Color(0xFF0F1A12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.danger, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ]),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
                fontSize: 13, color: Colors.white60, height: 1.5),
            children: [
              const TextSpan(text: 'Supprimer '),
              TextSpan(text: name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.white)),
              const TextSpan(text: ' ? Action irréversible.'),
              if (extra != null)
                TextSpan(text: '\n$extra',
                    style: const TextStyle(color: AppColors.danger)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      );
}