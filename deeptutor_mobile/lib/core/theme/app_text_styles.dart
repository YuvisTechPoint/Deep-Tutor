import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic text style helpers — Space Grotesk heroes, Jakarta body, mono stats.
abstract final class AppTextStyles {
  static TextStyle _spaceGrotesk(TextStyle? base) =>
      GoogleFonts.spaceGrotesk(textStyle: base);

  static TextStyle _jetbrains(TextStyle? base) =>
      GoogleFonts.jetBrainsMono(textStyle: base);

  static TextStyle codeStyle(BuildContext context) =>
      _jetbrains(Theme.of(context).textTheme.bodyMedium).copyWith(fontSize: 13);

  static TextStyle codeBold(BuildContext context) =>
      codeStyle(context).copyWith(fontWeight: FontWeight.w700);

  static TextStyle displayLarge(BuildContext context) =>
      _spaceGrotesk(Theme.of(context).textTheme.displayLarge);

  static TextStyle headlineMedium(BuildContext context) =>
      _spaceGrotesk(Theme.of(context).textTheme.headlineMedium);

  static TextStyle titleLarge(BuildContext context) =>
      _spaceGrotesk(Theme.of(context).textTheme.titleLarge).copyWith(
        fontWeight: FontWeight.w700,
      );

  static TextStyle titleMedium(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.w600,
          );

  static TextStyle bodyLarge(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge!;

  static TextStyle bodyMedium(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!;

  static TextStyle labelSmall(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall!;

  static TextStyle caption(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall!.copyWith(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.6),
          );

  static TextStyle osHero(BuildContext context) =>
      _spaceGrotesk(Theme.of(context).textTheme.headlineLarge).copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        height: 1.05,
      );

  static TextStyle displayHero(BuildContext context) => osHero(context);

  static TextStyle osSectionLabel(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall!.copyWith(
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.65),
          );

  static TextStyle sectionTitle(BuildContext context) =>
      _spaceGrotesk(Theme.of(context).textTheme.titleMedium).copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      );

  static TextStyle osModuleTitle(BuildContext context) =>
      moduleTitle(context);

  static TextStyle moduleTitle(BuildContext context) =>
      _spaceGrotesk(Theme.of(context).textTheme.titleSmall).copyWith(
        fontWeight: FontWeight.w700,
      );

  static TextStyle meta(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall!.copyWith(
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
          );

  static TextStyle osStat(BuildContext context) => monoStat(context);

  static TextStyle monoStat(BuildContext context) =>
      _jetbrains(Theme.of(context).textTheme.titleLarge).copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static double _scaledFont(BuildContext context, double base) {
    final scaler = MediaQuery.textScalerOf(context);
    final factor = scaler.scale(1.0).clamp(0.9, 1.15);
    return base * factor;
  }

  static TextStyle bentoTitle(BuildContext context) =>
      _spaceGrotesk(Theme.of(context).textTheme.titleSmall).copyWith(
        fontSize: _scaledFont(context, 14),
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        height: 1.2,
      );

  static TextStyle bentoSubtitle(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall!.copyWith(
            fontSize: _scaledFont(context, 11),
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.55),
            height: 1.25,
          );

  static TextStyle bentoHeroTitle(BuildContext context) =>
      _spaceGrotesk(Theme.of(context).textTheme.titleMedium).copyWith(
        fontSize: _scaledFont(context, 18),
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      );

  static TextStyle bentoHeroPreview(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall!.copyWith(
            fontSize: _scaledFont(context, 12),
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.65),
            height: 1.35,
          );

  static TextStyle numericStat(BuildContext context) =>
      _spaceGrotesk(Theme.of(context).textTheme.headlineSmall).copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
