import 'package:flutter/material.dart';

import '../../../../../core/theme.dart';

/// Une des deux actions proposées sur l'accueil.
///
/// `principale` ne change que la bordure : verte au lieu de grise. C'est
/// suffisant pour installer la hiérarchie entre « Signaler » et « Assistant »
/// sans donner à l'une un fond plein qui écraserait l'autre.
///
/// Aucune des deux ne doit ressembler à un bouton d'urgence : signaler un
/// dépôt de déchets n'appelle pas la même dramatisation qu'un incendie, et
/// c'est la même carte qui sert aux deux.
class CarteAction extends StatelessWidget {
  const CarteAction({
    super.key,
    required this.titre,
    required this.sousTitre,
    required this.icone,
    required this.onTap,
    this.principale = false,
  });

  final String titre;
  final String sousTitre;
  final IconData icone;
  final VoidCallback onTap;
  final bool principale;

  @override
  Widget build(BuildContext context) {
    final couleurBordure =
        principale ? AppColors.authVert : AppColors.border;

    // Trois couches, et chacune a une raison :
    //   Container → porte l'ombre. Posée plus bas, sur le Ink, elle serait
    //               peinte À L'INTÉRIEUR du Material et donc invisible.
    //   Material  → porte la couleur de fond et reçoit l'encre du tap.
    //   Container → porte la bordure, qui doit se dessiner PAR-DESSUS
    //               l'ondulation du tap, sinon elle disparaît pendant
    //               l'animation.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDims.card),
        boxShadow: AppShadows.bulle,
      ),
      child: Material(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppDims.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDims.card),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDims.card),
              border: Border.all(
                color: couleurBordure,
                width: principale ? 1.2 : 0.8,
              ),
            ),
            child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 14, 18),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.authVertFond,
                    borderRadius: BorderRadius.circular(AppDims.info),
                  ),
                  child: Icon(icone, size: 21, color: AppColors.authVert),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        titre,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        sousTitre,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
