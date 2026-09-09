import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme.dart';
import '../data/document_apiculteur.dart';

/// Écran « Mes documents » : les formulaires officiels de l'apiculteur.
///
/// Réservé à la spécialité apiculteur — un chasseur ou un campeur n'a rien à
/// faire d'un certificat de colonies. Le routeur ne propose ce chemin qu'à
/// eux ; cet écran ne revérifie donc pas la spécialité lui-même.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  // Nom de fichier du document en cours d'ouverture ou de téléchargement.
  // Sert à désactiver ses deux boutons sans geler le reste de la liste.
  final _enCours = <String>{};

  Future<Uint8List> _lireOctets(DocumentApiculteur doc) async {
    final data = await rootBundle.load(doc.assetPath);
    return data.buffer.asUint8List();
  }

  Future<void> _voir(DocumentApiculteur doc) async {
    setState(() => _enCours.add(doc.nomFichier));
    try {
      final octets = await _lireOctets(doc);
      // OpenFilex a besoin d'un vrai chemin sur disque : on recopie l'actif
      // groupé dans l'app vers le cache, une seule fois par lancement.
      final dossier = await getTemporaryDirectory();
      final fichier = File('${dossier.path}/${doc.nomFichier}');
      if (!await fichier.exists()) {
        await fichier.writeAsBytes(octets, flush: true);
      }
      final resultat = await OpenFilex.open(fichier.path);
      if (resultat.type != ResultType.done && mounted) {
        _snack('Aucune application de lecture PDF trouvée sur cet appareil.');
      }
    } catch (_) {
      if (mounted) _snack("Impossible d'ouvrir ce document.");
    } finally {
      if (mounted) setState(() => _enCours.remove(doc.nomFichier));
    }
  }

  Future<void> _telecharger(DocumentApiculteur doc) async {
    setState(() => _enCours.add(doc.nomFichier));
    try {
      final octets = await _lireOctets(doc);
      // saveFile() avec des octets écrit directement le fichier sur mobile
      // (Android/iOS) via le sélecteur natif : pas besoin de demander la
      // permission de stockage, l'utilisateur choisit lui-même la
      // destination (Téléchargements, Fichiers, Drive...).
      final chemin = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer « ${doc.titre} »',
        fileName: doc.nomFichier,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: octets,
      );
      if (!mounted) return;
      if (chemin != null) _snack('« ${doc.titre} » enregistré.');
    } catch (_) {
      if (mounted) _snack('Téléchargement impossible.');
    } finally {
      if (mounted) setState(() => _enCours.remove(doc.nomFichier));
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface0,
      appBar: AppBar(
        backgroundColor: AppColors.apiSky,
        foregroundColor: AppColors.authBlanc,
        elevation: 0,
        title: const Text(
          'Mes documents',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
        children: [
          const _Bandeau(),
          const SizedBox(height: 14),
          for (final doc in documentsApiculteur) ...[
            _CarteDocument(
              document: doc,
              enCours: _enCours.contains(doc.nomFichier),
              onVoir: () => _voir(doc),
              onTelecharger: () => _telecharger(doc),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _Bandeau extends StatelessWidget {
  const _Bandeau();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.apiAvatarBg,
        borderRadius: BorderRadius.circular(AppDims.controle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.apiHive),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Formulaires officiels du Journal Officiel de la République '
              'Tunisienne, requis pour la déclaration et l\'identification '
              'de vos colonies.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.apiSky.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarteDocument extends StatelessWidget {
  const _CarteDocument({
    required this.document,
    required this.enCours,
    required this.onVoir,
    required this.onTelecharger,
  });

  final DocumentApiculteur document;
  final bool enCours;
  final VoidCallback onVoir;
  final VoidCallback onTelecharger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppDims.card),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: AppShadows.champ,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.apiAvatarBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.picture_as_pdf_outlined,
                    size: 20, color: AppColors.apiHive),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.titre,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      document.reference,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.apiHive,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            document.description,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: enCours ? null : onVoir,
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Voir'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.apiSky,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDims.controle),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: enCours ? null : onTelecharger,
                  icon: enCours
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.authBlanc),
                          ),
                        )
                      : const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Télécharger'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.authVert,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDims.controle),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
