// features/dossier/widgets/piece_jointe_tile.dart

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:forest_app/core/theme/app_colors.dart';
import 'package:forest_app/features/dossier/models/dossier_model.dart';
import 'package:forest_app/features/dossier/services/dossier_service.dart';

// ═══════════════════════════════════════════════════════════════
//  PIÈCE JOINTE
//
//  Pourquoi ce widget existe au lieu d'un simple Image.network :
//  sur le web, Image.network pose une balise <img> et c'est le
//  NAVIGATEUR qui va chercher le fichier. Le jeton vit dans la
//  mémoire de l'application, pas dans le navigateur — la requête
//  partirait sans en-tête Authorization et reviendrait en 401.
//
//  On télécharge donc les octets nous-mêmes, jeton compris, et on
//  les affiche depuis la mémoire avec Image.memory.
//
//  dart:html : forest_app est un tableau de bord lancé dans Chrome.
//  Ce fichier ne compilerait pas pour Android ou iOS. Si tu dois un
//  jour t'en passer, tout est isolé dans _telechargerOctets — la
//  supprimer et retirer les deux boutons de téléchargement suffit,
//  l'affichage des images continue de fonctionner.
// ═══════════════════════════════════════════════════════════════

/// Déclenche un téléchargement navigateur à partir d'octets déjà en mémoire.
///
/// Passe par une URL d'objet temporaire : le fichier n'est jamais redemandé
/// au serveur, donc aucune seconde requête à authentifier.
void _telechargerOctets(Uint8List octets, String nom, String mimeType) {
  final blob = html.Blob(<Object>[octets], mimeType);
  final url  = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', nom)
    ..click();
  html.Url.revokeObjectUrl(url);
}

/// Nom proposé au téléchargement, déduit du type MIME.
///
/// L'extension ne vient pas du nom d'origine : citizen_ms ne le conserve
/// pas, il renomme chaque fichier d'après son type de document.
String _nomFichier(PieceJointe p) {
  final ext = switch (p.mimeType) {
    'image/jpeg'      => 'jpg',
    'image/png'       => 'png',
    'image/webp'      => 'webp',
    'application/pdf' => 'pdf',
    _                 => 'bin',
  };
  return '${p.typeDocument}.$ext';
}

class PieceJointeTile extends StatefulWidget {
  final PieceJointe piece;

  const PieceJointeTile({super.key, required this.piece});

  @override
  State<PieceJointeTile> createState() => _PieceJointeTileState();
}

class _PieceJointeTileState extends State<PieceJointeTile> {
  final _service = DossierService();

  Uint8List? _octets;
  bool       _enCours = false;
  String?    _erreur;

  @override
  void initState() {
    super.initState();
    // Les images partent tout de suite : sans octets, pas de vignette, et
    // une grille de carrés vides n'apprend rien à l'admin.
    //
    // Les PDF non : ils ne produiront aucune vignette de toute façon, et
    // télécharger plusieurs mégaoctets que personne n'ouvrira serait du
    // gâchis. Ils sont récupérés au clic sur le bouton.
    if (widget.piece.estImage) _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _enCours = true;
      _erreur  = null;
    });

    try {
      final octets = await _service.telechargerPiece(widget.piece.url);
      if (!mounted) return;
      setState(() {
        _octets  = octets;
        _enCours = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enCours = false;
        _erreur  = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _telecharger() async {
    if (_octets == null) {
      await _charger();
      if (_octets == null) return;
    }
    _telechargerOctets(
      _octets!,
      _nomFichier(widget.piece),
      widget.piece.mimeType,
    );
  }

  void _agrandir() {
    if (_octets == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => _Apercu(piece: widget.piece, octets: _octets!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.piece;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 96, child: _zoneVisuelle()),

          Container(
            color: AppColors.bgCard,
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(p.libelle,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 1),
                      Text(
                        _erreur != null
                            ? 'Non chargée'
                            : [
                                p.estImage ? 'Image' : 'PDF',
                                if (p.tailleLisible.isNotEmpty)
                                  p.tailleLisible,
                              ].join(' · '),
                        style: TextStyle(
                          fontSize: 11,
                          color: _erreur != null
                              ? AppColors.danger
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _enCours ? null : _telecharger,
                  icon: const Icon(Icons.download_outlined, size: 17),
                  color: AppColors.textSecondary,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Télécharger',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoneVisuelle() {
    // Erreur : cliquable pour réessayer. Un 401 après expiration du jeton
    // ou un 404 sur un BASE_URL mal configuré se règlent souvent en
    // relançant l'appel.
    if (_erreur != null) {
      return InkWell(
        onTap: _charger,
        child: Container(
          color: AppColors.dangerBg,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, size: 19, color: AppColors.danger),
                SizedBox(height: 5),
                Text('Réessayer',
                    style: TextStyle(fontSize: 11, color: AppColors.danger)),
              ],
            ),
          ),
        ),
      );
    }

    if (_enCours) {
      return Container(
        color: AppColors.bgInput,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primaryMid),
          ),
        ),
      );
    }

    if (_octets != null) {
      return InkWell(
        onTap: _agrandir,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(_octets!, fit: BoxFit.cover),
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: const Icon(Icons.zoom_out_map,
                    size: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    // Reste le PDF, dont les octets n'ont pas encore été demandés.
    return Container(
      color: AppColors.bgInput,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf_outlined,
                size: 26, color: AppColors.textSecondary),
            SizedBox(height: 4),
            Text('PDF',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  APERÇU AGRANDI
// ═══════════════════════════════════════════════════════════════

/// Fenêtre par-dessus la page, et non une nouvelle page.
///
/// Le travail de l'admin consiste à comparer le scan avec les champs saisis.
/// S'il doit quitter la fiche à chaque document, il perd le fil de ce qu'il
/// vérifiait.
class _Apercu extends StatelessWidget {
  final PieceJointe piece;
  final Uint8List   octets;

  const _Apercu({required this.piece, required this.octets});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
              decoration: const BoxDecoration(
                border: Border(
                    bottom:
                        BorderSide(color: AppColors.border, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(piece.libelle,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ),
                  IconButton(
                    onPressed: () => _telechargerOctets(
                        octets, _nomFichier(piece), piece.mimeType),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    color: AppColors.textSecondary,
                    tooltip: 'Télécharger',
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.textSecondary,
                    tooltip: 'Fermer',
                  ),
                ],
              ),
            ),

            Flexible(
              child: Container(
                color: AppColors.bgInput,
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                // InteractiveViewer : une CIN photographiée de travers se lit
                // mal en taille fixe. L'admin peut zoomer sur le numéro.
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Center(
                    child: Image.memory(octets, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
