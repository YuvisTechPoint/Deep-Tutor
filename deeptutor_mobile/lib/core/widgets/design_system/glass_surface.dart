import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_glass.dart';
import '../../theme/app_spacing.dart';

/// Neo-glass panel — exact #FFFFFF0D fill, copper glow default.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.glowColor,
    this.onTap,
    this.margin,
    this.useBlur = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? glowColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final bool useBlur;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(AppSpacing.radiusXL);
    final glow = glowColor ?? AppColors.copperPrimary;
    final fauxGlass = AppGlass.useFauxGlass(context);
    final fill = AppGlass.fillColor(context);
    final border = AppGlass.borderColor(context);

    Widget inner = Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: radius,
        color: fill,
        border: Border.all(color: border, width: 1),
        gradient: isDark && !fauxGlass
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.copperPrimary.withValues(alpha: 0.06),
                  Colors.transparent,
                ],
              )
            : null,
      ),
      child: child,
    );

    if (useBlur && !fauxGlass) {
      inner = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppGlass.blurSigma(context),
            sigmaY: AppGlass.blurSigma(context),
          ),
          child: inner,
        ),
      );
    } else {
      inner = ClipRRect(borderRadius: radius, child: inner);
    }

    final surface = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: glow.withValues(alpha: 0.14),
              blurRadius: 28,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: inner,
    );

    if (onTap == null) return surface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: glow.withValues(alpha: 0.08),
        highlightColor: glow.withValues(alpha: 0.04),
        child: surface,
      ),
    );
  }
}
