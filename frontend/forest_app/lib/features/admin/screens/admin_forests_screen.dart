// features/admin/screens/admin_forests_screen.dart
// VERSION 3 — tous les changements appliqués

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../features/forest/models/forest_model.dart';
import '../../../features/forest/providers/forest_provider.dart';

// ── Config carte ───────────────────────────────────────────────
const _tunisiaCenter = LatLng(33.8869, 9.5375);
const _initialZoom   = 7.0;

// Tuile neutre CartoDB — aucune zone verte prédéfinie
const _tileUrl =
    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

// ── Couleurs polygones ─────────────────────────────────────────
const _forestFill    = Color(0x3322C55E);
const _forestBorder  = Color(0xFF16A34A);
const _parcelleFill  = Color(0x333B82F6);
const _parcelleBorder= Color(0xFF2563EB);
const _oldPolyFill   = Color(0x33888888);   // ancien polygone pendant update
const _oldPolyBorder = Color(0xFF888888);
const _newPolyFill   = Color(0x5522C55E);   // nouveau polygone pendant update
const _newPolyBorder = Color(0xFF16A34A);

// ── Panel mode ─────────────────────────────────────────────────
enum _PanelMode { list, createForest, editForest, createParcelle }

// ── Quel tab est ouvert ────────────────────────────────────────
enum _ActiveTab { none, forests, parcelles }

class AdminForestsScreen extends ConsumerStatefulWidget {
  const AdminForestsScreen({super.key});

  @override
  ConsumerState<AdminForestsScreen> createState() =>
      _AdminForestsScreenState();
}

class _AdminForestsScreenState
    extends ConsumerState<AdminForestsScreen> {
  final _mapController = MapController();

  // ── Tab / panel state ─────────────────────────────────
  _ActiveTab  _activeTab  = _ActiveTab.none;
  _PanelMode  _panelMode  = _PanelMode.list;
  String?     _expandedForestId;

  // ── Popup hover ───────────────────────────────────────
  Forest?   _hoveredForest;
  Parcelle? _hoveredParcelle;

  // ── Drawing ───────────────────────────────────────────
  final List<LatLng> _drawPoints   = [];
  List<LatLng>       _oldPoints    = [];   // ancien polygone (update)
  bool               _isDrawing    = false;
  bool               _polygonReady = false; // polygon fermé
  String?            _drawingForestId;

  // ── Form ──────────────────────────────────────────────
  final _nameCtrl   = TextEditingController();
  final _formKey    = GlobalKey<FormState>();
  bool    _isSubmitting = false;
  String? _formError;

  // ── Edit ──────────────────────────────────────────────
  Forest? _editingForest;
  bool    _editHasNewPolygon = false; // true = dessin commencé

  // ── Parcelle form — forêt parente choisie ─────────────
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
  //  Helpers géométriques
  // ══════════════════════════════════════════════════════

  bool get _isClosed =>
      _drawPoints.length >= 3 &&
      _drawPoints.first.latitude  == _drawPoints.last.latitude &&
      _drawPoints.first.longitude == _drawPoints.last.longitude;

  bool get _canClose => _drawPoints.length >= 3 && !_isClosed;

  void _onMapTap(TapPosition tapPosition, LatLng pt) {
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
  //  Tab toggle
  // ══════════════════════════════════════════════════════

  void _toggleTab(_ActiveTab tab) {
    if (_activeTab == tab) {
      setState(() => _activeTab = _ActiveTab.none);
    } else {
      setState(() {
        _activeTab = tab;
        _panelMode = _PanelMode.list;
        _resetForm();
      });
    }
  }

  // ══════════════════════════════════════════════════════
  //  Form transitions
  // ══════════════════════════════════════════════════════

  void _resetForm() {
    _nameCtrl.clear();
    _drawPoints.clear();
    _oldPoints.clear();
    _isDrawing         = false;
    _polygonReady      = false;
    _formError         = null;
    _editingForest     = null;
    _editHasNewPolygon = false;
    _selectedParentForest = null;
  }

  void _openCreateForest() {
    _resetForm();
    setState(() => _panelMode = _PanelMode.createForest);
  }

  void _openEditForest(Forest f) {
    _resetForm();
    _nameCtrl.text = f.name;
    _editingForest = f;
    // Charger l'ancien polygone
    _oldPoints = f.geojson.latLngList
        .map((p) => LatLng(p[0], p[1]))
        .toList();
    setState(() => _panelMode = _PanelMode.editForest);
    _flyTo(f);
  }

  void _openCreateParcelle({Forest? parentForest}) {
    _resetForm();
    _selectedParentForest = parentForest;
    setState(() => _panelMode = _PanelMode.createParcelle);
    if (parentForest != null) _flyTo(parentForest);
  }

  void _backToList() {
    _resetForm();
    setState(() => _panelMode = _PanelMode.list);
  }

  // ── Edit : commencer à redessiner ─────────────────────
  void _startRedraw() {
    setState(() {
      _drawPoints.clear();
      _isDrawing         = true;
      _polygonReady      = false;
      _editHasNewPolygon = true;
    });
  }

  // ── Edit : annuler le nouveau dessin, garder l'ancien ──
  void _cancelRedraw() {
    setState(() {
      _drawPoints.clear();
      _isDrawing         = false;
      _polygonReady      = false;
      _editHasNewPolygon = false;
    });
  }

  // ══════════════════════════════════════════════════════
  //  Submit
  // ══════════════════════════════════════════════════════

  Future<void> _submitCreateForest() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isClosed) {
      setState(() => _formError = 'Fermez le polygone avant d\'enregistrer.');
      return;
    }
    setState(() { _isSubmitting = true; _formError = null; });
    try {
      final f = await ref.read(forestListProvider.notifier).createForest(
            name:    _nameCtrl.text.trim(),
            geojson: _buildGeoJSON(_drawPoints),
          );
      if (f != null && mounted) {
        _showSnack('Forêt « ${f.name} » créée', AppColors.success);
        _backToList();
      } else {
        setState(() =>
            _formError = ref.read(forestListProvider).error ?? 'Erreur');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitEditForest() async {
    if (!_formKey.currentState!.validate()) return;
    // Si nouveau polygone dessiné, il doit être fermé
    if (_editHasNewPolygon && !_isClosed) {
      setState(() => _formError = 'Fermez le nouveau polygone.');
      return;
    }
    setState(() { _isSubmitting = true; _formError = null; });
    try {
      final updated = await ref.read(forestListProvider.notifier).updateForest(
            _editingForest!.id,
            name:    _nameCtrl.text.trim(),
            geojson: _editHasNewPolygon ? _buildGeoJSON(_drawPoints) : null,
          );
      if (updated != null && mounted) {
        _showSnack('Forêt « ${updated.name} » mise à jour', AppColors.success);
        _backToList();
      } else {
        setState(() =>
            _formError = ref.read(forestListProvider).error ?? 'Erreur');
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
      setState(() => _formError = 'Fermez le polygone de la parcelle.');
      return;
    }
    setState(() { _isSubmitting = true; _formError = null; });
    try {
      final p = await ref.read(parcelleProvider.notifier).createParcelle(
            forestId: _selectedParentForest!.id,
            name:     _nameCtrl.text.trim(),
            geojson:  _buildGeoJSON(_drawPoints),
          );
      if (p != null && mounted) {
        _showSnack('Parcelle « ${p.name} » créée', AppColors.success);
        _backToList();
        // Recharger les parcelles de cette forêt
        ref.read(parcelleProvider.notifier)
            .loadParcelles(_selectedParentForest!.id);
      } else {
        setState(() =>
            _formError = ref.read(parcelleProvider).error ?? 'Erreur');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ══════════════════════════════════════════════════════
  //  Delete
  // ══════════════════════════════════════════════════════

  Future<void> _confirmDeleteForest(Forest f) async {
    final ok = await _showDeleteDialog(f.name,
        extra: 'Toutes ses parcelles seront supprimées.');
    if (ok == true) {
      await ref.read(forestListProvider.notifier).deleteForest(f.id);
      setState(() { _hoveredForest = null; });
    }
  }

  Future<void> _confirmDeleteParcelle(Parcelle p) async {
    final ok = await _showDeleteDialog(p.name);
    if (ok == true) {
      await ref.read(parcelleProvider.notifier)
          .deleteParcelle(p.id, p.forestId);
      setState(() { _hoveredParcelle = null; });
    }
  }

  Future<bool?> _showDeleteDialog(String name, {String? extra}) =>
      showDialog<bool>(
        context: context,
        builder: (_) => _DeleteDialog(name: name, extra: extra),
      );

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
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(msg),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ══════════════════════════════════════════════════════
  //  Build polygons
  // ══════════════════════════════════════════════════════

  List<Polygon> _buildPolygons(
      List<Forest> forests, ParcelleState ps) {
    final list = <Polygon>[];

    for (final f in forests) {
      // Pendant l'edit de cette forêt → afficher l'ancien en gris
      final isEditing = _panelMode == _PanelMode.editForest &&
          _editingForest?.id == f.id;

      final pts = f.geojson.latLngList
          .map((p) => LatLng(p[0], p[1]))
          .toList();
      if (pts.isEmpty) continue;

      list.add(Polygon(
        points:            pts,
        color:             isEditing ? _oldPolyFill   : _forestFill,
        borderColor:       isEditing ? _oldPolyBorder : _forestBorder,
        borderStrokeWidth: isEditing ? 1.5 : 1.8,
        isFilled:          true,
      ));

      // Parcelles
      for (final p in ps.forForest(f.id)) {
        final pPts = p.geojson.latLngList
            .map((pt) => LatLng(pt[0], pt[1]))
            .toList();
        if (pPts.isEmpty) continue;
        list.add(Polygon(
          points:            pPts,
          color:             _parcelleFill,
          borderColor:       _parcelleBorder,
          borderStrokeWidth: 1.5,
          isFilled:          true,
        ));
      }
    }

    // Nouveau polygone en cours de dessin (vert)
    final closed = _isClosed ? _drawPoints : <LatLng>[];
    if (closed.length >= 3) {
      final isParc = _panelMode == _PanelMode.createParcelle;
      list.add(Polygon(
        points:            closed,
        color:             isParc ? _parcelleFill : _newPolyFill,
        borderColor:       isParc ? _parcelleBorder : _newPolyBorder,
        borderStrokeWidth: 2.0,
        isFilled:          true,
      ));
    }

    return list;
  }

  // ══════════════════════════════════════════════════════
  //  Build labels (noms sur la carte)
  // ══════════════════════════════════════════════════════

  List<Marker> _buildForestLabels(List<Forest> forests) {
    return forests
        .where((f) => f.centroidLat != null)
        .map((f) {
          final isEditing = _panelMode == _PanelMode.editForest &&
              _editingForest?.id == f.id;
          return Marker(
            point: LatLng(f.centroidLat!, f.centroidLng!),
            width: 160,
            height: 40,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() {
                _hoveredForest   = f;
                _hoveredParcelle = null;
              }),
              onExit: (_) => setState(() => _hoveredForest = null),
              child: GestureDetector(
                onTap: () => setState(() {
                  _hoveredForest   = _hoveredForest?.id == f.id ? null : f;
                  _hoveredParcelle = null;
                }),
                child: _ForestLabel(
                  name:      f.name,
                  isEditing: isEditing,
                ),
              ),
            ),
          );
        })
        .toList();
  }

  List<Marker> _buildParcelleLabels(ParcelleState ps) {
    final markers = <Marker>[];
    for (final fId in ps.byForest.keys) {
      for (final p in ps.forForest(fId)) {
        if (p.centroidLat == null) continue;
        markers.add(Marker(
          point:  LatLng(p.centroidLat!, p.centroidLng!),
          width:  130,
          height: 32,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() {
              _hoveredParcelle = p;
              _hoveredForest   = null;
            }),
            onExit: (_) => setState(() => _hoveredParcelle = null),
            child: _ParcelleLabel(name: p.name),
          ),
        ));
      }
    }
    return markers;
  }

  // ══════════════════════════════════════════════════════
  //  Build
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final forestState = ref.watch(forestListProvider);
    final ps          = ref.watch(parcelleProvider);
    final forests     = forestState.forests;

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

    final openPts = _isClosed ? <LatLng>[] : _drawPoints;

    return Stack(children: [
      // ════════════════════════════════════════════════
      //  MAP
      // ════════════════════════════════════════════════
      FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _tunisiaCenter,
          initialZoom:   _initialZoom,
          minZoom: 4.0,
          maxZoom: 19.0,
          onTap: (tapPosition, pt) {
            _onMapTap(tapPosition, pt);
            // Fermer popup si clic hors polygone
            if (_hoveredForest != null || _hoveredParcelle != null) {
              setState(() {
                _hoveredForest   = null;
                _hoveredParcelle = null;
              });
            }
          },
        ),
        children: [
          // Tuile neutre CartoDB Voyager
          TileLayer(
            urlTemplate:         _tileUrl,
            subdomains:          const ['a', 'b', 'c', 'd'],
            userAgentPackageName:'com.ghabetna.forest_app',
            maxZoom: 19,
          ),

          // Polygones
          PolygonLayer(polygons: _buildPolygons(forests, ps)),

          // Ligne ouverte pendant dessin
          if (openPts.length >= 2)
            PolylineLayer(polylines: [
              Polyline(
                points:      openPts,
                color:       _panelMode == _PanelMode.createParcelle
                    ? _parcelleBorder
                    : _newPolyBorder,
                strokeWidth: 2.0,
                isDotted:    true,
              ),
            ]),

          // Points de dessin
          if (_drawPoints.isNotEmpty)
            MarkerLayer(markers: _drawPoints.asMap().entries.map((e) {
              final isFirst = e.key == 0;
              return Marker(
                point:  e.value,
                width:  isFirst ? 18 : 12,
                height: isFirst ? 18 : 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: isFirst ? _newPolyBorder : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: _newPolyBorder, width: 2),
                  ),
                ),
              );
            }).toList()),

          // Labels forêts (noms sur la carte)
          MarkerLayer(markers: _buildForestLabels(forests)),

          // Labels parcelles
          MarkerLayer(markers: _buildParcelleLabels(ps)),

          const RichAttributionWidget(
            attributions: [
              TextSourceAttribution('© CartoDB © OpenStreetMap'),
            ],
          ),
        ],
      ),

      // ════════════════════════════════════════════════
      //  POPUP HOVER — Forêt
      // ════════════════════════════════════════════════
      if (_hoveredForest != null &&
          _hoveredForest!.centroidLat != null)
        _ForestPopup(
          forest:    _hoveredForest!,
          mapController: _mapController,
          onEdit:    () { _openEditForest(_hoveredForest!); },
          onDelete:  () => _confirmDeleteForest(_hoveredForest!),
          onClose:   () => setState(() => _hoveredForest = null),
        ),

      // POPUP HOVER — Parcelle
      if (_hoveredParcelle != null &&
          _hoveredParcelle!.centroidLat != null)
        _ParcellePopup(
          parcelle:  _hoveredParcelle!,
          mapController: _mapController,
          onDelete:  () => _confirmDeleteParcelle(_hoveredParcelle!),
          onClose:   () => setState(() => _hoveredParcelle = null),
        ),

      // ════════════════════════════════════════════════
      //  TAB — FORÊTS (droite)
      // ════════════════════════════════════════════════
      Positioned(
        top: 0, bottom: 0, right: 0,
        child: _TabWithPanel(
          tabLabel:    'FORÊTS',
          tabIcon:     Icons.park_outlined,
          tabColor:    AppColors.primaryDark,
          accentColor: const Color(0xFF16A34A),
          isOpen:      _activeTab == _ActiveTab.forests,
          onToggle:    () => _toggleTab(_ActiveTab.forests),
          alignment:   _TabAlignment.right,
          child: _panelMode == _PanelMode.list
              ? _ForestListPanel(
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
                  onCreateParcelle: (f) => _openCreateParcelle(parentForest: f),
                )
              : _panelMode == _PanelMode.createForest
                  ? _DrawFormPanel(
                      key:         const ValueKey('create-forest'),
                      title:       'Nouvelle forêt',
                      subtitle:    'Dessinez le polygone sur la carte',
                      fieldHint:   'Ex : Forêt de Béja',
                      fieldIcon:   Icons.park_outlined,
                      accentColor: const Color(0xFF16A34A),
                      nameCtrl:    _nameCtrl,
                      formKey:     _formKey,
                      isDrawing:   _isDrawing,
                      isClosed:    _isClosed,
                      canClose:    _canClose,
                      pointCount:  _drawPoints.length,
                      isSubmitting:_isSubmitting,
                      formError:   _formError,
                      onDismissError:() => setState(() => _formError = null),
                      onToggleDraw:  () => setState(() => _isDrawing = !_isDrawing),
                      onClose:       _closePolygon,
                      onUndo:        _undoPoint,
                      onClear:       _clearDraw,
                      onSubmit:      _submitCreateForest,
                      onBack:        _backToList,
                    )
                  : _panelMode == _PanelMode.editForest
                      ? _EditForestPanel(
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
                          onDismissError:   () => setState(() => _formError = null),
                          onStartRedraw:    _startRedraw,
                          onCancelRedraw:   _cancelRedraw,
                          onToggleDraw:     () => setState(() => _isDrawing = !_isDrawing),
                          onClose:          _closePolygon,
                          onUndo:           _undoPoint,
                          onSubmit:         _submitEditForest,
                          onBack:           _backToList,
                        )
                      : const SizedBox.shrink(),
        ),
      ),

      // ════════════════════════════════════════════════
      //  TAB — PARCELLES (gauche)
      // ════════════════════════════════════════════════
      Positioned(
        top: 0, bottom: 0, left: 0,
        child: _TabWithPanel(
          tabLabel:    'PARCELLES',
          tabIcon:     Icons.crop_square_outlined,
          tabColor:    const Color(0xFF1E40AF),
          accentColor: _parcelleBorder,
          isOpen:      _activeTab == _ActiveTab.parcelles,
          onToggle:    () => _toggleTab(_ActiveTab.parcelles),
          alignment:   _TabAlignment.left,
          child: _panelMode == _PanelMode.createParcelle
              ? _DrawFormPanel(
                  key:         const ValueKey('create-parcelle'),
                  title:       'Nouvelle parcelle',
                  subtitle:    _selectedParentForest != null
                      ? 'Forêt : ${_selectedParentForest!.name}'
                      : 'Choisissez la forêt parente',
                  fieldHint:   'Ex : Parcelle Nord-Est',
                  fieldIcon:   Icons.crop_square_outlined,
                  accentColor: _parcelleBorder,
                  nameCtrl:    _nameCtrl,
                  formKey:     _formKey,
                  isDrawing:   _isDrawing,
                  isClosed:    _isClosed,
                  canClose:    _canClose,
                  pointCount:  _drawPoints.length,
                  isSubmitting:_isSubmitting,
                  formError:   _formError,
                  forestSelector: _selectedParentForest == null
                      ? _ForestSelector(
                          forests: forests,
                          onSelect: (f) => setState(() {
                            _selectedParentForest = f;
                            _flyTo(f);
                          }),
                        )
                      : null,
                  onDismissError:() => setState(() => _formError = null),
                  onToggleDraw:  () => setState(() => _isDrawing = !_isDrawing),
                  onClose:       _closePolygon,
                  onUndo:        _undoPoint,
                  onClear:       _clearDraw,
                  onSubmit:      _submitCreateParcelle,
                  onBack:        _backToList,
                )
              : _ParcelleListPanel(
                  forests:          forests,
                  parcelleState:    ps,
                  onCreateParcelle: _openCreateParcelle,
                  onParcelleDelete: _confirmDeleteParcelle,
                  onForestFly:      _flyTo,
                ),
        ),
      ),

      // ════════════════════════════════════════════════
      //  Overlays
      // ════════════════════════════════════════════════
      if (forestState.isLoading)
        const Positioned(
          top: 12, left: 0, right: 0,
          child: Center(child: _LoadingChip()),
        ),

      if (_isDrawing && _drawPoints.isEmpty)
        const Center(child: _DrawHint()),

      if (_drawPoints.isNotEmpty)
        Positioned(
          bottom: 28, left: 0, right: 0,
          child: Center(
            child: _DrawCounter(
              count:    _drawPoints.length,
              isClosed: _isClosed,
              isParc:   _panelMode == _PanelMode.createParcelle,
            ),
          ),
        ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
//  Forest label sur la carte (nom au lieu d'icône)
// ═══════════════════════════════════════════════════════════════

class _ForestLabel extends StatelessWidget {
  final String name;
  final bool   isEditing;
  const _ForestLabel({required this.name, required this.isEditing});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isEditing
                ? Colors.grey.withOpacity(0.85)
                : AppColors.primaryDark.withOpacity(0.88),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 4, offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.park,
                  size: 11,
                  color: isEditing
                      ? Colors.white70
                      : const Color(0xFF86EFAC)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
}

class _ParcelleLabel extends StatelessWidget {
  final String name;
  const _ParcelleLabel({required this.name});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF1D4ED8).withOpacity(0.85),
            borderRadius: BorderRadius.circular(5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 3, offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
//  Popup — positionné au centroïde via CustomPaint approximation
//  On utilise un Marker positionné juste au-dessus du centroïde
// ═══════════════════════════════════════════════════════════════

class _ForestPopup extends StatelessWidget {
  final Forest      forest;
  final MapController mapController;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClose;
  const _ForestPopup({
    required this.forest,
    required this.mapController,
    required this.onEdit,
    required this.onDelete,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // On positionne le popup dans une MarkerLayer via un Stack overlay
    // Le marker est au centroïde — on affiche le popup via un Positioned
    // calculé depuis la position de la carte.
    // Pour Flutter Web, on utilise un overlay flottant centré sur l'écran
    // décalé vers la position relative du centroïde.
    final size = MediaQuery.of(context).size;

    return Positioned(
      // Centré sur l'écran horizontalement, au tiers supérieur
      left: size.width / 2 - 110,
      top:  size.height * 0.15,
      child: _PopupCard(
        title:    forest.name,
        subtitle: forest.areaLabel,
        icon:     Icons.park_outlined,
        color:    AppColors.primaryDark,
        onEdit:   onEdit,
        onDelete: onDelete,
        onClose:  onClose,
      ),
    );
  }
}

class _ParcellePopup extends StatelessWidget {
  final Parcelle    parcelle;
  final MapController mapController;
  final VoidCallback onDelete;
  final VoidCallback onClose;
  const _ParcellePopup({
    required this.parcelle,
    required this.mapController,
    required this.onDelete,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned(
      left: size.width / 2 - 110,
      top:  size.height * 0.15,
      child: _PopupCard(
        title:    parcelle.name,
        subtitle: parcelle.areaLabel,
        icon:     Icons.crop_square_outlined,
        color:    const Color(0xFF1D4ED8),
        onDelete: onDelete,
        onClose:  onClose,
      ),
    );
  }
}

class _PopupCard extends StatelessWidget {
  final String       title;
  final String       subtitle;
  final IconData     icon;
  final Color        color;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClose;
  const _PopupCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onEdit,
    required this.onDelete,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) => Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        shadowColor: Colors.black26,
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close,
                    size: 15, color: AppColors.textMuted),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              if (onEdit != null) ...[
                Expanded(child: _PopBtn(
                  label: 'Modifier', icon: Icons.edit_outlined,
                  color: color, onTap: onEdit!,
                )),
                const SizedBox(width: 8),
              ],
              Expanded(child: _PopBtn(
                label: 'Supprimer', icon: Icons.delete_outline,
                color: AppColors.danger, onTap: onDelete,
              )),
            ]),
          ]),
        ),
      );
}

class _PopBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _PopBtn({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: color.withOpacity(0.25), width: 0.5),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
//  TAB + PANEL wrapper
// ═══════════════════════════════════════════════════════════════

enum _TabAlignment { left, right }

class _TabWithPanel extends StatelessWidget {
  final String         tabLabel;
  final IconData       tabIcon;
  final Color          tabColor;
  final Color          accentColor;
  final bool           isOpen;
  final VoidCallback   onToggle;
  final _TabAlignment  alignment;
  final Widget         child;

  const _TabWithPanel({
    required this.tabLabel,
    required this.tabIcon,
    required this.tabColor,
    required this.accentColor,
    required this.isOpen,
    required this.onToggle,
    required this.alignment,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isRight = alignment == _TabAlignment.right;
    final tab = GestureDetector(
      onTap: onToggle,
      child: Container(
        width: 26,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: tabColor,
          borderRadius: isRight
              ? const BorderRadius.only(
                  topLeft:    Radius.circular(8),
                  bottomLeft: Radius.circular(8))
              : const BorderRadius.only(
                  topRight:    Radius.circular(8),
                  bottomRight: Radius.circular(8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: isRight
                  ? const Offset(-2, 0)
                  : const Offset(2, 0),
            ),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            isOpen
                ? (isRight ? Icons.chevron_right : Icons.chevron_left)
                : (isRight ? Icons.chevron_left  : Icons.chevron_right),
            color: Colors.white, size: 16,
          ),
          const SizedBox(height: 8),
          RotatedBox(
            quarterTurns: 1,
            child: Text(tabLabel,
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.7),
                    letterSpacing: 1.0)),
          ),
        ]),
      ),
    );

    final panel = AnimatedContainer(
      duration: const Duration(milliseconds: 230),
      curve: Curves.easeInOut,
      width: isOpen ? 300 : 0,
      child: isOpen
          ? Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 16,
                    offset: isRight
                        ? const Offset(-4, 0)
                        : const Offset(4, 0),
                  ),
                ],
              ),
              child: child,
            )
          : const SizedBox.shrink(),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: isRight
            ? [tab, panel]
            : [panel, tab],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  FOREST LIST PANEL
// ═══════════════════════════════════════════════════════════════

class _ForestListPanel extends StatefulWidget {
  final List<Forest>    forests;
  final ParcelleState   parcelleState;
  final bool            isLoading;
  final String?         expandedForestId;
  final Set<String>     deletingIds;
  final void Function(Forest)    onForestTap;
  final void Function(String)    onForestExpand;
  final void Function(Forest)    onForestEdit;
  final void Function(Forest)    onForestDelete;
  final void Function(Parcelle)  onParcelleDelete;
  final VoidCallback             onCreateForest;
  final void Function(Forest)    onCreateParcelle;

  const _ForestListPanel({
    required this.forests,
    required this.parcelleState,
    required this.isLoading,
    required this.expandedForestId,
    required this.deletingIds,
    required this.onForestTap,
    required this.onForestExpand,
    required this.onForestEdit,
    required this.onForestDelete,
    required this.onParcelleDelete,
    required this.onCreateForest,
    required this.onCreateParcelle,
  });
  @override State<_ForestListPanel> createState() => _ForestListPanelState();
}

class _ForestListPanelState extends State<_ForestListPanel> {
  String _search = '';

  List<Forest> get _filtered => _search.isEmpty
      ? widget.forests
      : widget.forests
          .where((f) => f.name.toLowerCase().contains(_search.toLowerCase()))
          .toList();

  @override
  Widget build(BuildContext context) => Column(children: [
    // Header
    _PanelHeader(
      title:   'Forêts · Tunisie',
      count:   '${widget.forests.length} forêt${widget.forests.length != 1 ? 's' : ''}',
      icon:    Icons.park_outlined,
      color:   AppColors.primaryDark,
      btnLabel:'+ Forêt',
      btnColor: const Color(0xFF16A34A),
      onBtn:   widget.onCreateForest,
    ),
    // Search
    _PanelSearch(onChanged: (v) => setState(() => _search = v)),
    const Divider(height: 1, color: AppColors.borderLight),
    // List
    Expanded(
      child: widget.isLoading
          ? const Center(child: CircularProgressIndicator(
              color: AppColors.primaryMid, strokeWidth: 2))
          : _filtered.isEmpty
              ? _EmptyPanel(
                  icon:    Icons.park_outlined,
                  message: _search.isNotEmpty
                      ? 'Aucun résultat'
                      : 'Aucune forêt',
                  sub: _search.isEmpty ? 'Créez la première forêt.' : null,
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final f = _filtered[i];
                    return _ForestRow(
                      forest:           f,
                      isDeleting:       widget.deletingIds.contains(f.id),
                      isExpanded:       widget.expandedForestId == f.id,
                      parcelles:        widget.parcelleState.forForest(f.id),
                      isLoadingParc:    widget.parcelleState.loadingIds.contains(f.id),
                      onTap:            () => widget.onForestTap(f),
                      onExpand:         () => widget.onForestExpand(f.id),
                      onEdit:           () => widget.onForestEdit(f),
                      onDelete:         () => widget.onForestDelete(f),
                      onParcelleDelete: widget.onParcelleDelete,
                      onCreateParcelle: () => widget.onCreateParcelle(f),
                    );
                  },
                ),
    ),
  ]);
}

// ═══════════════════════════════════════════════════════════════
//  PARCELLE LIST PANEL
// ═══════════════════════════════════════════════════════════════

class _ParcelleListPanel extends StatelessWidget {
  final List<Forest>           forests;
  final ParcelleState          parcelleState;
  final void Function({Forest? parentForest}) onCreateParcelle;
  final void Function(Parcelle) onParcelleDelete;
  final void Function(Forest)   onForestFly;

  const _ParcelleListPanel({
    required this.forests,
    required this.parcelleState,
    required this.onCreateParcelle,
    required this.onParcelleDelete,
    required this.onForestFly,
  });

  @override
  Widget build(BuildContext context) {
    // Toutes les parcelles chargées
    final allParcelles = parcelleState.byForest.values
        .expand((list) => list)
        .toList();

    return Column(children: [
      _PanelHeader(
        title:    'Parcelles',
        count:    '${allParcelles.length} parcelle${allParcelles.length != 1 ? 's' : ''}',
        icon:     Icons.crop_square_outlined,
        color:    const Color(0xFF1E40AF),
        btnLabel: '+ Parcelle',
        btnColor: _parcelleBorder,
        onBtn:    () => onCreateParcelle(),
      ),
      const Divider(height: 1, color: AppColors.borderLight),
      Expanded(
        child: allParcelles.isEmpty
            ? _EmptyPanel(
                icon:    Icons.crop_square_outlined,
                message: 'Aucune parcelle chargée',
                sub: 'Dépliez une forêt dans l\'onglet Forêts\npour charger ses parcelles.',
              )
            : ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: allParcelles.length,
                itemBuilder: (_, i) {
                  final p = allParcelles[i];
                  final parentForest = forests
                      .where((f) => f.id == p.forestId)
                      .firstOrNull;
                  return _ParcelleRow(
                    parcelle:     p,
                    parentName:   parentForest?.name ?? '...',
                    onDelete:     () => onParcelleDelete(p),
                    onFlyToForest:parentForest != null
                        ? () => onForestFly(parentForest)
                        : null,
                  );
                },
              ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
//  DRAW FORM PANEL (partagé create forest + create parcelle)
// ═══════════════════════════════════════════════════════════════

class _DrawFormPanel extends StatelessWidget {
  final String       title;
  final String       subtitle;
  final String       fieldHint;
  final IconData     fieldIcon;
  final Color        accentColor;
  final TextEditingController nameCtrl;
  final GlobalKey<FormState>  formKey;
  final bool     isDrawing;
  final bool     isClosed;
  final bool     canClose;
  final int      pointCount;
  final bool     isSubmitting;
  final String?  formError;
  final Widget?  forestSelector; // null si pas besoin
  final VoidCallback onDismissError;
  final VoidCallback onToggleDraw;
  final VoidCallback onClose;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const _DrawFormPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.fieldHint,
    required this.fieldIcon,
    required this.accentColor,
    required this.nameCtrl,
    required this.formKey,
    required this.isDrawing,
    required this.isClosed,
    required this.canClose,
    required this.pointCount,
    required this.isSubmitting,
    required this.formError,
    this.forestSelector,
    required this.onDismissError,
    required this.onToggleDraw,
    required this.onClose,
    required this.onUndo,
    required this.onClear,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) => Column(children: [
    // Header
    Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.06),
        border: const Border(
            bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: const Icon(Icons.arrow_back,
                size: 15, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textMuted),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(fieldIcon, size: 13, color: accentColor),
        ),
      ]),
    ),

    // Body
    Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Error
            if (formError != null) ...[
              _ErrorBanner(message: formError!, onDismiss: onDismissError),
              const SizedBox(height: 14),
            ],

            // Forest selector (parcelle only)
            if (forestSelector != null) ...[
              forestSelector!,
              const SizedBox(height: 16),
            ],

            // Name
            Text('Nom *',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextFormField(
              controller: nameCtrl,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textPrimary),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Champ requis' : null,
              decoration: InputDecoration(
                hintText:  fieldHint,
                hintStyle: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted),
                prefixIcon: Icon(fieldIcon,
                    size: 16, color: AppColors.textMuted),
                filled:    true,
                fillColor: AppColors.bgInput,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.border, width: 0.5)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.border, width: 0.5)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color: accentColor, width: 1.2)),
                errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.danger, width: 0.8)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                isDense: true,
              ),
            ),

            const SizedBox(height: 20),

            // Draw tools
            Text('Polygone *',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            _DrawTools(
              isDrawing:   isDrawing,
              isClosed:    isClosed,
              canClose:    canClose,
              pointCount:  pointCount,
              accentColor: accentColor,
              onToggle:    onToggleDraw,
              onClose:     onClose,
              onUndo:      onUndo,
              onClear:     onClear,
            ),
            const SizedBox(height: 12),
            _PolygonStatus(
              pointCount:  pointCount,
              isClosed:    isClosed,
              isDrawing:   isDrawing,
              accentColor: accentColor,
            ),
            const SizedBox(height: 24),

            // Submit
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSubmitting ? null : onSubmit,
                icon: isSubmitting
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_outlined, size: 16),
                label: Text(
                    isSubmitting ? 'Enregistrement...' : 'Enregistrer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isClosed ? accentColor : AppColors.textMuted,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: isSubmitting ? null : onBack,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(
                      color: AppColors.border, width: 0.8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
                child: const Text('Annuler',
                    style: TextStyle(fontSize: 13)),
              ),
            ),
          ]),
        ),
      ),
    ),
  ]);
}

// ═══════════════════════════════════════════════════════════════
//  EDIT FOREST PANEL — ancien gris + nouveau vert
// ═══════════════════════════════════════════════════════════════

class _EditForestPanel extends StatelessWidget {
  final Forest      forest;
  final TextEditingController nameCtrl;
  final GlobalKey<FormState>  formKey;
  final bool     hasNewPolygon;
  final bool     isDrawing;
  final bool     isClosed;
  final bool     canClose;
  final int      pointCount;
  final bool     isSubmitting;
  final String?  formError;
  final VoidCallback onDismissError;
  final VoidCallback onStartRedraw;
  final VoidCallback onCancelRedraw;
  final VoidCallback onToggleDraw;
  final VoidCallback onClose;
  final VoidCallback onUndo;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const _EditForestPanel({
    required this.forest,
    required this.nameCtrl,
    required this.formKey,
    required this.hasNewPolygon,
    required this.isDrawing,
    required this.isClosed,
    required this.canClose,
    required this.pointCount,
    required this.isSubmitting,
    required this.formError,
    required this.onDismissError,
    required this.onStartRedraw,
    required this.onCancelRedraw,
    required this.onToggleDraw,
    required this.onClose,
    required this.onUndo,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withOpacity(0.05),
        border: const Border(
            bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: const Icon(Icons.arrow_back,
                size: 15, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Modifier la forêt',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            Text(forest.name,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textMuted),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    ),

    Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (formError != null) ...[
              _ErrorBanner(message: formError!, onDismiss: onDismissError),
              const SizedBox(height: 14),
            ],

            // Name
            const Text('Nom *',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextFormField(
              controller: nameCtrl,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textPrimary),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Champ requis' : null,
              decoration: InputDecoration(
                hintText:  'Nom de la forêt',
                hintStyle: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.park_outlined,
                    size: 16, color: AppColors.textMuted),
                filled:    true,
                fillColor: AppColors.bgInput,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.border, width: 0.5)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.border, width: 0.5)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.primaryMid, width: 1.2)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                isDense: true,
              ),
            ),

            const SizedBox(height: 20),

            // Polygone section
            const Text('Polygone',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 10),

            // Légende ancien / nouveau
            if (hasNewPolygon) ...[
              _PolyLegend(
                oldColor:  _oldPolyBorder,
                newColor:  _newPolyBorder,
                oldLabel:  'Ancien (affiché en gris)',
                newLabel:  'Nouveau (en cours de dessin)',
              ),
              const SizedBox(height: 12),
            ],

            // Boutons
            if (!hasNewPolygon) ...[
              _ActionBtn(
                label:  'Redessiner le polygone',
                icon:   Icons.draw_outlined,
                color:  AppColors.warning,
                onTap:  onStartRedraw,
              ),
              const SizedBox(height: 6),
              Text(
                'L\'ancien polygone restera visible (gris)\njusqu\'à ce que vous confirmiez.',
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textMuted, height: 1.4),
              ),
            ] else ...[
              _DrawTools(
                isDrawing:   isDrawing,
                isClosed:    isClosed,
                canClose:    canClose,
                pointCount:  pointCount,
                accentColor: const Color(0xFF16A34A),
                onToggle:    onToggleDraw,
                onClose:     onClose,
                onUndo:      onUndo,
                onClear:     () {},
              ),
              const SizedBox(height: 8),
              _ActionBtn(
                label: 'Annuler — garder l\'ancien',
                icon:  Icons.undo,
                color: AppColors.textSecondary,
                onTap: onCancelRedraw,
              ),
              const SizedBox(height: 10),
              _PolygonStatus(
                pointCount:  pointCount,
                isClosed:    isClosed,
                isDrawing:   isDrawing,
                accentColor: const Color(0xFF16A34A),
              ),
            ],

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSubmitting ? null : onSubmit,
                icon: isSubmitting
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_outlined, size: 16),
                label: Text(
                    isSubmitting ? 'Mise à jour...' : 'Enregistrer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: isSubmitting ? null : onBack,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(
                      color: AppColors.border, width: 0.8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
                child: const Text('Annuler',
                    style: TextStyle(fontSize: 13)),
              ),
            ),
          ]),
        ),
      ),
    ),
  ]);
}

// ═══════════════════════════════════════════════════════════════
//  Forest selector (pour création parcelle)
// ═══════════════════════════════════════════════════════════════

class _ForestSelector extends StatelessWidget {
  final List<Forest>          forests;
  final void Function(Forest) onSelect;
  const _ForestSelector({required this.forests, required this.onSelect});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Forêt parente *',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          if (forests.isEmpty)
            const Text('Aucune forêt disponible',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textMuted,
                    fontStyle: FontStyle.italic))
          else
            ...forests.map((f) => GestureDetector(
                  onTap: () => onSelect(f),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.bgInput,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.border, width: 0.5),
                    ),
                    child: Row(children: [
                      const Icon(Icons.park_outlined,
                          size: 15, color: AppColors.primaryMid),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(f.name,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500)),
                      ),
                      Text(f.areaLabel,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textMuted)),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_ios,
                          size: 11, color: AppColors.textMuted),
                    ]),
                  ),
                )),
        ],
      );
}

// ═══════════════════════════════════════════════════════════════
//  Small shared widgets
// ═══════════════════════════════════════════════════════════════

class _ForestRow extends StatelessWidget {
  final Forest            forest;
  final bool              isDeleting;
  final bool              isExpanded;
  final List<Parcelle>    parcelles;
  final bool              isLoadingParc;
  final VoidCallback      onTap;
  final VoidCallback      onExpand;
  final VoidCallback      onEdit;
  final VoidCallback      onDelete;
  final void Function(Parcelle) onParcelleDelete;
  final VoidCallback      onCreateParcelle;

  const _ForestRow({
    required this.forest, required this.isDeleting, required this.isExpanded,
    required this.parcelles, required this.isLoadingParc, required this.onTap,
    required this.onExpand, required this.onEdit, required this.onDelete,
    required this.onParcelleDelete, required this.onCreateParcelle,
  });

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity:  isDeleting ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Column(children: [
          InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(
                    color: AppColors.borderLight, width: 0.5))),
              child: Row(children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.park_outlined,
                      size: 15, color: AppColors.primaryMid),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(forest.name,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis),
                    Text(forest.areaLabel,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textMuted)),
                  ]),
                ),
                _IconBtn(icon: Icons.edit_outlined,
                    color: AppColors.primaryMid,
                    onTap: isDeleting ? null : onEdit),
                const SizedBox(width: 4),
                _IconBtn(icon: Icons.delete_outline,
                    color: AppColors.danger,
                    onTap: isDeleting ? null : onDelete),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onExpand,
                  child: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18, color: AppColors.textMuted,
                  ),
                ),
              ]),
            ),
          ),
          if (isExpanded)
            Container(
              color: const Color(0xFFF9FAF7),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                  child: Row(children: [
                    const Text('Parcelles',
                        style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5)),
                    const Spacer(),
                    GestureDetector(
                      onTap: onCreateParcelle,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _parcelleFill,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                              color: _parcelleBorder.withOpacity(0.4),
                              width: 0.5),
                        ),
                        child: const Row(children: [
                          Icon(Icons.add, size: 10, color: _parcelleBorder),
                          SizedBox(width: 3),
                          Text('Ajouter',
                              style: TextStyle(
                                  fontSize: 9, color: _parcelleBorder,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ]),
                ),
                if (isLoadingParc)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _parcelleBorder)),
                  )
                else if (parcelles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
                    child: Text('Aucune parcelle',
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted.withOpacity(0.7),
                            fontStyle: FontStyle.italic)),
                  )
                else
                  ...parcelles.map((p) => _SmallParcelleRow(
                        parcelle: p,
                        onDelete: () => onParcelleDelete(p),
                      )),
              ]),
            ),
        ]),
      );
}

class _ParcelleRow extends StatelessWidget {
  final Parcelle     parcelle;
  final String       parentName;
  final VoidCallback onDelete;
  final VoidCallback? onFlyToForest;
  const _ParcelleRow({required this.parcelle, required this.parentName,
      required this.onDelete, this.onFlyToForest});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(
              color: AppColors.borderLight, width: 0.5))),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: _parcelleFill,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.crop_square_outlined,
                size: 13, color: _parcelleBorder),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(parcelle.name,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis),
              Row(children: [
                Text(parentName,
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textMuted)),
                const SizedBox(width: 6),
                Text('· ${parcelle.areaLabel}',
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textMuted)),
              ]),
            ]),
          ),
          if (onFlyToForest != null)
            _IconBtn(
              icon:  Icons.my_location,
              color: AppColors.primaryMid,
              onTap: onFlyToForest,
              size:  24,
            ),
          const SizedBox(width: 4),
          _IconBtn(icon: Icons.delete_outline,
              color: AppColors.danger, onTap: onDelete),
        ]),
      );
}

class _SmallParcelleRow extends StatelessWidget {
  final Parcelle parcelle;
  final VoidCallback onDelete;
  const _SmallParcelleRow({required this.parcelle, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(22, 6, 14, 6),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(
              color: AppColors.borderLight, width: 0.5))),
        child: Row(children: [
          Container(width: 6, height: 6,
              decoration: const BoxDecoration(
                  color: _parcelleBorder, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(parcelle.name,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis),
              Text(parcelle.areaLabel,
                  style: const TextStyle(
                      fontSize: 9, color: AppColors.textMuted)),
            ]),
          ),
          _IconBtn(icon: Icons.delete_outline,
              color: AppColors.danger, onTap: onDelete, size: 22),
        ]),
      );
}

class _PanelHeader extends StatelessWidget {
  final String     title;
  final String     count;
  final IconData   icon;
  final Color      color;
  final String     btnLabel;
  final Color      btnColor;
  final VoidCallback onBtn;
  const _PanelHeader({required this.title, required this.count,
      required this.icon, required this.color, required this.btnLabel,
      required this.btnColor, required this.onBtn});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          border: const Border(bottom: BorderSide(
              color: AppColors.borderLight, width: 0.5)),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              Text(count,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textMuted)),
            ]),
          ),
          GestureDetector(
            onTap: onBtn,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: btnColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                    color: btnColor.withOpacity(0.35), width: 0.8),
              ),
              child: Text(btnLabel,
                  style: TextStyle(
                      fontSize: 11, color: btnColor,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      );
}

class _PanelSearch extends StatelessWidget {
  final void Function(String) onChanged;
  const _PanelSearch({required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(10),
        child: SizedBox(
          height: 34,
          child: TextField(
            onChanged: onChanged,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText:  'Rechercher...',
              hintStyle: const TextStyle(
                  fontSize: 11, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search,
                  size: 14, color: AppColors.textMuted),
              filled:    true,
              fillColor: AppColors.bgInput,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(
                    color: AppColors.border, width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(
                    color: AppColors.border, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(
                    color: AppColors.primaryMid, width: 1.0),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 0),
              isDense: true,
            ),
          ),
        ),
      );
}

class _DrawTools extends StatelessWidget {
  final bool isDrawing, isClosed, canClose;
  final int  pointCount;
  final Color accentColor;
  final VoidCallback onToggle, onClose, onUndo, onClear;
  const _DrawTools({required this.isDrawing, required this.isClosed,
      required this.canClose, required this.pointCount,
      required this.accentColor, required this.onToggle,
      required this.onClose, required this.onUndo, required this.onClear});

  @override
  Widget build(BuildContext context) => Wrap(spacing: 6, runSpacing: 6, children: [
    _Chip(
      label: isDrawing ? 'Arrêter' : 'Dessiner',
      icon:  isDrawing ? Icons.stop : Icons.edit_location_alt_outlined,
      color: isDrawing ? AppColors.warning : accentColor,
      onTap: onToggle,
    ),
    _Chip(
      label:   'Fermer',
      icon:    Icons.check_circle_outline,
      color:   canClose ? AppColors.success : AppColors.textMuted,
      onTap:   canClose ? onClose : null,
    ),
    _Chip(
      label:   'Annuler',
      icon:    Icons.undo,
      color:   pointCount > 0 ? AppColors.info : AppColors.textMuted,
      onTap:   pointCount > 0 ? onUndo : null,
    ),
    _Chip(
      label:   'Effacer',
      icon:    Icons.delete_sweep_outlined,
      color:   pointCount > 0 ? AppColors.danger : AppColors.textMuted,
      onTap:   pointCount > 0 ? onClear : null,
    ),
  ]);
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _Chip({required this.label, required this.icon,
      required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: disabled
              ? AppColors.bgInput
              : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: disabled ? AppColors.border : color.withOpacity(0.35),
            width: 0.8,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12,
              color: disabled ? AppColors.textMuted : color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: disabled ? AppColors.textMuted : color)),
        ]),
      ),
    );
  }
}

class _PolygonStatus extends StatelessWidget {
  final int pointCount;
  final bool isClosed, isDrawing;
  final Color accentColor;
  const _PolygonStatus({required this.pointCount, required this.isClosed,
      required this.isDrawing, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    if (pointCount == 0) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.bgInput,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: const Row(children: [
          Icon(Icons.mouse_outlined, size: 12, color: AppColors.textMuted),
          SizedBox(width: 8),
          Expanded(
            child: Text('Appuyez sur Dessiner puis cliquez sur la carte',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ),
        ]),
      );
    }
    final (text, color) = isClosed
        ? ('✓ Polygone fermé — $pointCount points', AppColors.success)
        : isDrawing
            ? ('$pointCount points — continuez à cliquer', accentColor)
            : ('$pointCount points — appuyez sur Fermer', AppColors.warning);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Row(children: [
        Icon(isClosed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 12, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 10, color: color,
                  fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}

class _PolyLegend extends StatelessWidget {
  final Color oldColor, newColor;
  final String oldLabel, newLabel;
  const _PolyLegend({required this.oldColor, required this.newColor,
      required this.oldLabel, required this.newLabel});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.bgInput,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(children: [
          _LegendRow(color: oldColor, label: oldLabel),
          const SizedBox(height: 4),
          _LegendRow(color: newColor, label: newLabel),
        ]),
      );
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 12, height: 3,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(label,
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
  ]);
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3), width: 0.8),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final double size;
  const _IconBtn({required this.icon, required this.color,
      this.onTap, this.size = 26});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.25), width: 0.5),
          ),
          child: Icon(icon, size: size * 0.55, color: color),
        ),
      );
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String   message;
  final String?  sub;
  const _EmptyPanel({required this.icon, required this.message, this.sub});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 36, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text(message,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            if (sub != null) ...[
              const SizedBox(height: 4),
              Text(sub!,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted),
                  textAlign: TextAlign.center),
            ],
          ]),
        ),
      );
}

class _LoadingChip extends StatelessWidget {
  const _LoadingChip();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primaryMid)),
          SizedBox(width: 8),
          Text('Chargement...', style: TextStyle(
              fontSize: 11, color: AppColors.textSecondary)),
        ]),
      );
}

class _DrawHint extends StatelessWidget {
  const _DrawHint();
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.65),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.touch_app_outlined, color: Colors.white70, size: 28),
            SizedBox(height: 8),
            Text('Cliquez sur la carte pour ajouter des points',
                style: TextStyle(color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center),
            SizedBox(height: 4),
            Text('Puis « Fermer » pour finaliser le polygone',
                style: TextStyle(color: Colors.white60, fontSize: 10),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _DrawCounter extends StatelessWidget {
  final int count;
  final bool isClosed, isParc;
  const _DrawCounter({required this.count, required this.isClosed,
      required this.isParc});

  @override
  Widget build(BuildContext context) {
    final color = isClosed
        ? AppColors.success
        : isParc ? _parcelleBorder : const Color(0xFF16A34A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Text(
        isClosed ? '✓ $count points — polygone fermé' : '$count point${count != 1 ? 's' : ''}',
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
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
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: AppColors.danger.withOpacity(0.3), width: 0.5),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 14, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(child: Text(message,
              style: const TextStyle(fontSize: 11, color: AppColors.danger))),
          GestureDetector(onTap: onDismiss,
              child: const Icon(Icons.close,
                  size: 14, color: AppColors.danger)),
        ]),
      );
}

class _DeleteDialog extends StatelessWidget {
  final String  name;
  final String? extra;
  const _DeleteDialog({required this.name, this.extra});

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded,
              color: AppColors.danger, size: 20),
          SizedBox(width: 8),
          Text('Confirmer la suppression',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ]),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            children: [
              const TextSpan(text: 'Supprimer '),
              TextSpan(text: name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
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
            child: const Text('Annuler',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      );
}