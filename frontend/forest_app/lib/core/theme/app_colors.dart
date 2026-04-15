import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand ───────────────────────────────────────────
  static const primaryDark   = Color(0xFF1A4731); // sidebar + primary card
  static const primaryMid    = Color(0xFF1A6B45); // links, badge text
  static const primaryLight  = Color(0xFFE8F5EE); // badge bg, hover
  static const primaryAccent = Color(0xFF7ECFAA); // logo leaf icon

  // ── Background ──────────────────────────────────────
  static const bgPage        = Color(0xFFF7F8F5);
  static const bgCard        = Color(0xFFFFFFFF);
  static const bgInput       = Color(0xFFF7F8F5);

  // ── Text ────────────────────────────────────────────
  static const textPrimary   = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B7566);
  static const textMuted     = Color(0xFFA0A89A);

  // ── Border ──────────────────────────────────────────
  static const border        = Color(0xFFE8EDE4);
  static const borderLight   = Color(0xFFF0F4EC);

  // ── Semantic ────────────────────────────────────────
  static const danger        = Color(0xFFE24B4A);
  static const dangerBg      = Color(0xFFFEF2F2);
  static const warning       = Color(0xFFF59E0B);
  static const warningBg     = Color(0xFFFEF3C7);
  static const success       = Color(0xFF27A563);
  static const successBg     = Color(0xFFE8F5EE);
  static const info          = Color(0xFF185FA5);
  static const infoBg        = Color(0xFFE6F1FB);

  // ── Sidebar overlay ─────────────────────────────────
  static const sidebarActive = Color(0x26FFFFFF); // white 15%
  static const sidebarHover  = Color(0x14FFFFFF); // white 8%
  static const sidebarDivider= Color(0x1AFFFFFF); // white 10%
}