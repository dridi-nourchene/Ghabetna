import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme.dart';
import '../../data/chat_models.dart';

/// Bandeau supérieur : décor illustré, avatar du robot, titre.
///
/// Le décor change avec la spécialité — forêt et chasseur d'un côté, ruches
/// et apiculteur de l'autre. C'est ce qui signale visuellement le domaine
/// interrogé, sans badge administratif.
///
/// GESTION DE LA BARRE D'ÉTAT :
/// l'illustration s'étend SOUS l'horloge et la batterie plutôt que de
/// s'arrêter en dessous. Le vert remonte jusqu'en haut de l'écran, ce qui
/// est plus soigné qu'une bande blanche. Seul le contenu — avatar et titre —
/// est décalé vers le bas.
class ChatHeader extends StatelessWidget {
  const ChatHeader({super.key, required this.specialite});

  final Specialite specialite;

  bool get _estApiculteur => specialite == Specialite.apiculteur;

  @override
  Widget build(BuildContext context) {
    // Hauteur de la barre d'état. Varie selon l'appareil : encoche,
    // poinçon, ou rien du tout.
    final barreEtat = MediaQuery.of(context).padding.top;

    final avatarBg =
        _estApiculteur ? AppColors.apiAvatarBg : AppColors.forestAvatarBg;
    final avatarRing =
        _estApiculteur ? AppColors.apiAvatarRing : AppColors.forestAvatarRing;
    final couleurTitre =
        _estApiculteur ? AppColors.apiTitle : AppColors.forestTitle;
    final couleurSousTitre =
        _estApiculteur ? AppColors.apiSubtitle : AppColors.forestSubtitle;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Icônes de la barre d'état en clair : le bandeau est vert foncé,
      // des icônes sombres y seraient illisibles.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // Android
        statusBarBrightness: Brightness.dark, // iOS
      ),
      child: SizedBox(
        height: AppDims.headerHeight + barreEtat,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _estApiculteur
                    ? _SceneApiculturePainter(decalageHaut: barreEtat)
                    : _SceneChassePainter(decalageHaut: barreEtat),
              ),
            ),
            Positioned(
              top: barreEtat + 22,
              left: 14,
              child: Row(
                children: [
                  Container(
                    width: AppDims.avatar,
                    height: AppDims.avatar,
                    decoration: BoxDecoration(
                      color: avatarBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: avatarRing, width: 2),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: ClipOval(
                      // L'image officielle du robot. Prévoir un format carré
                      // avec marge : un recadrage circulaire sur une image
                      // trop serrée couperait l'antenne.
                      child: Image.asset(
                        'assets/images/robot_ghabetna.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.smart_toy_outlined,
                          size: 24,
                          color: avatarRing,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Assistant Ghabetna',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: couleurTitre,
                        ),
                      ),
                      Text(
                        'réglementation et aide',
                        style: TextStyle(
                          fontSize: 11,
                          color: couleurSousTitre,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Décor forêt : collines, sapins, chasseur et son chien.
/// Coordonnées reprises du tracé validé, base 300 x 86.
///
/// [decalageHaut] correspond à la barre d'état : la scène est dessinée
/// EN DESSOUS, seul le ciel remplit la zone supérieure. Sans ce décalage,
/// la silhouette du chasseur serait étirée verticalement.
class _SceneChassePainter extends CustomPainter {
  _SceneChassePainter({required this.decalageHaut});
  final double decalageHaut;

  @override
  void paint(Canvas canvas, Size size) {
    final peindre = Paint()..style = PaintingStyle.fill;

    // Le ciel couvre TOUT, barre d'état comprise.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      peindre..color = AppColors.forestSky,
    );

    final sx = size.width / 300.0;
    final sy = (size.height - decalageHaut) / 86.0;
    double px(double x) => x * sx;
    double py(double y) => decalageHaut + y * sy;

    // Colline ondulée
    final colline = Path()
      ..moveTo(0, py(66))
      ..quadraticBezierTo(px(50), py(48), px(100), py(64))
      ..quadraticBezierTo(px(150), py(74), px(200), py(60))
      ..quadraticBezierTo(px(250), py(48), px(300), py(66))
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(colline, peindre..color = AppColors.forestHill);

    // Sapins : base gauche, sommet, base droite
    peindre.color = AppColors.forestTree;
    for (final t in const [
      [150.0, 64.0, 157.0, 44.0, 164.0],
      [170.0, 64.0, 179.0, 38.0, 188.0],
      [262.0, 64.0, 269.0, 46.0, 276.0],
      [283.0, 64.0, 289.0, 50.0, 295.0],
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(px(t[0]), py(t[1]))
          ..lineTo(px(t[2]), py(t[3]))
          ..lineTo(px(t[4]), py(t[1]))
          ..close(),
        peindre,
      );
    }

    // Chasseur
    peindre.color = AppColors.forestFigure;
    canvas.drawCircle(Offset(px(215), py(48)), 4 * sx, peindre);
    canvas.drawRect(
      Rect.fromLTRB(px(213), py(52), px(218), py(63)),
      peindre,
    );
    for (final j in const [
      [212.0, 63.0, 209.0, 71.0, 212.0, 71.0, 215.0, 65.0],
      [218.0, 63.0, 221.0, 71.0, 218.0, 71.0, 215.0, 65.0],
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(px(j[0]), py(j[1]))
          ..lineTo(px(j[2]), py(j[3]))
          ..lineTo(px(j[4]), py(j[5]))
          ..lineTo(px(j[6]), py(j[7]))
          ..close(),
        peindre,
      );
    }
    // Bras vers le bas
    canvas.drawPath(
      Path()
        ..moveTo(px(213), py(54))
        ..lineTo(px(208), py(58))
        ..lineTo(px(209), py(60))
        ..lineTo(px(214), py(57))
        ..close(),
      peindre,
    );
    // Fusil porté à l'épaule
    canvas.drawPath(
      Path()
        ..moveTo(px(218), py(55))
        ..lineTo(px(228), py(48))
        ..lineTo(px(229), py(50))
        ..lineTo(px(219), py(57))
        ..close(),
      peindre,
    );

    // Chien
    canvas.drawOval(
      Rect.fromLTRB(px(228), py(63), px(240), py(69)),
      peindre,
    );
    canvas.drawPath(
      Path()
        ..moveTo(px(239), py(64))
        ..lineTo(px(243), py(62))
        ..lineTo(px(244), py(64))
        ..lineTo(px(240), py(66))
        ..close(),
      peindre,
    );
    for (final patte in const [
      [229.0, 68.0, 228.0, 71.0, 230.0, 71.0],
      [237.0, 68.0, 238.0, 71.0, 236.0, 71.0],
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(px(patte[0]), py(patte[1]))
          ..lineTo(px(patte[2]), py(patte[3]))
          ..lineTo(px(patte[4]), py(patte[5]))
          ..close(),
        peindre,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SceneChassePainter oldDelegate) =>
      oldDelegate.decalageHaut != decalageHaut;
}

/// Décor apiculture : collines, ruches, apiculteur, abeilles.
class _SceneApiculturePainter extends CustomPainter {
  _SceneApiculturePainter({required this.decalageHaut});
  final double decalageHaut;

  @override
  void paint(Canvas canvas, Size size) {
    final peindre = Paint()..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      peindre..color = AppColors.apiSky,
    );

    final sx = size.width / 300.0;
    final sy = (size.height - decalageHaut) / 86.0;
    double px(double x) => x * sx;
    double py(double y) => decalageHaut + y * sy;

    final colline = Path()
      ..moveTo(0, py(66))
      ..quadraticBezierTo(px(60), py(50), px(120), py(64))
      ..quadraticBezierTo(px(180), py(76), px(240), py(60))
      ..quadraticBezierTo(px(270), py(52), px(300), py(66))
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(colline, peindre..color = AppColors.apiHill);

    // Ruches, avec leur bande horizontale
    for (final r in const [
      [252.0, 50.0, 270.0, 64.0, 55.0],
      [274.0, 46.0, 292.0, 64.0, 52.0],
    ]) {
      peindre.color = AppColors.apiHive;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(px(r[0]), py(r[1]), px(r[2]), py(r[3])),
          Radius.circular(2 * sx),
        ),
        peindre,
      );
      peindre.color = AppColors.apiSky;
      canvas.drawRect(
        Rect.fromLTRB(px(r[0]), py(r[4]), px(r[2]), py(r[4] + 2.4)),
        peindre,
      );
    }

    // Apiculteur
    peindre.color = AppColors.apiFigure;
    canvas.drawCircle(Offset(px(218), py(46)), 5 * sx, peindre);
    canvas.drawRect(
      Rect.fromLTRB(px(215), py(51), px(221), py(63)),
      peindre,
    );
    for (final j in const [
      [214.0, 63.0, 212.0, 71.0, 215.0, 71.0, 217.0, 65.0],
      [222.0, 63.0, 224.0, 71.0, 221.0, 71.0, 219.0, 65.0],
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(px(j[0]), py(j[1]))
          ..lineTo(px(j[2]), py(j[3]))
          ..lineTo(px(j[4]), py(j[5]))
          ..lineTo(px(j[6]), py(j[7]))
          ..close(),
        peindre,
      );
    }
    // Bras tendu vers les ruches
    canvas.drawPath(
      Path()
        ..moveTo(px(221), py(54))
        ..lineTo(px(230), py(57))
        ..lineTo(px(229), py(59))
        ..lineTo(px(220), py(56))
        ..close(),
      peindre,
    );

    // Abeilles
    peindre.color = AppColors.apiBee;
    canvas.drawCircle(Offset(px(238), py(42)), 2 * sx, peindre);
    canvas.drawCircle(Offset(px(246), py(35)), 1.6 * sx, peindre);
  }

  @override
  bool shouldRepaint(covariant _SceneApiculturePainter oldDelegate) =>
      oldDelegate.decalageHaut != decalageHaut;
}