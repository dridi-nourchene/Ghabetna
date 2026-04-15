import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/models/forest_model.dart';
import '../../data/services/forest_service.dart';
import '../../../../frontend/forest_app/lib/core/token_storage.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {

  // ── State ─────────────────────────────────────────────
  final ForestService   _service       = ForestService();
  final MapController   _mapController = MapController();

  List<ForestFeature>   _forests       = [];
  bool                  _isLoading     = true;
  String?               _error;
  String?               _userRole;

  // Sidebar
  bool                  _sidebarOpen   = true;
  bool                  _forestMenuOpen = false;

  // Mode dessin
  bool                  _isDrawingMode = false;
  List<LatLng>          _drawnPoints   = [];

  // Forêt sélectionnée (popup)
  ForestFeature?        _selectedForest;

  // Forêt en cours de modification
  ForestFeature? _editingForest;
  String?        _editingName;
  bool           _isRedrawMode = false;
  // position en pixels du clic
  Offset? _popupPosition;  
  // Initialisation 
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _userRole = await TokenStorage().getRole();
    await _loadForests();
  }


  // ── Charger les forêts ────────────────────────────────
  Future<void> _loadForests() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final collection = await _service.getForestsGeoJson();
      setState(() {
        _forests   = collection.features;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }


  // ── Convertir coordinates → LatLng ───────────────────
  List<LatLng> _toLatLng(List<List<double>> ring) {
    return ring.map((p) => LatLng(p[1], p[0])).toList();
  }


  // ── Construire polygones ──────────────────────────────
  List<Polygon> _buildPolygons() {
    return _forests.map((feature) {
      final isSelected = _selectedForest?.properties.id
          == feature.properties.id;

      return Polygon(
        points:            _toLatLng(feature.geometry.coordinates[0]),
        color:             isSelected
            ? Colors.orange.withOpacity(0.4)
            : Colors.green.withOpacity(0.3),
        borderColor:       isSelected ? Colors.orange : Colors.green,
        borderStrokeWidth: isSelected ? 3.0 : 2.0,
      );
    }).toList();
  }


  // ── Tap sur la carte ──────────────────────────────────
  void _onMapTap(TapPosition tap, LatLng point) {
  if (_isDrawingMode) {
    setState(() => _drawnPoints.add(point));
    return;
  }

  final clicked = _getClickedForest(point);
  setState(() {
    _selectedForest = clicked;
    // Position du clic en pixels sur l'écran
    _popupPosition  = clicked != null ? tap.relative : null;
  });
}


  // ── Détecter la forêt cliquée ─────────────────────────
  ForestFeature? _getClickedForest(LatLng point) {
    for (final forest in _forests) {
      final ring = forest.geometry.coordinates[0];
      if (_pointInPolygon(point, ring)) return forest;
    }
    return null;
  }


  // ── Point dans polygone (Ray casting) ─────────────────
  bool _pointInPolygon(LatLng point, List<List<double>> ring) {
    bool inside = false;
    int j = ring.length - 1;
    for (int i = 0; i < ring.length; i++) {
      final xi = ring[i][0]; final yi = ring[i][1];
      final xj = ring[j][0]; final yj = ring[j][1];
      if (((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude < (xj - xi) *
              (point.latitude - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }


  // ── Créer forêt ───────────────────────────────────────
  Future<void> _createForest(String name, String? desc) async {
    try {
      final points = _drawnPoints
          .map((p) => [p.longitude, p.latitude])
          .toList();
      await _service.createForest(name: name, points: points);
      setState(() { _isDrawingMode = false; _drawnPoints = []; });
      await _loadForests();
      _showSnack('Forêt créée !', Colors.green);
    } catch (e) {
      _showSnack('Erreur: $e', Colors.red);
    }
  }


  // ── Supprimer forêt ───────────────────────────────────
  Future<void> _deleteForest(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous supprimer cette forêt ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.deleteForest(id);
      setState(() => _selectedForest = null);
      await _loadForests();
      _showSnack('Forêt supprimée !', Colors.green);
    } catch (e) {
      _showSnack('Erreur: $e', Colors.red);
    }
  }


  // Snackbar 
  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  // Confirmer le redessin 
void _confirmRedraw() {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirmer la modification'),
      content: Text(
        'Modifier la forêt "${_editingForest!.properties.name}" '
        'avec le nouveau polygone ?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await _updateForestWithPolygon();
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: const Text('Confirmer',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}
// ── Update nom + description seulement ───────────────
  Future<void> _updateForestInfo(
    String id,
    String name,
  ) async {
    try {
      await _service.updateForest(
        id:          id,
        name:        name,
      );
      await _loadForests();
      _showSnack('Forêt modifiée !', Colors.green);
    } catch (e) {
      _showSnack('Erreur: $e', Colors.red);
    }
  }


// ── Update forêt avec nouveau polygone ────────────────
Future<void> _updateForestWithPolygon() async {
  try {
    final points = _drawnPoints
        .map((p) => [p.longitude, p.latitude])
        .toList();

    // Ferme le polygone
    if (points.first[0] != points.last[0] ||
        points.first[1] != points.last[1]) {
      points.add(points.first);
    }

    await _service.updateForest(
      id:          _editingForest!.properties.id,
      name:        _editingName,
      points:      points,
    );

    setState(() {
      _isDrawingMode = false;
      _isRedrawMode  = false;
      _drawnPoints   = [];
      _editingForest = null;
    });

    await _loadForests();
    _showSnack('Forêt modifiée avec succès !', Colors.green);
  } catch (e) {
    _showSnack('Erreur: $e', Colors.red);
  }
}


  
  // ── UI principale ─────────────────────────────────────
@override
Widget build(BuildContext context) {
  return Scaffold(

    // ── Navbar globale en haut ─────────────────────────
    appBar: AppBar(
      toolbarHeight: 48,
      backgroundColor: const Color.fromARGB(255, 242, 255, 243),
      elevation: 0,
      titleSpacing: 0,
      title: Row(
        children: [
          // Bouton menu sidebar
          IconButton(
            icon: Icon(
              _sidebarOpen ? Icons.menu : Icons.menu_open,
              color: const Color.fromARGB(255, 40, 99, 32),
              size: 20,
            ),
            onPressed: () =>
                setState(() => _sidebarOpen = !_sidebarOpen),
          ),
          const Text(
            'Ghabetna ',
            style: TextStyle(
              color:        const Color.fromARGB(255, 40, 99, 32),
              fontSize:      16,
              fontWeight:    FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: [
        // Avatar + dropdown
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: PopupMenuButton<Object>(
            offset: const Offset(0, 45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Container(
              width:  34,
              height: 34,
              decoration: BoxDecoration(
                color:  Colors.white24,
                shape:  BoxShape.circle,
                border: Border.all(color: Color.fromARGB(255, 40, 99, 32), width: 1.5),
              ),
              child: const Icon(Icons.person, color: Color.fromARGB(255, 40, 99, 32), size: 18),
            ),
            itemBuilder: (ctx) => <PopupMenuEntry<Object>>[
              PopupMenuItem<Object>(
                onTap: () => _showSnack(' Bientôt disponible', Colors.orange),
                child: Row(children: const [
                  Icon(Icons.manage_accounts, color:  Color.fromARGB(255, 40, 99, 32) , size: 18),
                  SizedBox(width: 10),
                  Text('Mon compte', style: TextStyle(fontSize: 13)),
                ]),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<Object>(
                onTap: () async {
                  await TokenStorage().clear();
                  _showSnack(' Déconnecté', Colors.grey);
                },
                child: Row(children: const [
                  Icon(Icons.logout, color: Colors.red, size: 18),
                  SizedBox(width: 10),
                  Text('Déconnexion',
                      style: TextStyle(fontSize: 13, color: Colors.red)),
                ]),
              ),
            ],
          ),
        ),
      ],
    ),

    // ── Body : sidebar + carte ─────────────────────────
    body: Row(
      children: [
        _buildSidebar(),
        Expanded(
          child: Stack(
            children: [
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError()
                      : _buildMap(),
              if (_isDrawingMode) _buildDrawingBar(),
              if (_selectedForest != null) _buildForestPopup(),
            ],
          ),
        ),
      ],
    ),
  );
}

  // ── Sidebar ───────────────────────────────────────────
  Widget _buildSidebar() {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 250),
    width: _sidebarOpen ? 260 : 60,
    color: const Color(0xFF1B5E20),
    child: Column(
      children: [

        // ── Gestion Utilisateurs ──────────────────
        _buildSidebarItem(
          icon:  Icons.people,
          label: 'Utilisateurs',
          onTap: () => _showSnack("9a3da nsala7 fih :(", Colors.orange),
        ),

        const Divider(color: Colors.white24),

        // ── Gestion Forêts ────────────────────────
        _buildSidebarItem(
          icon:     Icons.forest,
          label:    'Forêts',
          hasArrow: true,
          isOpen:   _forestMenuOpen,
          onTap: () => setState(() => _forestMenuOpen = !_forestMenuOpen),
        ),

        if (_forestMenuOpen && _sidebarOpen) ...[
          _buildSubItem(
            icon:  Icons.add_location,
            label: 'Ajouter une forêt',
            onTap: _userRole == 'admin'
                ? () => setState(() {
                      _isDrawingMode  = true;
                      _drawnPoints    = [];
                      _selectedForest = null;
                    })
                : () => _showSnack('Admin uniquement', Colors.red),
          ),
          _buildSubItem(
            icon:  Icons.list,
            label: 'Lister les forêts',
            onTap: () => _showForestList(),
          ),
        ],

        const Spacer(),

        _buildSidebarItem(
          icon:  Icons.refresh,
          label: 'Actualiser',
          onTap: _loadForests,
        ),
        const SizedBox(height: 16),
      ],
    ),
  );
}
  // ── Item sidebar ──────────────────────────────────────
  Widget _buildSidebarItem({
    required IconData icon,
    required String   label,
    required VoidCallback onTap,
    bool hasArrow = false,
    bool isOpen   = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: _sidebarOpen
          ? Text(label, style: const TextStyle(color: Colors.white))
          : null,
      trailing: hasArrow && _sidebarOpen
          ? Icon(
              isOpen ? Icons.expand_less : Icons.expand_more,
              color: Colors.white,
            )
          : null,
      onTap: onTap,
    );
  }


  // ── Sous-item sidebar ─────────────────────────────────
  Widget _buildSubItem({
    required IconData     icon,
    required String       label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child:   ListTile(
        leading: Icon(icon, color: Colors.greenAccent, size: 20),
        title:   Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        onTap: onTap,
      ),
    );
  }


  // ── Liste forêts (bottom sheet) ───────────────────────
  void _showForestList() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child:   Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              ' Liste des forêts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _forests.isEmpty
                  ? const Center(child: Text('Aucune forêt'))
                  : ListView.builder(
                      itemCount: _forests.length,
                      itemBuilder: (ctx, i) {
                        final f = _forests[i].properties;
                        return ListTile(
                          leading: const Icon(Icons.forest,
                              color: Colors.green),
                          title:    Text(f.name),
                          subtitle: Text(
                            '${f.areaHectares?.toStringAsFixed(1) ?? "?"} ha',
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            // Zoom sur la forêt
                            _mapController.move(
                              LatLng(f.centroidLat ?? 36.8,
                                  f.centroidLng ?? 10.1),
                              12,
                            );
                            // Sélectionner la forêt
                            setState(() {
                              _selectedForest = _forests[i];
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
Widget _buildZoomButton({
  required IconData     icon,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width:      36,
      height:     36,
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.15),
            blurRadius: 4,
          ),
        ],
      ),
      child: Icon(icon, size: 20, color: Colors.black87),
    ),
  );
}

  // ── Carte ─────────────────────────────────────────────
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        // Centré sur Tunis 🇹🇳
        initialCenter: const LatLng(36.8190, 10.1658),
        initialZoom:   10,
        onTap:         _onMapTap,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.ghabetna.forest_app',
        ),
        PolygonLayer(polygons: _buildPolygons()),

        // Points dessin
        if (_drawnPoints.isNotEmpty) ...[
          PolygonLayer(polygons: [
            Polygon(
              points:            _drawnPoints,
              color:             Colors.orange.withOpacity(0.2),
              borderColor:       Colors.orange,
              borderStrokeWidth: 2,
              isDotted:          true,
            ),
          ]),
          MarkerLayer(
            markers: _drawnPoints.map((p) => Marker(
              point:  p,
              width:  12,
              height: 12,
              child:  Container(
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            )).toList(),
          ),
        ],
        // ── Boutons Zoom ──────────────────────────────
      Positioned(
        right:  12,
        top: 16,
        child:  Column(
          children: [
            // Zoom in
            _buildZoomButton(
              icon:    Icons.add,
              onTap: () {
                final zoom = _mapController.camera.zoom;
                _mapController.move(
                  _mapController.camera.center,
                  zoom + 1,
                );
              },
            ),
            const SizedBox(height: 4),
            // Zoom out
            _buildZoomButton(
              icon:    Icons.remove,
              onTap: () {
                final zoom = _mapController.camera.zoom;
                _mapController.move(
                  _mapController.camera.center,
                  zoom - 1,
                );
              },
            ),
          ],
        ),
      ),
    ],
    );
  }


  // ── Barre dessin ──────────────────────────────────────
  Widget _buildDrawingBar() {
  final isRedraw = _isRedrawMode;
  return Positioned(
    top: 16, left: 16, right: 16,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        isRedraw ? Color.fromARGB(255, 40, 99, 32) : Colors.orange,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isRedraw ? Icons.draw : Icons.edit_location,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isRedraw
                  ? ' Redessinez le polygone — ${_drawnPoints.length} points'
                  : ' Nouveau polygone — ${_drawnPoints.length} points',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Annuler dernier point
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white),
            onPressed: () {
              if (_drawnPoints.isNotEmpty)
                setState(() => _drawnPoints.removeLast());
            },
          ),
          // Confirmer
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: () {
              if (_drawnPoints.length < 3) {
                _showSnack('Minimum 3 points', Colors.red);
                return;
              }
              if (isRedraw) {
                _confirmRedraw();  // ← confirme la modification
              } else {
                _showCreateDialog(); // ← confirme la création
              }
            },
          ),
          // Annuler tout
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => setState(() {
              _isDrawingMode = false;
              _isRedrawMode  = false;
              _drawnPoints   = [];
              _editingForest = null;
            }),
          ),
        ],
      ),
    ),
  );
}


  // ── Popup forêt sélectionnée ──────────────────────────
  Widget _buildForestPopup() {
  final f  = _selectedForest!.properties;
  final dx = _popupPosition!.dx;
  final dy = _popupPosition!.dy;

  // Évite que le popup sorte de l'écran
  final left = dx + 220 > MediaQuery.of(context).size.width
      ? dx - 230.0
      : dx + 10.0;
  final top = dy + 160 > MediaQuery.of(context).size.height
      ? dy - 170.0
      : dy + 10.0;

  return Positioned(
    left: left,
    top:  top,
    child: Material(
      elevation:    8,
      borderRadius: BorderRadius.circular(12),
      child:        Container(
        width:   220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          mainAxisSize:       MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.forest, color: Colors.green, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    f.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize:   13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedForest = null;
                    _popupPosition  = null;
                  }),
                  child: const Icon(Icons.close, size: 14, color: Colors.grey),
                ),
              ],
            ),

            const Divider(height: 10),

            // Infos
            Text(
              ' ${f.areaHectares?.toStringAsFixed(1) ?? "?"} ha',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            if (f.supervisorName != null)
              Text(
                ' ${f.supervisorName}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),

            const SizedBox(height: 8),

            // Boutons admin
            if (_userRole == 'admin')
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 28,
                      child:  OutlinedButton(
                        onPressed: () => _showEditDialog(_selectedForest!),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: const BorderSide(color: Colors.orange),
                        ),
                        child: const Text(' Modifier',
                            style: TextStyle(fontSize: 11, color: Colors.orange)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SizedBox(
                      height: 28,
                      child:  ElevatedButton(
                        onPressed: () => _deleteForest(f.id),
                        style: ElevatedButton.styleFrom(
                          padding:         EdgeInsets.zero,
                          backgroundColor: Colors.red,
                        ),
                        child: const Text(' Suppr.',
                            style: TextStyle(fontSize: 11, color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}
  // ── Dialog créer forêt ────────────────────────────────
  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🌲 Nouvelle forêt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom *',
                border:    OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              _createForest(nameCtrl.text, descCtrl.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Créer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }


  // ── Dialog modifier forêt ─────────────────────────────
    void _showEditDialog(ForestFeature forest) {
    final nameCtrl = TextEditingController(text: forest.properties.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(' Modifier la forêt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Bouton redessiner ────────────────────
            OutlinedButton.icon(
              icon:  const Icon(Icons.draw, color: Color.fromARGB(255, 40, 99, 32)),
              label: const Text(
                'Redessiner le polygone',
                style: TextStyle(color: Color.fromARGB(255, 40, 99, 32)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color.fromARGB(255, 40, 99, 32)),
              ),
              onPressed: () {
                // Sauvegarde nom + desc + forêt en cours
                setState(() {
                  _editingForest  = forest;
                  _editingName    = nameCtrl.text;
                  _isRedrawMode   = true;
                  _isDrawingMode  = true;
                  _drawnPoints    = [];
                  _selectedForest = null;
                });
                Navigator.pop(ctx);
                _showSnack(
                  'Dessinez le nouveau polygone',
                  Color.fromARGB(255, 40, 99, 32),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Modifier seulement nom + description (sans changer polygone)
              await _updateForestInfo(
                forest.properties.id,
                nameCtrl.text,
       
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Modifier', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Widget erreur ─────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(_error!),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadForests,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}