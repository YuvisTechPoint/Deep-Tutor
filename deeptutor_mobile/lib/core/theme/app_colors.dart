import 'package:flutter/material.dart';

/// Copper-black AI OS design tokens — primary accent #D4734B, glass #FFFFFF0D.
abstract final class AppColors {
  // ── Copper brand spectrum ──────────────────────────────────────────────────
  static const copperPrimary = Color(0xFFD4734B);
  static const copperLight = Color(0xFFE8956F);
  static const copperDeep = Color(0xFF9A4F32);
  static const copperMuted = Color(0xFFB85A38);

  // Legacy aliases → copper (keep imports stable)
  static const primary = copperPrimary;
  static const primaryLight = copperLight;
  static const primaryDark = copperDeep;
  static const accent = copperPrimary;
  static const accentLight = copperLight;

  // Secondary spectrum (module differentiation)
  static const electricViolet = Color(0xFF8B5CF6);
  static const neonIndigo = Color(0xFF6366F1);
  static const deepSapphire = Color(0xFF312E81);
  static const glowingBlue = Color(0xFF38BDF8);
  static const softMagenta = Color(0xFFE879F9);
  static const holographicCyan = Color(0xFF22D3EE);
  static const warmGold = Color(0xFFE8B84A);
  static const tealAccent = Color(0xFF2DD4BF);

  // Semantic
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const error = Color(0xFFF87171);
  static const info = glowingBlue;

  // Gamification
  static const xpGold = Color(0xFFFCD34D);
  static const streakFire = Color(0xFFE8956F);
  static const levelBadge = copperPrimary;

  // ── Dark surfaces (primary experience) ─────────────────────────────────────
  static const voidBlack = Color(0xFF000000);
  static const voidDeep = Color(0xFF050505);
  static const voidElevated = Color(0xFF0A0A0A);
  static const midnight = Color(0xFF0B0B0B);
  static const navyDeep = Color(0xFF111111);
  static const surfaceElevated = Color(0xFF141414);

  /// Exact translucent fill #FFFFFF0D (~5% white).
  static const surfaceGlass = Color(0x0DFFFFFF);
  static const surfaceGlassBorder = Color(0x1FFFFFFF);

  @Deprecated('Use surfaceGlass')
  static const glassFill = surfaceGlass;
  @Deprecated('Use surfaceGlassBorder')
  static const glassBorder = surfaceGlassBorder;

  static const backgroundDark = voidBlack;
  static const surfaceDark = voidElevated;
  static const cardDark = surfaceElevated;
  static const onDark = Color(0xFFE8E8E8);

  // ── Light surfaces ─────────────────────────────────────────────────────────
  static const backgroundLight = Color(0xFFF7F5F2);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const cardLight = Color(0xFFFFFFFF);
  static const onLight = Color(0xFF0F0F0F);

  /// Light-mode glass (~5% black overlay).
  static const surfaceGlassLight = Color(0x0D000000);
  static const surfaceGlassBorderLight = Color(0x1A000000);

  // Neutral
  static const grey100 = Color(0xFFF1F5F9);
  static const grey200 = Color(0xFFE2E8F0);
  static const grey400 = Color(0xFF94A3B8);
  static const grey600 = Color(0xFF6B7280);
  static const grey800 = Color(0xFF1E1E1E);

  // Mesh gradient stops (copper ambient)
  static const meshTop = Color(0xFF1A0F0A);
  static const meshMid = Color(0xFF080808);
  static const meshAccent = Color(0xFF2D1810);

  static Color primaryOverlay(double opacity) =>
      copperPrimary.withValues(alpha: opacity);
  static Color accentOverlay(double opacity) =>
      copperPrimary.withValues(alpha: opacity);
  static Color glow(Color c, double opacity) => c.withValues(alpha: opacity);

  /// Copper-tinted derivative for module accents.
  static Color copperTint(double hueShift, {double saturation = 0.85}) {
    final hsl = HSLColor.fromColor(copperPrimary);
    return hsl
        .withHue((hsl.hue + hueShift) % 360)
        .withSaturation(saturation)
        .toColor();
  }
}

/// Feature accents — copper family with subtle hue shifts (luxury OS cohesion).
abstract final class AppFeatureColors {
  static const chat = AppColors.copperPrimary;
  static const practice = Color(0xFFD47A52);
  static const books = Color(0xFFE8A85C);
  static const missions = Color(0xFFE8956F);
  static const career = Color(0xFFC97B5A);
  static const revision = AppColors.copperLight;
  static const codeLab = Color(0xFFD48B6A);
  static const knowledge = Color(0xFFBF6E4E);
  static const learn = AppColors.copperMuted;
  static const progress = Color(0xFF34D399);
  static const roadmap = Color(0xFFE8B84A);
  static const tutorBot = Color(0xFFE07D54);
  static const whiteboard = Color(0xFFD4734B);
  static const coWriter = Color(0xFFDB8260);
  static const space = Color(0xFFB8734A);
  static const diagnostic = AppColors.copperDeep;
  static const notifications = AppColors.copperLight;
  static const settings = Color(0xFF9CA3AF);
  static const onboarding = AppColors.copperPrimary;
  static const integrations = Color(0xFFCC7A52);
}
