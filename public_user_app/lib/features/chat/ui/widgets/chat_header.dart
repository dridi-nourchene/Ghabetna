import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../data/chat_models.dart';

/// Bandeau supérieur : décor illustré, avatar du robot, titre.
///
/// Le décor change avec la spécialité — forêt et chasseur d'un côté, ruches
/// et apiculteur de l'autre. C'est ce qui signale visuellement le domaine
/// interrogé, sans badge administratif.
class ChatHeader extends StatelessWidget {
  const ChatHeader({super.key, required this.specialite});

  final Specialite specialite;

  bool get _estApiculteur => specialite == Specialite.apiculteur;

  @override
  Widget build(BuildContext context) {
    final avatarBg =
        _estApiculteur ? AppColors.apiAvatarBg : AppColors.forestAvatarBg;
    final avatarRing =
        _estApiculteur ? AppColors.apiAvatarRing : AppColors.forestAvatarRing;
    final titre = _estApiculteur ? AppColors.apiTitle : AppColors.forestTitle;
    final sousTitre =
        _estApiculteur ? AppColors.apiSubtitle : AppColors.forestSubtitle;

    return SizedBox(
      height: AppDims.headerHeight,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _estApiculteur
                  ? _SceneApiculturePainter()
                  : _SceneChassePainter(),
            ),
          ),
          Positioned(
            top: 30,
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
                    // avec marge : le recadrage circulaire couperait
                    // l'antenne sur une image trop serrée.
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
                        color: titre,
                      ),
                    ),
                    Text(
                      'réglementation et aide',
                      style: TextStyle(fontSize: 11, color: sousTitre),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Décor forêt : collines, sapins, chasseur et son chien.
/// Coordonnées reprises du tracé SVG validé, base 300 x 86.
class _SceneChassePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 300.0;
    final sy = size.height / 86.0;
    Offset p(double x, double y) => Offset(x * sx, y * sy);
    final peindre = Paint()..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      peindre..color = AppColors.forestSky,
    );

    // Colline ondulée
    final colline = Path()
      ..moveTo(0, 66 * sy)
      ..quadraticBezierTo(50 * sx, 48 * sy, 100 * sx, 64 * sy)
      ..quadraticBezierTo(150 * sx, 74 * sy, 200 * sx, 60 * sy)
      ..quadraticBezierTo(250 * sx, 48 * sy, 300 * sx, 66 * sy)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(colline, peindre..color = AppColors.forestHill);

    // Sapins
    peindre.color = AppColors.forestTree;
    for (final t in const [
      [150.0, 64.0, 157.0, 44.0, 164.0],
      [170.0, 64.0, 179.0, 38.0, 188.0],
      [262.0, 64.0, 269.0, 46.0, 276.0],
      [283.0, 64.0, 289.0, 50.0, 295.0],
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(t[0] * sx, t[1] * sy)
          ..lineTo(t[2] * sx, t[3] * sy)
          ..lineTo(t[4] * sx, t[1] * sy)
          ..close(),
        peindre,
      );
    }

    // Chasseur : tête, tronc, jambes, bras, fusil
    peindre.color = AppColors.forestFigure;
    canvas.drawCircle(p(215, 48), 4 * sx, peindre);
    canvas.drawRect(
      Rect.fromLTWH(213 * sx, 52 * sy, 5 * sx, 11 * sy),
      peindre,
    );
    for (final j in const [
      [212.0, 63.0, 209.0, 71.0, 212.0, 71.0, 215.0, 65.0],
      [218.0, 63.0, 221.0, 71.0, 218.0, 71.0, 215.0, 65.0],
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(j[0] * sx, j[1] * sy)
          ..lineTo(j[2] * sx, j[3] * sy)
          ..lineTo(j[4] * sx, j[5] * sy)
          ..lineTo(j[6] * sx, j[7] * sy)
          ..close(),
        peindre,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(213 * sx, 54 * sy)
        ..lineTo(208 * sx, 58 * sy)
        ..lineTo(209 * sx, 60 * sy)
        ..lineTo(214 * sx, 57 * sy)
        ..close(),
      peindre,
    );
    // Le fusil, porté à l'épaule
    canvas.drawPath(
      Path()
        ..moveTo(218 * sx, 55 * sy)
        ..lineTo(228 * sx, 48 * sy)
        ..lineTo(229 * sx, 50 * sy)
        ..lineTo(219 * sx, 57 * sy)
        ..close(),
      peindre,
    );

    // Chien
    canvas.drawOval(
      Rect.fromCenter(
          center: p(234, 66), width: 12 * sx, height: 6 * sy),
      peindre,
    );
    canvas.drawPath(
      Path()
        ..moveTo(239 * sx, 64 * sy)
        ..lineTo(243 * sx, 62 * sy)
        ..lineTo(244 * sx, 64 * sy)
        ..lineTo(240 * sx, 66 * sy)
        ..close(),
      peindre,
    );
    for (final patte in const [
      [229.0, 68.0, 228.0, 71.0, 230.0, 71.0],
      [237.0, 68.0, 238.0, 71.0, 236.0, 71.0],
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(patte[0] * sx, patte[1] * sy)
          ..lineTo(patte[2] * sx, patte[3] * sy)
          ..lineTo(patte[4] * sx, patte[5] * sy)
          ..close(),
        peindre,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Décor apiculture : collines, ruches, apiculteur, abeilles.
class _SceneApiculturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 300.0;
    final sy = size.height / 86.0;
    Offset p(double x, double y) => Offset(x * sx, y * sy);
    final peindre = Paint()..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      peindre..color = AppColors.apiSky,
    );

    final colline = Path()
      ..moveTo(0, 66 * sy)
      ..quadraticBezierTo(60 * sx, 50 * sy, 120 * sx, 64 * sy)
      ..quadraticBezierTo(180 * sx, 76 * sy, 240 * sx, 60 * sy)
      ..quadraticBezierTo(270 * sx, 52 * sy, 300 * sx, 66 * sy)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(colline, peindre..color = AppColors.apiHill);

    // Ruches empilées
    peindre.color = AppColors.apiHive;
    for (final r in const [
      [252.0, 50.0, 18.0, 14.0, 55.0],
      [274.0, 46.0, 18.0, 18.0, 52.0],
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(r[0] * sx, r[1] * sy, r[2] * sx, r[3] * sy),
          Radius.circular(2 * sx),
        ),
        peindre,
      );
      canvas.drawRect(
        Rect.fromLTWH(r[0] * sx, r[4] * sy, r[2] * sx, 2.4 * sy),
        peindre..color = AppColors.apiSky,
      );
      peindre.color = AppColors.apiHive;
    }

    // Apiculteur
    peindre.color = AppColors.apiFigure;
    canvas.drawCircle(p(218, 46), 5 * sx, peindre);
    canvas.drawRect(
      Rect.fromLTWH(215 * sx, 51 * sy, 6 * sx, 12 * sy),
      peindre,
    );
    for (final j in const [
      [214.0, 63.0, 212.0, 71.0, 215.0, 71.0, 217.0, 65.0],
      [222.0, 63.0, 224.0, 71.0, 221.0, 71.0, 219.0, 65.0],
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(j[0] * sx, j[1] * sy)
          ..lineTo(j[2] * sx, j[3] * sy)
          ..lineTo(j[4] * sx, j[5] * sy)
          ..lineTo(j[6] * sx, j[7] * sy)
          ..close(),
        peindre,
      );
    }
    // Bras tendu vers les ruches
    canvas.drawPath(
      Path()
        ..moveTo(221 * sx, 54 * sy)
        ..lineTo(230 * sx, 57 * sy)
        ..lineTo(229 * sx, 59 * sy)
        ..lineTo(220 * sx, 56 * sy)
        ..close(),
      peindre,
    );

    // Abeilles
    peindre.color = AppColors.apiBee;
    canvas.drawCircle(p(238, 42), 2 * sx, peindre);
    canvas.drawCircle(p(246, 35), 1.6 * sx, peindre);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}