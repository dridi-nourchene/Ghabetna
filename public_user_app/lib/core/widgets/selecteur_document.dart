import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../fichier_joint.dart';
import '../theme.dart';

/// Ligne de dépôt d'un document.
///
/// Deux états visibles : bordure pointillée quand la pièce manque, bordure
/// pleine avec le nom du fichier et sa taille une fois déposée. Le citoyen
/// voit ce qui reste à faire sans relire les libellés un par un — utile
/// quand un chasseur armé doit fournir cinq pièces.
class SelecteurDocument extends StatelessWidget {
  const SelecteurDocument({
    super.key,
    required this.libelle,
    required this.fichier,
    required this.onChange,
  });

  final String libelle;
  final FichierJoint? fichier;
  final void Function(FichierJoint?) onChange;

  Future<void> _choisir(BuildContext context) async {
    final resultat = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      // withData force la lecture des octets : sans ça, path est renseigné
      // mais bytes reste null sur mobile, et l'envoi partirait vide.
      withData: true,
    );

    if (resultat == null || resultat.files.isEmpty) return;
    final f = resultat.files.first;
    if (f.bytes == null) return;

    // Contrôle local avant l'envoi : refuser 15 Mo ici évite de les
    // téléverser pour rien et d'attendre le refus du serveur.
    if (f.bytes!.length > FichierJoint.tailleMaxOctets) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fichier trop lourd (10 Mo maximum)')),
        );
      }
      return;
    }

    final ext = (f.extension ?? '').toLowerCase();
    final mime = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      _ => 'image/jpeg',
    };

    onChange(FichierJoint(
      nom: f.name,
      octets: f.bytes!,
      mimeType: mime,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final rempli = fichier != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: rempli ? null : () => _choisir(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(AppDims.controle),
            border: Border.all(
              color: rempli ? AppColors.border : AppColors.authVertPointille,
              width: rempli ? 0.5 : 1,
            ),
            boxShadow: rempli ? AppShadows.champ : null,
          ),
          child: Row(
            children: [
              Icon(
                rempli
                    ? Icons.description_outlined
                    : Icons.file_upload_outlined,
                size: 20,
                color: AppColors.authVert,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      libelle,
                      style: TextStyle(
                        fontSize: 14,
                        color: rempli
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (rempli)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          '${fichier!.nom} · ${fichier!.tailleLisible}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (rempli)
                GestureDetector(
                  onTap: () => onChange(null),
                  child: const Icon(Icons.close,
                      size: 18, color: AppColors.textMuted),
                )
              else
                const Text(
                  'Ajouter',
                  style: TextStyle(fontSize: 12, color: AppColors.authVert),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
