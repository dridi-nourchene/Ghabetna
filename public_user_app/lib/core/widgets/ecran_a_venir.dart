import 'package:flutter/material.dart';

import '../theme.dart';

/// Onglet déclaré dans la barre mais pas encore construit.
///
/// Existe pour que la barre à cinq entrées soit complète dès aujourd'hui :
/// un onglet inerte se lit comme un bug, un onglet qui dit où il en est se
/// lit comme un chantier. Trois écrans restent à faire — Alertes, Documents,
/// Profil — et ils arrivent dans cet ordre.
///
/// À SUPPRIMER au fur et à mesure. Si ce fichier est encore importé le jour
/// de la soutenance, c'est le jury qui découvrira les écrans manquants.
class EcranAVenir extends StatelessWidget {
  const EcranAVenir({
    super.key,
    required this.titre,
    required this.description,
    required this.icone,
  });

  final String titre;

  /// Ce que l'écran fera. Un écran vide est une invitation, pas une excuse :
  /// on annonce le contenu à venir plutôt que de s'excuser de son absence.
  final String description;

  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: const BoxDecoration(
                  color: AppColors.authVertFond,
                  shape: BoxShape.circle,
                ),
                child: Icon(icone, size: 27, color: AppColors.authVert),
              ),
              const SizedBox(height: 18),
              Text(
                titre,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
