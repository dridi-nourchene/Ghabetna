import 'package:flutter/material.dart';

import '../theme.dart';

/// Bandeau vert à bord inférieur ondulé, commun à tous les écrans
/// d'authentification.
///
/// La courbe n'est pas un arc symétrique : elle descend en diagonale de la
/// gauche vers la droite. C'est ce déséquilibre qui donne l'aspect organique
/// de la maquette — un arc centré ferait « bulle » et non « colline ».
class CourbeHeader extends StatelessWidget {
  const CourbeHeader({
    super.key,
    required this.hauteur,
    required this.child,
  });

  final double hauteur;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // La hauteur reçue est celle de la partie pleine ; la vague déborde en
    // dessous. On ajoute la barre de statut pour que le contenu ne passe pas
    // sous l'encoche.
    final hautStatut = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: hauteur + hautStatut,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _PeintreCourbe()),
          ),
          Positioned.fill(
            top: hautStatut,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _PeintreCourbe extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final peinture = Paint()..color = AppColors.authVert;

    // Amplitude de la vague, proportionnelle à la largeur pour que la forme
    // reste identique sur un petit téléphone comme sur une tablette.
    final vague = size.width * 0.14;

    final chemin = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - vague * 0.9)
      // Deux points de contrôle : le premier tire la courbe vers le haut à
      // droite, le second la fait replonger à gauche.
      ..cubicTo(
        size.width * 0.62, size.height + vague * 0.15,
        size.width * 0.28, size.height - vague * 1.25,
        0, size.height - vague * 0.1,
      )
      ..close();

    canvas.drawPath(chemin, peinture);
  }

  // Le tracé ne dépend d'aucun état : rien à repeindre tant que la taille
  // ne change pas, et Flutter gère déjà ce cas.
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
