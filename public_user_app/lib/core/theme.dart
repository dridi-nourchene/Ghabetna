import 'package:flutter/material.dart';

/// Palette de l'application.
///
/// Les valeurs sont reprises telles quelles de la maquette validée.
/// Ne pas les modifier sans revalider le design : les nuances ont été
/// choisies une par une.
class AppColors {
  AppColors._();

  // --- Surfaces ---------------------------------------------------------
  static const surface2 = Color(0xFFFFFFFF); // cartes, bulles du bot
  static const surface1 = Color(0xFFF0EEE6); // champ de saisie
  static const surface0 = Color(0xFFFAF9F5); // fond de la conversation
  static const border = Color(0xFFE5E3DC);

  // --- Texte ------------------------------------------------------------
  static const textPrimary = Color(0xFF1A1A18);
  static const textSecondary = Color(0xFF6B6A65);
  static const textMuted = Color(0xFF9B9A94);

  // --- Bandeau chasse ---------------------------------------------------
  static const forestSky = Color(0xFF173404);
  static const forestHill = Color(0xFF27500A);
  static const forestTree = Color(0xFF3B6D11);
  static const forestFigure = Color(0xFF0D1F02);
  static const forestAvatarBg = Color(0xFFEAF3DE);
  static const forestAvatarRing = Color(0xFF97C459);
  static const forestTitle = Color(0xFFEAF3DE);
  static const forestSubtitle = Color(0xFFC0DD97);

  // --- Bandeau apiculture ----------------------------------------------
  static const apiSky = Color(0xFF04342C);
  static const apiHill = Color(0xFF085041);
  static const apiHive = Color(0xFF0F6E56);
  static const apiFigure = Color(0xFF04211B);
  static const apiBee = Color(0xFF5DCAA5);
  static const apiAvatarBg = Color(0xFFE1F5EE);
  static const apiAvatarRing = Color(0xFF5DCAA5);
  static const apiTitle = Color(0xFFE1F5EE);
  static const apiSubtitle = Color(0xFF9FE1CB);

  // --- Conversation (bleu) ---------------------------------------------
  static const bubbleUserBg = Color(0xFFE6F1FB);
  static const bubbleUserText = Color(0xFF042C53);
  static const accentBlue = Color(0xFF378ADD); // liseré, points de frappe
  static const accentBlueDark = Color(0xFF185FA5); // icônes, titre du verdict
  static const infoBg = Color(0xFFE6F1FB);
  static const infoText = Color(0xFF042C53);
  static const dot1 = Color(0xFF378ADD);
  static const dot2 = Color(0xFF85B7EB);
  static const dot3 = Color(0xFFB5D4F4);

  // --- Bandeau d'erreur (ambre) ------------------------------------------
  // Volontairement distinct du bleu de la conversation : une erreur ne
  // doit jamais pouvoir être confondue avec une réponse de Ghabetna.
  static const errorBg = Color(0xFFFDEDD3);
  static const errorBorder = Color(0xFFE8BE71);
  static const errorText = Color(0xFF6B3D06);
  static const suggestionBorder = Color(0xFFB5D4F4);

  // --- Bouton d'envoi : vert translucide --------------------------------
  static const sendActiveBg = Color(0x38639922); // 22 %
  static const sendActiveBorder = Color(0x73639922); // 45 %
  static const sendActiveIcon = Color(0xFF3B6D11);
  static const sendIdleBg = Color(0x1A639922); // 10 %
  static const sendIdleBorder = Color(0x40639922); // 25 %
  static const sendIdleIcon = Color(0x733B6D11); // 45 %
}

/// Rayons et espacements de la maquette.
class AppDims {
  AppDims._();
  static const double card = 22;
  // Coins UNIFORMES pour les deux bulles (utilisateur et assistant) : plus
  // de coin "rentré" d'un côté. L'alignement gauche/droite dans le fil
  // suffit à distinguer qui parle.
  static const double bubble = 16;
  static const double info = 10;
  static const double suggestion = 12;
  static const double pill = 20;
  // +14 par rapport a l'original : compense le decalage du contenu
  // vers le bas, sans quoi l'avatar deborderait du bandeau.
  static const double headerHeight = 100;
  static const double avatar = 46;
  static const double sendButton = 36;
}

/// Ombre partagée par toutes les bulles de conversation (utilisateur,
/// assistant, indicateur de frappe, bandeau d'erreur).
///
/// Deux couches, faible opacité, teintées de vert forêt plutôt que du gris
/// neutre par défaut : les bulles se détachent du fond crème sans donner
/// une impression de relief trop appuyée.
class AppShadows {
  AppShadows._();
  static const List<BoxShadow> bulle = [
    BoxShadow(
      color: Color(0x14173404),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x0D173404),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.surface0,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.forestTree,
      surface: AppColors.surface2,
    ),
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      bodyMedium: TextStyle(
        fontSize: 13,
        height: 1.55,
        color: AppColors.textPrimary,
      ),
    ),
  );
}