import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme.dart';

/// Zone de photo — appareil photo ou galerie, avec indicateur de GPS trouvé
/// dans les métadonnées. La photo n'est pas obligatoire : un signalement
/// sans image reste utile, forêt + type suffisent à orienter un agent.
class PhotoPicker extends StatelessWidget {
  const PhotoPicker({
    super.key,
    required this.photo,
    required this.infoGps,
    required this.onChoisir,
    required this.onRetirer,
  });

  final File? photo;
  final String? infoGps;
  final VoidCallback onChoisir;
  final VoidCallback onRetirer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: photo == null ? onChoisir : null,
          child: Container(
            width: double.infinity,
            height: 170,
            decoration: BoxDecoration(
              color: photo != null ? null : AppColors.surface2,
              borderRadius: BorderRadius.circular(AppDims.controle),
              border: Border.all(
                color: photo != null
                    ? AppColors.authVert.withOpacity(0.4)
                    : AppColors.border,
                width: photo != null ? 1.2 : 0.5,
              ),
              boxShadow: AppShadows.champ,
              image: photo != null
                  ? DecorationImage(image: FileImage(photo!), fit: BoxFit.cover)
                  : null,
            ),
            child: photo == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined,
                          size: 32, color: AppColors.authVert.withOpacity(0.6)),
                      const SizedBox(height: 8),
                      const Text(
                        'Ajouter une photo',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Appareil photo ou galerie',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                      ),
                    ],
                  )
                : Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: GestureDetector(
                      onTap: onRetirer,
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
          ),
        ),
        if (photo != null)
          GestureDetector(
            onTap: onChoisir,
            child: const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Changer la photo',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.authVert,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        if (infoGps != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: infoGps!.startsWith('✓')
                    ? const Color(0xFFE8F5EE)
                    : const Color(0xFFFFF8E6),
                borderRadius: BorderRadius.circular(AppDims.info),
              ),
              child: Text(
                infoGps!,
                style: TextStyle(
                  fontSize: 12,
                  color: infoGps!.startsWith('✓')
                      ? AppColors.authVert
                      : const Color(0xFF9C6E00),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

void afficherChoixSource(
  BuildContext context, {
  required VoidCallback surAppareilPhoto,
  required VoidCallback surGalerie,
}) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.authVert),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                surAppareilPhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.authVert),
              title: const Text('Choisir dans la galerie'),
              onTap: () {
                Navigator.pop(context);
                surGalerie();
              },
            ),
          ],
        ),
      ),
    ),
  );
}
