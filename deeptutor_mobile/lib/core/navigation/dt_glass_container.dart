import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_glass.dart';
import '../theme/app_spacing.dart';

/// Frosted glass surface for dock, sheets, and overlays.
class DtGlassContainer extends StatelessWidget {
  const DtGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = AppSpacing.radiusXL + 4,
    this.borderRadiusGeometry,
    this.padding,
    this.blur = 28,
  });

  final Widget child;
  final double borderRadius;
  /// When set, overrides [borderRadius] (e.g. flush bottom on phones).
  final BorderRadius? borderRadiusGeometry;
  final EdgeInsetsGeometry? padding;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = AppGlass.fillColor(context);
    final border = AppGlass.borderColor(context);

    // Dark underlay stops BackdropFilter from sampling white/empty web backdrop.
    final blurBase = isDark
        ? AppColors.voidElevated.withValues(alpha: 0.88)
        : AppColors.voidBlack.withValues(alpha: 0.75);

    final radius =
        borderRadiusGeometry ?? BorderRadius.circular(borderRadius);

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: blurBase,
                borderRadius: radius,
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: radius,
                border: Border.all(color: border, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                  if (isDark)
                    BoxShadow(
                      color: AppColors.copperPrimary.withValues(alpha: 0.12),
                      blurRadius: 24,
                      spreadRadius: -4,
                    ),
                ],
              ),
              child: Padding(
                padding: padding ?? EdgeInsets.zero,
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
