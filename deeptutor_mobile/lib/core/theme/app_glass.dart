import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Glass morphism tiers — blur budgets for 60fps on phone.
abstract final class AppGlass {
  static const double blurSigmaHigh = 18;
  static const double blurSigmaLow = 10;
  static const int maxBlurSurfacesPerScreen = 3;

  static Color fillColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.surfaceGlass : AppColors.surfaceGlassLight;
  }

  static Color borderColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? AppColors.surfaceGlassBorder
        : AppColors.surfaceGlassBorderLight;
  }

  /// Use reduced blur when animations disabled or low-power mode.
  static double blurSigma(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) return blurSigmaLow;
    return blurSigmaHigh;
  }

  static bool useFauxGlass(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context);
  }

  static Color borderColorStatic(bool isDark) => isDark
      ? AppColors.surfaceGlassBorder
      : AppColors.surfaceGlassBorderLight;
}
