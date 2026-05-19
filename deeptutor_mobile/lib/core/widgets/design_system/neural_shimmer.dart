import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Premium loading shimmer with subtle orb pulse.
class NeuralShimmer extends StatefulWidget {
  const NeuralShimmer({
    super.key,
    this.lines = 6,
    this.height = 14,
  });

  final int lines;
  final double height;

  @override
  State<NeuralShimmer> createState() => _NeuralShimmerState();
}

class _NeuralShimmerState extends State<NeuralShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColors.surfaceElevated : AppColors.grey200;
    final highlight = isDark
        ? AppColors.copperPrimary.withValues(alpha: 0.25)
        : AppColors.primary.withValues(alpha: 0.12);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(widget.lines, (i) {
            final w = 1.0 - (i % 3) * 0.12;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                height: widget.height,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment(-1 + _ctrl.value * 2, 0),
                    end: Alignment(_ctrl.value * 2, 0),
                    colors: [base, highlight, base],
                  ),
                ),
                child: FractionallySizedBox(
                  widthFactor: w,
                  alignment: Alignment.centerLeft,
                  child: const SizedBox.shrink(),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Centered orb loader for full-screen states.
class OrbLoader extends StatefulWidget {
  const OrbLoader({super.key, this.color});

  final Color? color;

  @override
  State<OrbLoader> createState() => _OrbLoaderState();
}

class _OrbLoaderState extends State<OrbLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: c.withValues(alpha: 0.2 + _ctrl.value * 0.3),
                blurRadius: 24 + _ctrl.value * 12,
              ),
            ],
            gradient: RadialGradient(
              colors: [
                c.withValues(alpha: 0.9),
                c.withValues(alpha: 0.2),
              ],
            ),
          ),
        );
      },
    );
  }
}
