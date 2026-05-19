import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';

/// A shimmer-based skeleton placeholder.
///
/// Use [DtSkeleton.text], [DtSkeleton.rect], or the composable
/// [DtSkeletonList] for common patterns.
class DtSkeleton extends StatelessWidget {
  const DtSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8.0,
  });

  const DtSkeleton.text({
    super.key,
    this.width = double.infinity,
    this.height = 14.0,
    this.radius = 6.0,
  });

  const DtSkeleton.rect({
    super.key,
    this.width = double.infinity,
    this.height = 80.0,
    this.radius = 12.0,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColors.grey800 : AppColors.grey200;
    final highlight =
        isDark ? AppColors.grey600 : AppColors.grey100;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      period: const Duration(milliseconds: 1400),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// A stacked column of shimmer text lines for content placeholders.
class DtSkeletonTextBlock extends StatelessWidget {
  const DtSkeletonTextBlock({
    super.key,
    this.lines = 3,
    this.lastLineWidth = 0.65,
  });

  final int lines;
  final double lastLineWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines, (i) {
        final isFinal = i == lines - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: i < lines - 1 ? 8 : 0),
          child: FractionallySizedBox(
            widthFactor: isFinal ? lastLineWidth : 1.0,
            child: const DtSkeleton.text(),
          ),
        );
      }),
    );
  }
}

/// Pre-built card list skeleton for list views while data loads.
class DtSkeletonList extends StatelessWidget {
  const DtSkeletonList({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            DtSkeleton(width: 44, height: 44, radius: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  DtSkeleton.text(height: 13),
                  SizedBox(height: 6),
                  DtSkeleton.text(height: 11, width: 140),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
