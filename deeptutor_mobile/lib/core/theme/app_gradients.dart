import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'feature_identity.dart';

/// Mesh and module gradient presets — copper-black luxury.
abstract final class AppGradients {
  static LinearGradient meshDark({
    AlignmentGeometry? begin,
    AlignmentGeometry? end,
  }) {
    return LinearGradient(
      begin: begin ?? Alignment.topCenter,
      end: end ?? Alignment.bottomCenter,
      colors: const [
        AppColors.meshTop,
        AppColors.meshMid,
        AppColors.voidBlack,
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  static RadialGradient copperBloom({
    Alignment center = const Alignment(0.2, -0.4),
  }) =>
      RadialGradient(
        center: center,
        radius: 1.2,
        colors: [
          AppColors.copperPrimary.withValues(alpha: 0.08),
          AppColors.copperDeep.withValues(alpha: 0.03),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      );

  static LinearGradient meshLight() => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFDF9F6),
          Color(0xFFF7F5F2),
          Color(0xFFFFFFFF),
        ],
      );

  static RadialGradient copperBloomLight() => RadialGradient(
        center: const Alignment(0.3, -0.3),
        radius: 1.0,
        colors: [
          AppColors.copperPrimary.withValues(alpha: 0.06),
          Colors.transparent,
        ],
      );

  /// Translucent glass module surface — exact #FFFFFF0D with copper wash.
  static LinearGradient glassModule(
    FeatureId id, {
    bool isDark = true,
  }) {
    final accent = FeatureIdentity.of(id).accent;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.alphaBlend(
          accent.withValues(alpha: isDark ? 0.14 : 0.08),
          isDark ? AppColors.surfaceGlass : AppColors.surfaceGlassLight,
        ),
        isDark ? AppColors.surfaceGlass : AppColors.surfaceGlassLight,
      ],
    );
  }

  @Deprecated('Use glassModule for OS surfaces')
  static LinearGradient module(FeatureId id, {bool isDark = true}) =>
      glassModule(id, isDark: isDark);

  static LinearGradient copperBorder() => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.copperLight,
          AppColors.copperPrimary,
          AppColors.copperDeep,
        ],
      );

  static LinearGradient dockPill() => LinearGradient(
        colors: [
          AppColors.copperPrimary.withValues(alpha: 0.50),
          AppColors.copperDeep.withValues(alpha: 0.35),
        ],
      );

  static LinearGradient buttonPrimary() => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.copperLight, AppColors.copperPrimary],
      );

  static RadialGradient heroOrb() => RadialGradient(
        colors: [
          AppColors.copperLight.withValues(alpha: 0.9),
          AppColors.copperPrimary,
          AppColors.copperDeep.withValues(alpha: 0.8),
        ],
      );

  @Deprecated('Use copperBorder')
  static LinearGradient holographicBorder() => copperBorder();
}
