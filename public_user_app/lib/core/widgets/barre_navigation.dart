import 'package:flutter/material.dart';

import '../theme.dart';

/// Une destination de la barre basse.
class Destination {
  const Destination({
    required this.route,
    required this.libelle,
    required this.icone,
  });

  final String route;
  final String libelle;
  final IconData icone;
}

/// Barre de navigation du citoyen.
///
/// Cinq DESTINATIONS, pas d'actions. « Quitter » n'y figure pas : la
/// déconnexion est définitive et se retrouverait à portée de pouce entre deux
/// onglets, exactement là où l'on tapote sans regarder. Elle vit dans Profil,
/// derrière une confirmation.
///
/// FORME : pleine largeur, deux coins arrondis en haut seulement — miroir du
/// bandeau vert, qui a les siens en bas. L'ombre est portée VERS LE HAUT,
/// puisque c'est de ce côté que se trouve le contenu à surmonter.
///
/// Toutes les entrées ont la même taille et la même icône. L'onglet actif se
/// distingue uniquement par la couleur : ni cercle, ni bouton flottant, ni
/// icône agrandie. Un seul signal, appliqué partout de la même façon.
class BarreNavigation extends StatelessWidget {
  const BarreNavigation({
    super.key,
    required this.cheminActif,
    required this.onSelect,
  });

  final String cheminActif;
  final void Function(String route) onSelect;

  /// « Accueil » est au centre — c'est le point de départ, et le pouce y
  /// arrive naturellement.
  static const destinations = <Destination>[
    Destination(
      route: '/chat',
      libelle: 'Assistant',
      icone: Icons.forum_outlined,
    ),
    Destination(
      route: '/alertes',
      libelle: 'Alertes',
      icone: Icons.notifications_none_rounded,
    ),
    Destination(
      route: '/accueil',
      libelle: 'Accueil',
      icone: Icons.home_outlined,
    ),
    Destination(
      route: '/documents',
      libelle: 'Documents',
      icone: Icons.description_outlined,
    ),
    Destination(
      route: '/profil',
      libelle: 'Profil',
      icone: Icons.person_outline_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDims.card),
        ),
        boxShadow: [
          // Décalage négatif : l'ombre monte vers le contenu.
          BoxShadow(
            color: Color(0x14173404),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(
            // spaceAround et non spaceEvenly : les cinq cellules occupent
            // chacune un cinquième exact grâce aux Expanded ci-dessous.
            children: [
              for (final d in destinations)
                Expanded(
                  child: _Onglet(
                    destination: d,
                    actif: cheminActif == d.route,
                    onTap: () => onSelect(d.route),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Onglet extends StatelessWidget {
  const _Onglet({
    required this.destination,
    required this.actif,
    required this.onTap,
  });

  final Destination destination;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final couleur = actif ? AppColors.authVert : AppColors.textMuted;

    return Semantics(
      button: true,
      selected: actif,
      label: destination.libelle,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDims.info),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(destination.icone, size: 22, color: couleur),
              const SizedBox(height: 4),
              // 10 px et ellipsis : sur un écran de 360 dp chaque cellule
              // fait 72 dp, et « Documents » est le libellé le plus long.
              // Sans cette contrainte il déborde et Flutter peint des
              // rayures jaunes en debug.
              Text(
                destination.libelle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: actif ? FontWeight.w600 : FontWeight.w400,
                  color: couleur,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
