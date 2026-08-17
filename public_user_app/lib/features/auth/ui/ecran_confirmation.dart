import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/../../core/theme.dart';
import '/../../core/widgets/bouton_principal.dart';
import '/../../core/widgets/courbe_header.dart';

/// Affiché une seule fois, juste après le 201 de citizen_ms.
///
/// Ce n'est PAS un état du compte : c'est un accusé de réception. Un citoyen
/// déjà connecté a forcément un dossier approuvé, il ne reverra jamais cet
/// écran.
///
/// Pas de bouton retour dans le bandeau : le dossier est parti, il n'y a
/// plus rien à corriger. La seule sortie est le retour à la connexion.
class EcranConfirmation extends StatelessWidget {
  const EcranConfirmation({super.key, required this.profilId});

  final String profilId;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Empêche le retour matériel Android vers le formulaire : la saisie
      // n'existe plus, l'écran serait vide et le citoyen risquerait de
      // renvoyer un second dossier.
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.surface0,
        body: Column(
          children: [
            const CourbeHeader(hauteur: 132, child: SizedBox.shrink()),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 6, 28, 30),
                child: Column(
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: const BoxDecoration(
                        color: AppColors.authVertFond,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 34,
                        color: AppColors.authVert,
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Dossier envoyé',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Votre demande a bien été transmise. L\'administration '
                      'examinera vos justificatifs et vous recevrez un e-mail '
                      'dès qu\'une décision sera prise.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 26),

                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius:
                            BorderRadius.circular(AppDims.controle),
                        border: Border.all(
                            color: AppColors.border, width: 0.5),
                        boxShadow: AppShadows.champ,
                      ),
                      child: Column(
                        children: [
                          _Ligne(
                            libelle: 'Référence',
                            // Les 8 premiers caractères de l'identifiant
                            // suffisent à retrouver le dossier ; l'UUID
                            // complet serait illisible à l'écran.
                            valeur: profilId.isEmpty
                                ? '—'
                                : profilId.substring(0, 8).toUpperCase(),
                          ),
                          const Divider(
                              height: 1, color: AppColors.border, thickness: 0.5),
                          const _Ligne(
                            libelle: 'Statut',
                            valeur: 'En attente d\'examen',
                            couleur: AppColors.errorText,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    BoutonPrincipal(
                      libelle: 'Retour à la connexion',
                      onPressed: () => context.go('/login'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.libelle,
    required this.valeur,
    this.couleur = AppColors.textPrimary,
  });

  final String libelle;
  final String valeur;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(
            libelle,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const Spacer(),
          Text(valeur, style: TextStyle(fontSize: 13, color: couleur)),
        ],
      ),
    );
  }
}
