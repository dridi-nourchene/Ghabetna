// features/forest/constants/forest_constants.dart

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

// ── Carte ──────────────────────────────────────────────────────
const forestTunisiaCenter = LatLng(33.8869, 9.5375);
const forestInitialZoom   = 7.0;

const forestTileUrl =
    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

// ── Couleurs polygones forêt ───────────────────────────────────
const forestFill    = Color(0x3322C55E);
const forestBorder  = Color(0xFF16A34A);

// ── Couleurs polygones parcelle ────────────────────────────────
const parcelleFill   = Color(0x333B82F6);
const parcelleBorder = Color(0xFF2563EB);

// ── Couleurs edit (ancien/nouveau polygone) ────────────────────
const oldPolyFill   = Color(0x33888888);
const oldPolyBorder = Color(0xFF888888);
const newPolyFill   = Color(0x5522C55E);
const newPolyBorder = Color(0xFF16A34A);

// ── Couleurs accent ────────────────────────────────────────────
const forestAccent   = Color(0xFF16A34A);
const parcelleAccent = Color(0xFF2563EB);
const forestTabColor = Color(0xFF1A4731);
const parcelleTabColor = Color(0xFF1E40AF);