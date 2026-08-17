import 'package:flutter/material.dart';

import '../theme.dart';

/// Bouton d'action principal : même hauteur et même rayon que ChampTexte.
///
/// Son ombre est plus marquée que celle des champs (0,28 contre 0,12) :
/// c'est le seul écart qui installe la hiérarchie, la forme étant identique.
class BoutonPrincipal extends StatelessWidget {
  const BoutonPrincipal({
    super.key,
    required this.libelle,
    required this.onPressed,
    this.enChargement = false,
  });

  final String libelle;
  final VoidCallback? onPressed;
  final bool enChargement;

  @override
  Widget build(BuildContext context) {
    // Pendant un envoi, le bouton reste affiché mais devient inerte : le
    // masquer ferait sauter la mise en page, et le laisser actif
    // provoquerait un double envoi du formulaire.
    final actif = onPressed != null && !enChargement;

    return Container(
      height: AppDims.controle * 3.29, // 46
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDims.controle),
        boxShadow: actif ? AppShadows.bouton : null,
      ),
      child: Material(
        color: actif ? AppColors.authVert : AppColors.authVertInactif,
        borderRadius: BorderRadius.circular(AppDims.controle),
        child: InkWell(
          onTap: actif ? onPressed : null,
          borderRadius: BorderRadius.circular(AppDims.controle),
          child: Center(
            child: enChargement
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.authBlanc),
                    ),
                  )
                : Text(
                    libelle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.authBlanc,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
