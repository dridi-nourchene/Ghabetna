import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../chat/data/chat_models.dart' show Specialite;
import '../../data/inscription_form.dart';

/// Étape 2 : chasseur, campeur ou apiculteur.
///
/// Chaque carte annonce ce qu'elle exigera à l'étape suivante. Le citoyen
/// sait donc AVANT de choisir s'il a les documents sous la main — sinon il
/// abandonnerait à l'étape 3 en découvrant qu'il lui manque un permis.
class EtapeSpecialite extends StatelessWidget {
  const EtapeSpecialite({
    super.key,
    required this.form,
    required this.onModif,
  });

  final InscriptionForm form;
  final VoidCallback onModif;

  static const _cartes = [
    (Specialite.chasseur, Icons.gps_fixed, 'Chasseur',
        'Permis de chasse requis'),
    (Specialite.campeur, Icons.cabin, 'Campeur',
        'Pièce d\'identité seulement'),
    (Specialite.apiculteur, Icons.hexagon_outlined, 'Apiculteur',
        'Certificat des colonies requis'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (specialite, icone, titre, exigence) in _cartes)
            _Carte(
              icone: icone,
              titre: titre,
              exigence: exigence,
              choisie: form.specialite == specialite,
              onTap: () {
                // Changer de spécialité invalide les documents déjà déposés :
                // un permis de chasse n'a aucun sens pour un apiculteur, et
                // le laisser ferait échouer la validation serveur.
                if (form.specialite != specialite) {
                  form.documents.removeWhere(
                    (cle, _) => cle != 'cin_recto' && cle != 'cin_verso',
                  );

                  // Même invariant pour les ruchers : une donnée qui n'a de
                  // sens que pour une spécialité ne survit pas à un
                  // changement de spécialité. Sans cette ligne, un retour
                  // vers apiculteur ferait réapparaître des ruchers
                  // rattachés à une déclaration abandonnée, et l'écart de
                  // colonies affiché à l'étape 3 comparerait une ancienne
                  // répartition à un nouveau certificat.
                  form.ruchers.clear();
                }
                form.specialite = specialite;
                onModif();
              },
            ),
        ],
      ),
    );
  }
}

class _Carte extends StatelessWidget {
  const _Carte({
    required this.icone,
    required this.titre,
    required this.exigence,
    required this.choisie,
    required this.onTap,
  });

  final IconData icone;
  final String titre;
  final String exigence;
  final bool choisie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(AppDims.controle),
            // Bordure épaisse plutôt qu'un fond vert plein : un fond plein
            // entrerait en concurrence avec le bouton d'action.
            border: Border.all(
              color: choisie ? AppColors.authVert : AppColors.border,
              width: choisie ? 2 : 0.5,
            ),
            boxShadow: AppShadows.champ,
          ),
          child: Row(
            children: [
              Icon(icone, size: 24, color: AppColors.authVert),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      exigence,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (choisie)
                const Icon(Icons.check, size: 18, color: AppColors.authVert),
            ],
          ),
        ),
      ),
    );
  }
}
