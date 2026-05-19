import 'package:flutter/material.dart';

import '../../theme/app_gradients.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/feature_identity.dart';
import 'dt_ai_pulse.dart';
import 'glass_surface.dart';

/// Feature identity banner with gradient and live indicator.
class DtModuleHeader extends StatelessWidget {
  const DtModuleHeader({
    super.key,
    required this.featureId,
    this.live = false,
    this.trailing,
  });

  final FeatureId featureId;
  final bool live;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final identity = FeatureIdentity.of(featureId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassSurface(
      glowColor: identity.accent,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusL),
              gradient: AppGradients.module(featureId, isDark: isDark),
              border: Border.all(
                color: identity.accent.withValues(alpha: 0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: identity.accent.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(identity.icon, color: identity.accent, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  identity.label,
                  style: AppTextStyles.osModuleTitle(context),
                ),
                const SizedBox(height: 2),
                Text(
                  identity.subtitle,
                  style: AppTextStyles.caption(context),
                ),
                if (live) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const DtAiPulse(label: 'LIVE'),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
