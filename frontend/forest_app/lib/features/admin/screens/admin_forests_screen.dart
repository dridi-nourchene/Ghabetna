// features/admin/screens/admin_forests_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../features/alert/models/alert_map_model.dart';
import '../../../features/alert/providers/alert_map_provider.dart';
import '../../../features/forest/constants/forest_constant.dart';
import '../../../features/forest/models/forest_model.dart';
import '../../../features/forest/providers/forest_provider.dart';
import '../../../features/forest/widgets/forest_widgets.dart';
import '../../../features/forest/widgets/parcelle_widgets.dart';
import '../../../features/forest/widgets/shared_widgets.dart';
import 'dart:ui' as ui;

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

  // ── Alert popup ───────────────────────────────────────
  String? _selectedAlertId;

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
      ref.read(alertMapProvider.notifier).startPolling();
    });
  }

  @override
  void dispose() {
    ref.read(alertMapProvider.notifier).stopPolling();
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
    // Close alert popup on map tap
    if (_selectedAlertId != null) {
      setState(() => _selectedAlertId = null);
      ref.read(alertDetailProvider.notifier).clear();
      return;
    }
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
  //  Alert
  // ══════════════════════════════════════════════════════

  void _onAlertTap(String alertId) {
    // Close forest/parcelle popups when opening alert
    setState(() {
      _selectedAlertId = alertId;
      _hoveredForest   = null;
      _hoveredParcelle = null;
    });
    ref.read(alertDetailProvider.notifier).loadAlert(alertId);
  }

  void _closeAlertPopup() {
    setState(() => _selectedAlertId = null);
    ref.read(alertDetailProvider.notifier).clear();
  }

  LatLng? _resolveAlertPosition(AlertMapPoint point, List<Forest> forests) {
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

  List<Marker> _buildAlertMarkers(
      List<AlertMapPoint> points, List<Forest> forests) {
    final markers = <Marker>[];
    for (final point in points) {
      final position = _resolveAlertPosition(point, forests);
      if (position == null) continue;
      final isSelected = _selectedAlertId == point.id;
      markers.add(Marker(
        point:  position,
        width:  isSelected ? 48 : 36,
        height: isSelected ? 52 : 40,
        child: GestureDetector(
          onTap: () => _onAlertTap(point.id),
          child: _AlertTriangleMarker(
            type:          point.type,
            status:        point.status,
            isSelected:    isSelected,
            isApproximate: !point.hasExactLocation,
          ),
        ),
      ));
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
    final forestState  = ref.watch(forestListProvider);
    final ps           = ref.watch(parcelleProvider);
    final alertState   = ref.watch(alertMapProvider);
    final forests      = forestState.forests;
    final sidebarOpen  = _activeTab != ActiveTab.none;
    final openPts      = _isClosed ? <LatLng>[] : _drawPoints;

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
          // ── Alert markers on top ──────────────────────
          MarkerLayer(
              markers: _buildAlertMarkers(alertState.points, forests)),
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

      // ── Alert polling indicator (top-left) ───────────
      Positioned(
        top: 12, left: 12,
        child: _AlertPollingChip(
          alertState: alertState,
          onRefresh:  () =>
              ref.read(alertMapProvider.notifier).refreshNow(),
        ),
      ),

      // ── Alert detail popup ────────────────────────────
      if (_selectedAlertId != null)
        Positioned(
          top:  60,
          left: 12,
          child: _AlertDetailPanel(
            alertId:         _selectedAlertId!,
            onClose:         _closeAlertPopup,
            onStatusUpdated: () {
              ref.read(alertMapProvider.notifier).refreshNow();
            },
          ),
        ),

      // ── Alert legend (bottom-left) ────────────────────
      const Positioned(
        bottom: 28,
        left:   12,
        child:  _AlertLegend(),
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

// ══════════════════════════════════════════════════════════════
//  ALERT TRIANGLE MARKER
// ══════════════════════════════════════════════════════════════

class _AlertTriangleMarker extends StatelessWidget {
  final AlertType   type;
  final AlertStatus status;
  final bool        isSelected;
  final bool        isApproximate;

  const _AlertTriangleMarker({
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
    final size = isSelected ? 44.0 : 34.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          size: Size(size, size),
          painter: _TrianglePainter(color: _color, isSelected: isSelected),
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
        if (isApproximate)
          Positioned(
            top:   -4,
            right: -4,
            child: Container(
              width:  14,
              height: 14,
              decoration: BoxDecoration(
                color:  const Color(0xFFFF8F00),
                shape:  BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Center(
                child: Text('~',
                    style: TextStyle(
                        fontSize: 8,
                        color:    Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1)),
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

    canvas.drawPath(path.shift(const Offset(1.5, 2.5)), shadowPaint);
    canvas.drawPath(path, fillPaint);

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
//  ALERT POLLING CHIP
// ══════════════════════════════════════════════════════════════

class _AlertPollingChip extends StatelessWidget {
  final AlertMapState alertState;
  final VoidCallback  onRefresh;

  const _AlertPollingChip({
    required this.alertState,
    required this.onRefresh,
  });

  String get _lastRefreshText {
    final lr = alertState.lastRefresh;
    if (lr == null) return 'Chargement...';
    final diff = DateTime.now().difference(lr);
    if (diff.inSeconds < 60) return 'Il y a ${diff.inSeconds}s';
    return 'Il y a ${diff.inMinutes}min';
  }

  @override
  Widget build(BuildContext context) {
    final count = alertState.points
        .where((p) => p.status == AlertStatus.en_cours)
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: alertState.isLoading
                ? AppColors.warning
                : count > 0
                    ? AppColors.danger
                    : AppColors.success,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize:       MainAxisSize.min,
          children: [
            Text(
              count > 0
                  ? '$count alerte${count > 1 ? 's' : ''} en cours'
                  : 'Aucune alerte active',
              style: const TextStyle(
                  fontSize:   11,
                  fontWeight: FontWeight.w600,
                  color:      AppColors.textPrimary),
            ),
            Text(_lastRefreshText,
                style: const TextStyle(
                    fontSize: 9, color: AppColors.textMuted)),
          ],
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onRefresh,
          child: alertState.isLoading
              ? const SizedBox(
                  width:  13,
                  height: 13,
                  child:  CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primaryMid))
              : const Icon(Icons.refresh,
                  size: 14, color: AppColors.textMuted),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  ALERT LEGEND
// ══════════════════════════════════════════════════════════════

class _AlertLegend extends StatelessWidget {
  const _AlertLegend();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            const Text('Alertes',
                style: TextStyle(
                    fontSize:   10,
                    fontWeight: FontWeight.w700,
                    color:      AppColors.textSecondary,
                    letterSpacing: 0.3)),
            const SizedBox(height: 6),
            _LegendRow(color: const Color(0xFFD32F2F), label: 'En cours'),
            const SizedBox(height: 3),
            _LegendRow(color: const Color(0xFF388E3C), label: 'Traitée'),
            const SizedBox(height: 6),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 13, height: 13,
                decoration: const BoxDecoration(
                    color: Color(0xFFFF8F00), shape: BoxShape.circle),
                child: const Center(
                  child: Text('~',
                      style: TextStyle(
                          fontSize: 7,
                          color:    Colors.white,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 6),
              const Text('Position approx.',
                  style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
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
            size: const Size(14, 14),
            painter: _TrianglePainter(color: color, isSelected: false),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textPrimary)),
        ],
      );
}

// ══════════════════════════════════════════════════════════════
//  ALERT DETAIL PANEL — reused from admin_map_screen logic
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
  ConsumerState<_AlertDetailPanel> createState() =>
      _AlertDetailPanelState();
}

class _AlertDetailPanelState
    extends ConsumerState<_AlertDetailPanel> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String status) async {
    final ok = await ref
        .read(alertDetailProvider.notifier)
        .updateStatus(
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
      width:       310,
      constraints: const BoxConstraints(maxHeight: 520),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset:     const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: AppColors.borderLight, width: 0.5)),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color:        AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    size: 14, color: AppColors.danger),
              ),
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
                child: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color:        AppColors.bgInput,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.close,
                      size: 13, color: AppColors.textMuted),
                ),
              ),
            ]),
          ),
          // Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: state.isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: CircularProgressIndicator(
                            color:       AppColors.primaryMid,
                            strokeWidth: 2),
                      ))
                  : state.error != null
                      ? Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.danger, size: 28),
                              const SizedBox(height: 8),
                              Text(state.error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        )
                      : state.alert == null
                          ? const SizedBox.shrink()
                          : _AlertDetailBody(
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

class _AlertDetailBody extends StatelessWidget {
  final AlertDetail           alert;
  final TextEditingController commentController;
  final bool                  isUpdating;
  final void Function(String) onUpdate;

  const _AlertDetailBody({
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
          // Type + status
          Row(children: [
            Text(alert.type.emoji,
                style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert.type.label,
                        style: const TextStyle(
                            fontSize:   14,
                            fontWeight: FontWeight.w700,
                            color:      AppColors.textPrimary)),
                    Text(_formatDate(alert.createdAt),
                        style: const TextStyle(
                            fontSize: 9, color: AppColors.textMuted)),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:        _statusBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(alert.status.label,
                  style: TextStyle(
                      fontSize:   9,
                      fontWeight: FontWeight.w600,
                      color:      _statusColor)),
            ),
          ]),

          // Image
          if (alert.imageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                alert.imageUrl!,
                width:  double.infinity,
                height: 130,
                fit:    BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 40,
                  color:  AppColors.bgInput,
                  child:  const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
          ],

          // Description
          if (alert.description != null &&
              alert.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            const _SmallLabel('Description'),
            const SizedBox(height: 3),
            Text(alert.description!,
                style: const TextStyle(
                    fontSize: 11,
                    color:    AppColors.textSecondary,
                    height:   1.5)),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 10),

          // Location
          const _SmallLabel('Localisation'),
          const SizedBox(height: 5),
          _InfoRow(
            icon:  Icons.location_on_outlined,
            color: alert.locationSource == LocationSource.exif
                ? AppColors.success
                : AppColors.warning,
            text: switch (alert.locationSource) {
              LocationSource.exif        => 'GPS photo (précis)',
              LocationSource.agent_gps   => 'GPS téléphone',
              LocationSource.forest_only => 'Position approx. (centroïde)',
            },
          ),
          if (alert.incidentLat != null) ...[
            const SizedBox(height: 3),
            _InfoRow(
              icon:  Icons.my_location,
              color: AppColors.primaryMid,
              text:  '${alert.incidentLat!.toStringAsFixed(5)}, '
                     '${alert.incidentLng!.toStringAsFixed(5)}',
            ),
          ],
          if (alert.agentLat != null) ...[
            const SizedBox(height: 3),
            _InfoRow(
              icon:  Icons.person_pin_circle_outlined,
              color: AppColors.info,
              text:  'Agent : ${alert.agentLat!.toStringAsFixed(4)}, '
                     '${alert.agentLng!.toStringAsFixed(4)}',
            ),
          ],
          if (alert.distanceKm != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: alert.distanceKm! > 5
                    ? AppColors.danger.withOpacity(0.08)
                    : AppColors.successBg,
                borderRadius: BorderRadius.circular(7),
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
                  size:  11,
                  color: alert.distanceKm! > 5
                      ? AppColors.danger
                      : AppColors.success,
                ),
                const SizedBox(width: 5),
                Text(
                  '${alert.distanceKm!.toStringAsFixed(1)} km '
                  '${alert.distanceKm! > 5 ? '⚠️ Suspect' : '✓ OK'}',
                  style: TextStyle(
                      fontSize: 10,
                      color:    alert.distanceKm! > 5
                          ? AppColors.danger
                          : AppColors.success,
                      fontWeight: FontWeight.w500),
                ),
              ]),
            ),
          ],

          // Admin comment
          if (alert.adminComment != null &&
              alert.adminComment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 10),
            const _SmallLabel('Commentaire admin'),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:        AppColors.infoBg,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                    color: AppColors.info.withOpacity(0.3),
                    width: 0.5),
              ),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.admin_panel_settings_outlined,
                        size: 12, color: AppColors.info),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(alert.adminComment!,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.info)),
                    ),
                  ]),
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 10),

          // Actions
          if (alert.status == AlertStatus.en_cours) ...[
            const _SmallLabel('Décision'),
            const SizedBox(height: 6),
            TextField(
              controller: commentController,
              maxLines:   2,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText:  'Commentaire (optionnel)...',
                hintStyle: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted),
                filled:    true,
                fillColor: AppColors.bgInput,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide:   const BorderSide(
                      color: AppColors.border, width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide:   const BorderSide(
                      color: AppColors.border, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide:   const BorderSide(
                      color: AppColors.primaryMid, width: 1.0),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 7),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: _DecisionBtn(
                  label:     'Traiter',
                  icon:      Icons.check_circle_outline,
                  color:     AppColors.success,
                  isLoading: isUpdating,
                  onTap:     () => onUpdate('traiter'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _DecisionBtn(
                  label:     'Rejeter',
                  icon:      Icons.cancel_outlined,
                  color:     AppColors.textMuted,
                  isLoading: isUpdating,
                  onTap:     () => onUpdate('rejeter'),
                ),
              ),
            ]),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color:        _statusBg,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                    color: _statusColor.withOpacity(0.3), width: 0.5),
              ),
              child: Row(children: [
                Icon(
                  alert.status == AlertStatus.traiter
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  size:  13,
                  color: _statusColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'Alerte ${alert.status.label.toLowerCase()}',
                  style: TextStyle(
                      fontSize:   11,
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

class _SmallLabel extends StatelessWidget {
  final String text;
  const _SmallLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize:      9,
          fontWeight:    FontWeight.w700,
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
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
        ),
      ]);
}

class _DecisionBtn extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final bool         isLoading;
  final VoidCallback onTap;

  const _DecisionBtn({
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
                width: 11, height: 11,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Icon(icon, size: 13),
        label: Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor:         color,
          foregroundColor:         Colors.white,
          disabledBackgroundColor: color.withOpacity(0.4),
          elevation:               0,
          padding: const EdgeInsets.symmetric(vertical: 9),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7)),
        ),
      );
}