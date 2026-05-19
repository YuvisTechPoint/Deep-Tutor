import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Glow and shadow tiers for premium copper surfaces.
abstract final class AppElevation {
  static List<BoxShadow> glowSubtle(Color color, {bool isDark = true}) => [
        BoxShadow(
          color: color.withValues(alpha: isDark ? 0.16 : 0.10),
          blurRadius: 16,
          spreadRadius: -6,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> glowActive(Color color, {bool isDark = true}) => [
        BoxShadow(
          color: color.withValues(alpha: isDark ? 0.32 : 0.20),
          blurRadius: 28,
          spreadRadius: -4,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: color.withValues(alpha: isDark ? 0.14 : 0.08),
          blurRadius: 48,
          spreadRadius: -12,
        ),
      ];

  static List<BoxShadow> glowFocus(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.40),
          blurRadius: 20,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> cardDark([Color? accent]) => [
        BoxShadow(
          color: AppColors.voidBlack.withValues(alpha: 0.6),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
        ...glowSubtle(accent ?? AppColors.copperPrimary),
      ];

  static List<BoxShadow> copperAmbient({bool isDark = true}) => [
        BoxShadow(
          color: AppColors.copperPrimary.withValues(alpha: isDark ? 0.08 : 0.06),
          blurRadius: 40,
          spreadRadius: -8,
          offset: const Offset(0, 4),
        ),
      ];
}
