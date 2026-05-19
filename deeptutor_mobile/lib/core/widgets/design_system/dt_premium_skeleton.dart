import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Copper-gradient shimmer skeleton.
class DtPremiumSkeleton extends StatelessWidget {
  const DtPremiumSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(AppSpacing.radiusS);

    return Shimmer.fromColors(
      baseColor: isDark
          ? AppColors.surfaceGlass
          : AppColors.surfaceGlassLight,
      highlightColor: AppColors.copperPrimary.withValues(alpha: 0.15),
      period: const Duration(milliseconds: 1400),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? AppColors.voidElevated : AppColors.grey100,
          borderRadius: radius,
        ),
      ),
    );
  }
}
