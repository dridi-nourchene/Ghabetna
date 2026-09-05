import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme.dart';

/// Bandeau d'identité en haut de l'accueil.
///
/// FORME : carte verte à coins arrondis, détachée des bords — et non la
/// vague de `CourbeHeader` utilisée par la connexion et l'inscription.
/// Choix arrêté sur la maquette.
///
/// La différence de forme dit quelque chose de vrai : la vague appartient au
/// parcours d'entrée, qui est linéaire et se termine. L'accueil est un point
/// de départ vers cinq destinations — une carte posée, pas un en-tête qui
/// coiffe un formulaire.
///
/// Pas de « Bonjour » : retiré volontairement du MD. Le nom seul se lit plus
/// vite et ne vieillit pas selon l'heure de la journée.
class BandeauAccueil extends StatelessWidget {
  const BandeauAccueil({
    super.key,
    required this.nom,
    required this.specialite,
    required this.solde,
  });

  final String nom;

  /// Libellé déjà mis en forme (« Chasseur », « Campeur », « Apiculteur »).
  /// Le widget ne connaît pas l'enum : c'est l'écran qui traduit.
  final String specialite;

  final int solde;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Le fond derrière la carte est crème, pas vert : les icônes de la
      // barre d'état doivent rester sombres. C'est l'inverse de ChatHeader,
      // dont l'illustration remonte jusqu'en haut de l'écran.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Android
        statusBarBrightness: Brightness.light, // iOS
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            decoration: BoxDecoration(
              color: AppColors.authVert,
              borderRadius: BorderRadius.circular(AppDims.card),
              boxShadow: AppShadows.bouton,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        nom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.authBlanc,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _PastillePortefeuille(solde: solde),
                  ],
                ),
                const SizedBox(height: 10),
                _PastilleSpecialite(libelle: specialite),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Spécialité du citoyen.
///
/// Fond pâle et texte vert foncé plutôt que l'inverse : sur un aplat vert
/// moyen, une pastille sombre passe presque inaperçue. Ici le contraste tient
/// tout seul, sans bordure ni ombre supplémentaire.
class _PastilleSpecialite extends StatelessWidget {
  const _PastilleSpecialite({required this.libelle});

  final String libelle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.authVertPale,
        borderRadius: BorderRadius.circular(AppDims.pill),
      ),
      child: Text(
        libelle,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.forestSky,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Solde de coins.
///
/// Volontairement NON tappable : il n'y a aucun écran derrière, et le MD a
/// tranché qu'il n'y en aurait pas tant que la blockchain n'est pas là. Un
/// élément qui a l'air cliquable et ne réagit pas se lit comme une panne.
///
/// Pas d'InkWell, pas de chevron, pas de curseur : la pastille se donne à
/// lire, pas à toucher.
class _PastillePortefeuille extends StatelessWidget {
  const _PastillePortefeuille({required this.solde});

  final int solde;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$solde coins',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          // Blanc très translucide : la pastille se pose sur le vert sans
          // introduire une quatrième couleur dans le bandeau.
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppDims.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 14,
              color: AppColors.authBlanc,
            ),
            const SizedBox(width: 6),
            Text(
              '$solde',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.authBlanc,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
