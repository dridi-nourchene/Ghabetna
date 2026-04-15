import 'package:flutter/material.dart';

class AppTheme {
  // ── Couleurs Ghabetna ─────────────────────────────────
  static const Color primary      = Color(0xFF2E7D32); // vert foncé
  static const Color primaryLight = Color(0xFF4CAF50); // vert clair
  static const Color primaryDark  = Color(0xFF1B5E20); // vert très foncé
  static const Color accent       = Color(0xFF81C784); // vert pastel
  static const Color background   = Color(0xFFF5F5F5);
  static const Color white        = Color(0xFFFFFFFF);
  static const Color error        = Color(0xFFD32F2F);
  static const Color textPrimary  = Color(0xFF212121);
  static const Color textSecondary= Color(0xFF757575);
  static const Color border       = Color(0xFFE0E0E0);

  // ── Thème principal ───────────────────────────────────
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary:   primary,
    ),
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: background,
    inputDecorationTheme: InputDecorationTheme(
      filled:          true,
      fillColor:       white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   const BorderSide(color: error),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16, vertical: 14,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: white,
        minimumSize:     const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontSize:   16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}