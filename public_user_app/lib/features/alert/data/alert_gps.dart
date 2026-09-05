import 'dart:io';

import 'package:exif/exif.dart';
import 'package:geolocator/geolocator.dart';

/// Localisation d'un signalement — parité avec agent_app (même logique,
/// même seuil anti-fraude) : le citoyen doit pouvoir situer un incident
/// aussi précisément qu'un agent, sans quoi le superviseur reçoit deux
/// classes de signalements de fiabilité différente.
class AlertGps {
  AlertGps._();

  /// Position du téléphone au moment de l'envoi — repli quand la photo ne
  /// contient pas de GPS EXIF (capture d'écran, appareil sans capteur…).
  static Future<({double lat, double lng})?> positionTelephone() async {
    try {
      final serviceActif = await Geolocator.isLocationServiceEnabled();
      if (!serviceActif) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      // (0, 0) n'est jamais une position réelle pour une forêt tunisienne
      // — c'est un point au large du Ghana. Certains téléphones/émulateurs
      // renvoient cette valeur "stub" au lieu de lever une exception quand
      // aucun fix GPS n'a encore été obtenu ; sans ce garde-fou, l'alerte
      // partirait avec une localisation fausse plutôt qu'absente.
      if (position.latitude == 0 && position.longitude == 0) return null;

      return (lat: position.latitude, lng: position.longitude);
    } catch (_) {
      return null;
    }
  }

  /// GPS lu dans les métadonnées EXIF de la photo. Rejeté si la photo a
  /// plus d'une heure : sans ce garde-fou, une ancienne photo réutilisée
  /// ferait croire à un incident récent à un endroit qui ne l'est plus.
  static Future<({double lat, double lng})?> depuisPhoto(
      File photo) async {
    try {
      final octets = await photo.readAsBytes();
      final data = await readExifFromBytes(octets);
      if (data.isEmpty) return null;

      final latTag = data['GPS GPSLatitude'];
      final lngTag = data['GPS GPSLongitude'];
      final latRef = data['GPS GPSLatitudeRef'];
      final lngRef = data['GPS GPSLongitudeRef'];
      final dateTag = data['EXIF DateTimeOriginal'] ?? data['Image DateTime'];

      if (latTag == null || lngTag == null) return null;

      // De nombreux téléphones (Samsung notamment) réservent toujours un
      // bloc GPS dans le JPEG, même géotagage désactivé à la prise de vue :
      // les tags existent mais avec des références vides ("" au lieu de
      // "N"/"S"/"E"/"W") et des ratios à 0/0. C'est un bloc PLACEHOLDER, pas
      // une vraie position — détecté ici, avant même de calculer les degrés
      // décimaux.
      if ((latRef?.printable.isEmpty ?? true) ||
          (lngRef?.printable.isEmpty ?? true)) {
        return null;
      }

      if (dateTag != null) {
        try {
          final texte = dateTag.printable
              .replaceFirst(':', '-')
              .replaceFirst(':', '-');
          final date = DateTime.parse(texte);
          final diff = DateTime.now().difference(date).abs();
          if (diff.inHours > 1) {
            // ignore: avoid_print
            print('[EXIF] Photo trop ancienne (${diff.inHours}h) — GPS ignoré');
            return null;
          }
        } catch (_) {
          // Date illisible : on garde quand même le GPS.
        }
      }

      double versDecimal(IfdTag tag) {
        final valeurs = tag.values.toList();
        final deg = (valeurs[0] as Ratio).toDouble();
        final min = (valeurs[1] as Ratio).toDouble();
        final sec = (valeurs[2] as Ratio).toDouble();
        return deg + (min / 60.0) + (sec / 3600.0);
      }

      double lat = versDecimal(latTag);
      double lng = versDecimal(lngTag);
      if (latRef?.printable == 'S') lat = -lat;
      if (lngRef?.printable == 'W') lng = -lng;

      // Un tag GPS mal formé donne un décimal exactement nul plutôt qu'une
      // exception — (0,0) n'existe pas dans une forêt tunisienne, donc
      // c'est un signal d'échec, pas une vraie position.
      if (lat == 0 && lng == 0) return null;

      return (lat: lat, lng: lng);
    } catch (e) {
      // ignore: avoid_print
      print('[EXIF] Erreur : $e');
      return null;
    }
  }
}
