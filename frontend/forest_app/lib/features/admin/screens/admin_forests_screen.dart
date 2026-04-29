// features/admin/screens/admin_forests_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../features/forest/constants/forest_constant.dart';
import '../../../features/forest/models/forest_model.dart';
import '../../../features/forest/providers/forest_provider.dart';
import '../../../features/forest/widgets/forest_widgets.dart';
import '../../../features/forest/widgets/parcelle_widgets.dart';
import '../../../features/forest/widgets/shared_widgets.dart';

// ── Panel mode ─────────────────────────────────────────────────
enum PanelMode { list, createForest, editForest, createParcelle }

// ── Tab actif ─────────────────────────────────────────────────
enum ActiveTab { none, forests, parcelles }

class AdminForestsScreen extends ConsumerStatefulWidget {
  const AdminForestsScreen({super.key});

  @override
  ConsumerState<AdminForestsScreen> createState() =>
      _AdminForestsScreenState();
}

class _AdminForestsScreenState
    extends ConsumerState<AdminForestsScreen> {
  final _mapController = MapController();

  // ── Tab / panel ───────────────────────────────────────
  ActiveTab  _activeTab  = ActiveTab.none;
  PanelMode  _panelMode  = PanelMode.list;
  String?    _expandedForestId;

  // ── Hover popups ──────────────────────────────────────
  Forest?   _hoveredForest;
  Parcelle? _hoveredParcelle;

  // ── Drawing ───────────────────────────────────────────
  final List<LatLng> _drawPoints   = [];
  List<LatLng>       _oldPoints    = [];
  bool               _isDrawing    = false;
  bool               _polygonReady = false;

  // ── Form ──────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _formKey  = GlobalKey<FormState>();
  bool    _isSubmitting = false;
  String? _formError;

  // ── Edit ──────────────────────────────────────────────
  Forest? _editingForest;
  bool    _editHasNewPolygon = false;

  // ── Parcelle ──────────────────────────────────────────
  Forest? _selectedParentForest;

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

  // ══════════════════════════════════════════════════════
  //  Géométrie
  // ══════════════════════════════════════════════════════

  bool get _isClosed =>
      _drawPoints.length >= 3 &&
      _drawPoints.first.latitude  == _drawPoints.last.latitude &&
      _drawPoints.first.longitude == _drawPoints.last.longitude;

  bool get _canClose => _drawPoints.length >= 3 && !_isClosed;

  void _onMapTap(TapPosition _, LatLng pt) {
    if (!_isDrawing || _isClosed) return;
    setState(() => _drawPoints.add(pt));
  }

  void _closePolygon() {
    if (!_canClose) return;
    setState(() {
      _drawPoints.add(_drawPoints.first);
      _polygonReady = true;
    });
  }

  void _undoPoint() {
    if (_drawPoints.isEmpty) return;
    setState(() {
      _drawPoints.removeLast();
      _polygonReady = _isClosed;
    });
  }

  void _clearDraw() => setState(() {
        _drawPoints.clear();
        _isDrawing    = false;
        _polygonReady = false;
      });

  Map<String, dynamic> _buildGeoJSON(List<LatLng> pts) {
    final coords = pts.map((p) => [p.longitude, p.latitude]).toList();
    return {'type': 'Polygon', 'coordinates': [coords]};
  }

  // ══════════════════════════════════════════════════════
  //  Navigation sidebar
  // ══════════════════════════════════════════════════════

  void _toggleTab(ActiveTab tab) {
    setState(() {
      if (_activeTab == tab) {
        _activeTab = ActiveTab.none;
      } else {
        _activeTab = tab;
        _panelMode = PanelMode.list;
        _resetForm();
      }
    });
  }

  void _resetForm() {
    _nameCtrl.clear();
    _drawPoints.clear();
    _oldPoints.clear();
    _isDrawing            = false;
    _polygonReady         = false;
    _formError            = null;
    _editingForest        = null;
    _editHasNewPolygon    = false;
    _selectedParentForest = null;
  }

  void _openCreateForest() {
    _resetForm();
    setState(() {
      _activeTab = ActiveTab.forests;
      _panelMode = PanelMode.createForest;
    });
  }

  void _openEditForest(Forest f) {
    _resetForm();
    _nameCtrl.text = f.name;
    _editingForest = f;
    _oldPoints = f.geojson.latLngList
        .map((p) => LatLng(p[0], p[1]))
        .toList();
    setState(() {
      _activeTab = ActiveTab.forests;
      _panelMode = PanelMode.editForest;
    });
    _flyTo(f);
  }

  void _openCreateParcelle({Forest? parentForest}) {
    _resetForm();
    _selectedParentForest = parentForest;
    setState(() {
      _activeTab = ActiveTab.parcelles;
      _panelMode = PanelMode.createParcelle;
    });
    if (parentForest != null) _flyTo(parentForest);
  }

  void _backToList() {
    _resetForm();
    setState(() => _panelMode = PanelMode.list);
  }

  void _startRedraw() => setState(() {
        _drawPoints.clear();
        _isDrawing         = true;
        _polygonReady      = false;
        _editHasNewPolygon = true;
      });

  void _cancelRedraw() => setState(() {
        _drawPoints.clear();
        _isDrawing         = false;
        _polygonReady      = false;
        _editHasNewPolygon = false;
      });

  // ══════════════════════════════════════════════════════
  //  Submit
  // ══════════════════════════════════════════════════════

  Future<void> _submitCreateForest() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isClosed) {
      setState(() =>
          _formError = 'Fermez le polygone avant d\'enregistrer.');
      return;
    }
    setState(() { _isSubmitting = true; _formError = null; });
    try {
      final f = await ref
          .read(forestListProvider.notifier)
          .createForest(
              name:    _nameCtrl.text.trim(),
              geojson: _buildGeoJSON(_drawPoints));
      if (f != null && mounted) {
        _showSnack('Forêt « ${f.name} » créée', AppColors.success);
        _backToList();
      } else {
        setState(() =>
            _formError =
                ref.read(forestListProvider).error ?? 'Erreur');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitEditForest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_editHasNewPolygon && !_isClosed) {
      setState(() => _formError = 'Fermez le nouveau polygone.');
      return;
    }
    setState(() { _isSubmitting = true; _formError = null; });
    try {
      final updated = await ref
          .read(forestListProvider.notifier)
          .updateForest(
              _editingForest!.id,
              name:    _nameCtrl.text.trim(),
              geojson: _editHasNewPolygon
                  ? _buildGeoJSON(_drawPoints)
                  : null);
      if (updated != null && mounted) {
        _showSnack(
            'Forêt « ${updated.name} » mise à jour',
            AppColors.success);
        _backToList();
      } else {
        setState(() =>
            _formError =
                ref.read(forestListProvider).error ?? 'Erreur');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitCreateParcelle() async {
    if (_selectedParentForest == null) {
      setState(() => _formError = 'Choisissez une forêt parente.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (!_isClosed) {
      setState(
          () => _formError = 'Fermez le polygone de la parcelle.');
      return;
    }
    setState(() { _isSubmitting = true; _formError = null; });
    try {
      final p = await ref
          .read(parcelleProvider.notifier)
          .createParcelle(
              forestId: _selectedParentForest!.id,
              name:     _nameCtrl.text.trim(),
              geojson:  _buildGeoJSON(_drawPoints));
      if (p != null && mounted) {
        _showSnack(
            'Parcelle « ${p.name} » créée', AppColors.success);
        _backToList();
        ref
            .read(parcelleProvider.notifier)
            .loadParcelles(_selectedParentForest!.id);
      } else {
        setState(() =>
            _formError =
                ref.read(parcelleProvider).error ?? 'Erreur');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ══════════════════════════════════════════════════════
  //  Delete
  // ══════════════════════════════════════════════════════

  Future<void> _confirmDeleteForest(Forest f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteDialog(
          name:  f.name,
          extra: 'Toutes ses parcelles seront supprimées.'),
    );
    if (ok == true) {
      await ref.read(forestListProvider.notifier).deleteForest(f.id);
      setState(() => _hoveredForest = null);
    }
  }

  Future<void> _confirmDeleteParcelle(Parcelle p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteDialog(name: p.name),
    );
    if (ok == true) {
      await ref
          .read(parcelleProvider.notifier)
          .deleteParcelle(p.id, p.forestId);
      setState(() => _hoveredParcelle = null);
    }
  }

  // ══════════════════════════════════════════════════════
  //  Misc
  // ══════════════════════════════════════════════════════

  void _flyTo(Forest f) {
    if (f.centroidLat != null) {
      _mapController.move(
          LatLng(f.centroidLat!, f.centroidLng!), 11.0);
    }
  }

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

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline,
            color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(msg),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ══════════════════════════════════════════════════════
  //  Build polygones
  // ══════════════════════════════════════════════════════

  List<Polygon> _buildPolygons(
      List<Forest> forests, ParcelleState ps) {
    final list = <Polygon>[];
    for (final f in forests) {
      final isEditing = _panelMode == PanelMode.editForest &&
          _editingForest?.id == f.id;
      final pts = f.geojson.latLngList
          .map((p) => LatLng(p[0], p[1]))
          .toList();
      if (pts.isEmpty) continue;
      list.add(Polygon(
        points:            pts,
        color:             isEditing ? oldPolyFill   : forestFill,
        borderColor:       isEditing ? oldPolyBorder : forestBorder,
        borderStrokeWidth: isEditing ? 1.5 : 1.8,
        isFilled:          true,
      ));
      for (final p in ps.forForest(f.id)) {
        final pPts = p.geojson.latLngList
            .map((pt) => LatLng(pt[0], pt[1]))
            .toList();
        if (pPts.isEmpty) continue;
        list.add(Polygon(
          points:            pPts,
          color:             parcelleFill,
          borderColor:       parcelleBorder,
          borderStrokeWidth: 1.5,
          isFilled:          true,
        ));
      }
    }
    final closed = _isClosed ? _drawPoints : <LatLng>[];
    if (closed.length >= 3) {
      final isParc = _panelMode == PanelMode.createParcelle;
      list.add(Polygon(
        points:            closed,
        color:             isParc ? parcelleFill : newPolyFill,
        borderColor:       isParc ? parcelleBorder : newPolyBorder,
        borderStrokeWidth: 2.0,
        isFilled:          true,
      ));
    }
    return list;
  }

  // ══════════════════════════════════════════════════════
  //  Build markers
  // ══════════════════════════════════════════════════════

  List<Marker> _buildForestMarkers(List<Forest> forests) =>
      forests.where((f) => f.centroidLat != null).map((f) {
        final isEditing = _panelMode == PanelMode.editForest &&
            _editingForest?.id == f.id;
        return Marker(
          point:  LatLng(f.centroidLat!, f.centroidLng!),
          width:  160,
          height: 40,
          child: MouseRegion(
            cursor:  SystemMouseCursors.click,
            onEnter: (_) => setState(() {
              _hoveredForest   = f;
              _hoveredParcelle = null;
            }),
            onExit: (_) =>
                setState(() => _hoveredForest = null),
            child: GestureDetector(
              onTap: () => setState(() {
                _hoveredForest =
                    _hoveredForest?.id == f.id ? null : f;
                _hoveredParcelle = null;
              }),
              child: ForestLabel(
                  name: f.name, isEditing: isEditing),
            ),
          ),
        );
      }).toList();

  List<Marker> _buildParcelleMarkers(ParcelleState ps) {
    final markers = <Marker>[];
    for (final fId in ps.byForest.keys) {
      for (final p in ps.forForest(fId)) {
        if (p.centroidLat == null) continue;
        markers.add(Marker(
          point:  LatLng(p.centroidLat!, p.centroidLng!),
          width:  130,
          height: 32,
          child: MouseRegion(
            cursor:  SystemMouseCursors.click,
            onEnter: (_) => setState(() {
              _hoveredParcelle = p;
              _hoveredForest   = null;
            }),
            onExit: (_) =>
                setState(() => _hoveredParcelle = null),
            child: ParcelleLabel(name: p.name),
          ),
        ));
      }
    }
    return markers;
  }

  // ══════════════════════════════════════════════════════
  //  Panel content
  // ══════════════════════════════════════════════════════

  Widget _buildPanelContent(
      List<Forest> forests,
      ParcelleState ps,
      ForestListState forestState) {

    if (_activeTab == ActiveTab.forests) {
      return switch (_panelMode) {
        PanelMode.list => ForestListPanel(
            forests:          forests,
            parcelleState:    ps,
            isLoading:        forestState.isLoading,
            expandedForestId: _expandedForestId,
            deletingIds:      forestState.deletingIds,
            onForestTap:      _flyTo,
            onForestExpand:   _toggleExpand,
            onForestEdit:     _openEditForest,
            onForestDelete:   _confirmDeleteForest,
            onParcelleDelete: _confirmDeleteParcelle,
            onCreateForest:   _openCreateForest,
            onCreateParcelle: (f) =>
                _openCreateParcelle(parentForest: f),
          ),
        PanelMode.createForest => DrawFormPanel(
            key:          const ValueKey('create-forest'),
            title:        'Nouvelle forêt',
            subtitle:     'Dessinez le polygone sur la carte',
            fieldHint:    'Ex : Forêt de Béja',
            fieldIcon:    Icons.park_outlined,
            accentColor:  forestAccent,
            nameCtrl:     _nameCtrl,
            formKey:      _formKey,
            isDrawing:    _isDrawing,
            isClosed:     _isClosed,
            canClose:     _canClose,
            pointCount:   _drawPoints.length,
            isSubmitting: _isSubmitting,
            formError:    _formError,
            onDismissError: () =>
                setState(() => _formError = null),
            onToggleDraw: () =>
                setState(() => _isDrawing = !_isDrawing),
            onClose:  _closePolygon,
            onUndo:   _undoPoint,
            onClear:  _clearDraw,
            onSubmit: _submitCreateForest,
            onBack:   _backToList,
          ),
        PanelMode.editForest => EditForestPanel(
            forest:           _editingForest!,
            nameCtrl:         _nameCtrl,
            formKey:          _formKey,
            hasNewPolygon:    _editHasNewPolygon,
            isDrawing:        _isDrawing,
            isClosed:         _isClosed,
            canClose:         _canClose,
            pointCount:       _drawPoints.length,
            isSubmitting:     _isSubmitting,
            formError:        _formError,
            onDismissError:   () =>
                setState(() => _formError = null),
            onStartRedraw:    _startRedraw,
            onCancelRedraw:   _cancelRedraw,
            onToggleDraw:     () =>
                setState(() => _isDrawing = !_isDrawing),
            onClose:  _closePolygon,
            onUndo:   _undoPoint,
            onSubmit: _submitEditForest,
            onBack:   _backToList,
          ),
        _ => const SizedBox.shrink(),
      };
    }

    if (_activeTab == ActiveTab.parcelles) {
      return switch (_panelMode) {
        PanelMode.createParcelle => DrawFormPanel(
            key:          const ValueKey('create-parcelle'),
            title:        'Nouvelle parcelle',
            subtitle:     _selectedParentForest != null
                ? 'Forêt : ${_selectedParentForest!.name}'
                : 'Choisissez la forêt parente',
            fieldHint:    'Ex : Parcelle Nord-Est',
            fieldIcon:    Icons.crop_square_outlined,
            accentColor:  parcelleBorder,
            nameCtrl:     _nameCtrl,
            formKey:      _formKey,
            isDrawing:    _isDrawing,
            isClosed:     _isClosed,
            canClose:     _canClose,
            pointCount:   _drawPoints.length,
            isSubmitting: _isSubmitting,
            formError:    _formError,
            forestSelector: _selectedParentForest == null
                ? ForestSelector(
                    forests:  forests,
                    onSelect: (f) => setState(() {
                      _selectedParentForest = f;
                      _flyTo(f);
                    }),
                  )
                : null,
            onDismissError: () =>
                setState(() => _formError = null),
            onToggleDraw: () =>
                setState(() => _isDrawing = !_isDrawing),
            onClose:  _closePolygon,
            onUndo:   _undoPoint,
            onClear:  _clearDraw,
            onSubmit: _submitCreateParcelle,
            onBack:   _backToList,
          ),
        _ => ParcelleListPanel(
            forests:          forests,
            parcelleState:    ps,
            onCreateParcelle: _openCreateParcelle,
            onParcelleDelete: _confirmDeleteParcelle,
            onForestFly:      _flyTo,
          ),
      };
    }

    return const SizedBox.shrink();
  }

  // ══════════════════════════════════════════════════════
  //  Build
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final forestState = ref.watch(forestListProvider);
    final ps          = ref.watch(parcelleProvider);
    final forests     = forestState.forests;
    final sidebarOpen = _activeTab != ActiveTab.none;
    final openPts     = _isClosed ? <LatLng>[] : _drawPoints;

    ref.listen<ForestListState>(forestListProvider, (_, next) {
      if (next.error != null) {
        _showSnack(next.error!, AppColors.danger);
        ref.read(forestListProvider.notifier).clearError();
      }
    });
    ref.listen<ParcelleState>(parcelleProvider, (_, next) {
      if (next.error != null) {
        _showSnack(next.error!, AppColors.danger);
        ref.read(parcelleProvider.notifier).clearError();
      }
    });

    return Stack(children: [

      // ── Carte ────────────────────────────────────────
      FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: forestTunisiaCenter,
          initialZoom:   forestInitialZoom,
          minZoom: 4.0,
          maxZoom: 19.0,
          onTap: (tapPos, pt) {
            _onMapTap(tapPos, pt);
            if (_hoveredForest != null ||
                _hoveredParcelle != null) {
              setState(() {
                _hoveredForest   = null;
                _hoveredParcelle = null;
              });
            }
          },
        ),
        children: [
          TileLayer(
            urlTemplate:          forestTileUrl,
            subdomains:           const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.ghabetna.forest_app',
            maxZoom: 19,
          ),
          PolygonLayer(polygons: _buildPolygons(forests, ps)),
          if (openPts.length >= 2)
            PolylineLayer(polylines: [
              Polyline(
                points:      openPts,
                color:       _panelMode == PanelMode.createParcelle
                    ? parcelleBorder
                    : newPolyBorder,
                strokeWidth: 2.0,
                isDotted:    true,
              ),
            ]),
          if (_drawPoints.isNotEmpty)
            MarkerLayer(
                markers: _drawPoints.asMap().entries.map((e) {
              final isFirst = e.key == 0;
              return Marker(
                point:  e.value,
                width:  isFirst ? 18 : 12,
                height: isFirst ? 18 : 12,
                child: Container(
                  decoration: BoxDecoration(
                    color:  isFirst ? newPolyBorder : Colors.white,
                    shape:  BoxShape.circle,
                    border: Border.all(
                        color: newPolyBorder, width: 2),
                  ),
                ),
              );
            }).toList()),
          MarkerLayer(markers: _buildForestMarkers(forests)),
          MarkerLayer(markers: _buildParcelleMarkers(ps)),
          const RichAttributionWidget(attributions: [
            TextSourceAttribution('© CartoDB © OpenStreetMap'),
          ]),
        ],
      ),

      // ── Popup forêt ───────────────────────────────────
      if (_hoveredForest != null &&
          _hoveredForest!.centroidLat != null)
        ForestPopup(
          forest:   _hoveredForest!,
          onEdit:   () => _openEditForest(_hoveredForest!),
          onDelete: () => _confirmDeleteForest(_hoveredForest!),
          onClose:  () => setState(() => _hoveredForest = null),
        ),

      // ── Popup parcelle ────────────────────────────────
      if (_hoveredParcelle != null &&
          _hoveredParcelle!.centroidLat != null)
        ParcellePopup(
          parcelle: _hoveredParcelle!,
          onDelete: () =>
              _confirmDeleteParcelle(_hoveredParcelle!),
          onClose:  () =>
              setState(() => _hoveredParcelle = null),
        ),

      // ── Sidebar droite ────────────────────────────────
      Positioned(
        top: 0, bottom: 0, right: 0,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SideTab(
                  label:    'FORÊTS',
                  icon:     Icons.park_outlined,
                  color:    forestTabColor,
                  isActive: _activeTab == ActiveTab.forests,
                  isTop:    true,
                  onTap:    () => _toggleTab(ActiveTab.forests),
                ),
                SideTab(
                  label:    'PARCELLES',
                  icon:     Icons.crop_square_outlined,
                  color:    parcelleTabColor,
                  isActive: _activeTab == ActiveTab.parcelles,
                  isTop:    false,
                  onTap:    () => _toggleTab(ActiveTab.parcelles),
                ),
              ],
            ),
            // Panel
            AnimatedContainer(
              duration: const Duration(milliseconds: 230),
              curve:    Curves.easeInOut,
              width:    sidebarOpen ? 300 : 0,
              child: sidebarOpen
                  ? Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color:      Color(0x1A000000),
                            blurRadius: 16,
                            offset:     Offset(-4, 0),
                          ),
                        ],
                      ),
                      child: _buildPanelContent(
                          forests, ps, forestState),
                    )
                  : const SizedBox.shrink(),
            ),
            // Tabs empilés à droite
          ],
        ),
      ),

      // ── Overlays ──────────────────────────────────────
      if (forestState.isLoading)
        const Positioned(
          top: 12, left: 0, right: 0,
          child: Center(child: LoadingChip()),
        ),

      if (_isDrawing && _drawPoints.isEmpty)
        const Center(child: DrawHint()),

      if (_drawPoints.isNotEmpty)
        Positioned(
          bottom: 28, left: 0, right: 0,
          child: Center(
            child: DrawCounter(
              count:    _drawPoints.length,
              isClosed: _isClosed,
              isParc:   _panelMode == PanelMode.createParcelle,
            ),
          ),
        ),
    ]);
  }
}