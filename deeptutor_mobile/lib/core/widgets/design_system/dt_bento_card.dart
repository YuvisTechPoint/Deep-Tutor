import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_animations.dart';
import '../../theme/app_elevation.dart';
import '../../theme/app_gradients.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/feature_identity.dart';
import 'dt_ai_pulse.dart';

/// Unified bento tile with copper edge glow and press physics.
class DtBentoCard extends StatefulWidget {
  const DtBentoCard({
    super.key,
    required this.featureId,
    required this.onTap,
    this.spanWide = false,
    this.live = false,
    this.preview,
  });

  final FeatureId featureId;
  final VoidCallback onTap;
  final bool spanWide;
  final bool live;
  final String? preview;

  @override
  State<DtBentoCard> createState() => _DtBentoCardState();
}

class _DtBentoCardState extends State<DtBentoCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final identity = FeatureIdentity.of(widget.featureId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? AppAnimations.pressScale : 1.0,
        duration: AppAnimations.fast,
        curve: AppAnimations.liquidNav,
        child: AnimatedContainer(
          duration: AppAnimations.standard,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
            gradient: AppGradients.module(widget.featureId, isDark: isDark),
            border: Border.all(
              color: identity.accent.withValues(alpha: 0.25),
            ),
            boxShadow: AppElevation.cardDark(identity.accent),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(identity.icon, color: identity.accent, size: 22),
                  const Spacer(),
                  if (widget.live) const DtAiPulse(size: 6),
                ],
              ),
              const Spacer(),
              Text(
                identity.label,
                style: widget.spanWide
                    ? AppTextStyles.bentoHeroTitle(context)
                    : AppTextStyles.bentoTitle(context),
              ),
              if (widget.preview != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.preview!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bentoSubtitle(context),
                ),
              ] else
                Text(
                  identity.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bentoSubtitle(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
