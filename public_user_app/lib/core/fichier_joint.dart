import 'dart:typed_data';

/// Un document sélectionné par le citoyen, gardé en mémoire jusqu'à l'envoi.
///
/// On stocke les octets et non le chemin : sur le web il n'y a pas de
/// chemin de fichier, et sur mobile un chemin peut devenir invalide si le
/// système nettoie son cache entre l'étape 3 et l'envoi à l'étape 4.
class FichierJoint {
  const FichierJoint({
    required this.nom,
    required this.octets,
    required this.mimeType,
  });

  final String nom;
  final Uint8List octets;
  final String mimeType;

  int get taille => octets.length;

  /// « 1,2 Mo » — affiché sous le nom du document une fois déposé.
  String get tailleLisible {
    final ko = taille / 1024;
    if (ko < 1024) return '${ko.toStringAsFixed(0)} Ko';
    return '${(ko / 1024).toStringAsFixed(1).replaceAll('.', ',')} Mo';
  }

  /// Doit rester cohérent avec MAX_SIZE_MB de citizen_ms : refuser ici
  /// évite un aller-retour réseau de plusieurs mégaoctets pour rien.
  static const int tailleMaxOctets = 10 * 1024 * 1024;

  static const Set<String> typesAcceptes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf',
  };
}
