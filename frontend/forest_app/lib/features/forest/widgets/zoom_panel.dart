// features/forest/widgets/zoom_panel.dart
//
// Widget réutilisable — panel zoom +/- pour flutter_map.
// À ajouter dans le Stack de chaque écran carte.
//
// Usage :
//   Positioned(
//     right: 14,
//     bottom: 40,
//     child: ZoomPanel(mapController: _mapController),
//   )

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ZoomPanel extends StatelessWidget {
  final MapController mapController;

  /// Position du zoom après clic (null = garde le centre actuel)
  final double? centerLat;
  final double? centerLng;

  const ZoomPanel({
    super.key,
    required this.mapController,
    this.centerLat,
    this.centerLng,
  });

  LatLng get _currentCenter => mapController.camera.center;
  double get _currentZoom   => mapController.camera.zoom;

  void _zoomIn() {
    final zoom = (_currentZoom + 1).clamp(1.0, 19.0);
    mapController.move(_currentCenter, zoom);
  }

  void _zoomOut() {
    final zoom = (_currentZoom - 1).clamp(1.0, 19.0);
    mapController.move(_currentCenter, zoom);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDDDDD), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Zoom + ──────────────────────────
          _ZoomButton(
            icon: Icons.add,
            tooltip: 'Zoom avant',
            onTap: _zoomIn,
            isTop: true,
          ),

          // Séparateur
          Container(
            height: 0.5,
            width: 38,
            color: const Color(0xFFE0E0E0),
          ),

          // ── Zoom − ──────────────────────────
          _ZoomButton(
            icon: Icons.remove,
            tooltip: 'Zoom arrière',
            onTap: _zoomOut,
            isTop: false,
          ),
        ],
      ),
    );
  }
}

// ── Bouton interne ────────────────────────────────────────────

class _ZoomButton extends StatefulWidget {
  final IconData     icon;
  final String       tooltip;
  final VoidCallback onTap;
  final bool         isTop;

  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.isTop,
  });

  @override
  State<_ZoomButton> createState() => _ZoomButtonState();
}

class _ZoomButtonState extends State<_ZoomButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown:   (_) => setState(() => _pressed = true),
        onTapUp:     (_) => setState(() => _pressed = false),
        onTapCancel: ()  => setState(() => _pressed = false),
        onTap:       widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width:  38,
          height: 38,
          decoration: BoxDecoration(
            color: _pressed
                ? const Color(0xFFE8F5E9)
                : Colors.white,
            borderRadius: BorderRadius.vertical(
              top:    widget.isTop    ? const Radius.circular(9) : Radius.zero,
              bottom: !widget.isTop  ? const Radius.circular(9) : Radius.zero,
            ),
          ),
          child: Icon(
            widget.icon,
            size:  20,
            color: _pressed
                ? const Color(0xFF2E7D32)
                : const Color(0xFF555555),
          ),
        ),
      ),
    );
  }
}