import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Ambient brand gradient behind scrollable content — premium app shell feel.
class PremiumBackground extends StatelessWidget {
  const PremiumBackground({
    super.key,
    required this.child,
    this.showOrbs = true,
  });

  final Widget child;
  final bool showOrbs;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryLight : AppColors.primary;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      AppColors.meshTop.withValues(alpha: 0.9),
                      AppColors.midnight,
                      AppColors.voidBlack,
                    ]
                  : [
                      primary.withValues(alpha: 0.05),
                      AppColors.backgroundLight,
                    ],
            ),
          ),
        ),
        if (showOrbs) ...[
          Positioned(
            top: -100,
            right: -40,
            child: _Orb(
              size: 240,
              color: AppColors.accent.withValues(alpha: isDark ? 0.14 : 0.1),
            ),
          ),
          Positioned(
            top: 120,
            left: -80,
            child: _Orb(
              size: 180,
              color: primary.withValues(alpha: isDark ? 0.1 : 0.08),
            ),
          ),
        ],
        child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
