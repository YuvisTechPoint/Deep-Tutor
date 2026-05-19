import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_animations.dart';
import '../../theme/app_elevation.dart';
import '../../theme/app_glass.dart';
import '../../theme/app_gradients.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/feature_identity.dart';
import '../bento/bento_grid.dart';

export '../bento/bento_grid.dart' show BentoDensity;

/// Adaptive premium module card — glow, press physics, density layouts.
class PremiumModuleCard extends StatefulWidget {
  const PremiumModuleCard({
    super.key,
    this.featureId,
    this.icon,
    this.label,
    this.subtitle,
    this.color,
    required this.onTap,
    this.badge,
    this.density = BentoDensity.standard,
    this.minHeight,
    @Deprecated('Use density and intrinsic height instead') this.height,
    this.flex = 0,
    this.showPulse = false,
    this.accentWidget,
    this.preview,
    this.width,
  });

  final FeatureId? featureId;
  final IconData? icon;
  final String? label;
  final String? subtitle;
  final Color? color;
  final VoidCallback onTap;
  final String? badge;
  final BentoDensity density;
  final double? minHeight;
  final double? height;
  final int flex;
  final bool showPulse;
  final Widget? accentWidget;
  final Widget? preview;
  final double? width;

  @override
  State<PremiumModuleCard> createState() => _PremiumModuleCardState();
}

class _PremiumModuleCardState extends State<PremiumModuleCard>
    with TickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;
  AnimationController? _pulse;

  FeatureIdentity get _identity {
    if (widget.featureId != null) {
      return FeatureIdentity.of(widget.featureId!);
    }
    return FeatureIdentity(
      id: FeatureId.learn,
      label: widget.label ?? '',
      subtitle: widget.subtitle ?? '',
      icon: widget.icon ?? Icons.apps,
      accent: widget.color ?? Colors.blue,
    );
  }

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: AppAnimations.fast,
      lowerBound: 0,
      upperBound: 1,
      value: 1,
    );
    _scale = Tween<double>(begin: 0.96, end: 1).animate(
      CurvedAnimation(parent: _press, curve: AppAnimations.enter),
    );
    if (widget.showPulse) {
      _pulse = AnimationController(
        vsync: this,
        duration: AppAnimations.pulse,
      )..repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant PremiumModuleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showPulse != widget.showPulse) {
      _pulse?.dispose();
      _pulse = null;
      if (widget.showPulse) {
        _pulse = AnimationController(
          vsync: this,
          duration: AppAnimations.pulse,
        )..repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _press.dispose();
    _pulse?.dispose();
    super.dispose();
  }

  double? get _effectiveMinHeight {
    if (widget.minHeight != null) return widget.minHeight;
    // ignore: deprecated_member_use_from_same_package
    if (widget.height != null) return null;
    switch (widget.density) {
      case BentoDensity.compact:
        return null;
      case BentoDensity.standard:
        return null;
      case BentoDensity.hero:
        return AppSpacing.heroMinHeightStatic;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final id = _identity;
    final accent = widget.color ?? id.accent;
    final padding = AppSpacing.cardPadding(context);
    final fixedHeight = widget.height;

    Widget card = RepaintBoundary(
      child: GestureDetector(
        onTapDown: (_) => _press.reverse(),
        onTapUp: (_) => _press.forward(),
        onTapCancel: () => _press.forward(),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            width: widget.width,
            height: fixedHeight,
            constraints: BoxConstraints(
              minHeight: fixedHeight ?? _effectiveMinHeight ?? 0,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
              gradient: AppGradients.glassModule(
                widget.featureId ?? FeatureId.learn,
                isDark: isDark,
              ),
              border: Border.all(color: AppGlass.borderColorStatic(isDark)),
              boxShadow: [
                ...AppElevation.copperAmbient(isDark: isDark),
                ...AppElevation.glowSubtle(accent, isDark: isDark),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
              child: Stack(
                children: [
                  Positioned(
                    right: -24,
                    top: -24,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  if (widget.preview != null)
                    Positioned.fill(child: widget.preview!),
                  Padding(
                    padding: EdgeInsets.all(padding),
                    child: _buildContent(context, id, accent),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.flex > 1) {
      card = Expanded(flex: widget.flex, child: card);
    }

    return card;
  }

  Widget _buildContent(
    BuildContext context,
    FeatureIdentity id,
    Color accent,
  ) {
    final title = widget.label ?? id.label;
    final subtitle = widget.subtitle ?? id.subtitle;
    final showSubtitle =
        widget.density != BentoDensity.compact && subtitle.isNotEmpty;

    switch (widget.density) {
      case BentoDensity.compact:
        return _CompactLayout(
          icon: widget.icon ?? id.icon,
          accent: accent,
          title: title,
          subtitle: subtitle.isNotEmpty ? subtitle : null,
          badge: widget.badge,
          showPulse: widget.showPulse,
          pulse: _pulse,
        );
      case BentoDensity.standard:
      case BentoDensity.hero:
        return _StandardLayout(
          icon: widget.icon ?? id.icon,
          accent: accent,
          title: title,
          subtitle: showSubtitle ? subtitle : null,
          badge: widget.badge,
          showPulse: widget.showPulse,
          pulse: _pulse,
          accentWidget: widget.density == BentoDensity.hero
              ? widget.accentWidget
              : null,
          compactSubtitle: widget.density == BentoDensity.hero,
        );
    }
  }
}

class _CompactLayout extends StatelessWidget {
  const _CompactLayout({
    required this.icon,
    required this.accent,
    required this.title,
    this.subtitle,
    this.badge,
    this.showPulse = false,
    this.pulse,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String? subtitle;
  final String? badge;
  final bool showPulse;
  final AnimationController? pulse;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ModuleIconOrb(
          icon: icon,
          color: accent,
          pulse: pulse,
          size: 32,
          iconSize: 18,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bentoTitle(context),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bentoSubtitle(context),
                ),
              ],
            ],
          ),
        ),
        if (badge != null) _Badge(label: badge!, color: accent),
        if (showPulse)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: LiveDot(color: accent),
          ),
      ],
    );
  }
}

class _StandardLayout extends StatelessWidget {
  const _StandardLayout({
    required this.icon,
    required this.accent,
    required this.title,
    this.subtitle,
    this.badge,
    this.showPulse = false,
    this.pulse,
    this.accentWidget,
    this.compactSubtitle = false,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String? subtitle;
  final String? badge;
  final bool showPulse;
  final AnimationController? pulse;
  final Widget? accentWidget;
  final bool compactSubtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ModuleIconOrb(
              icon: icon,
              color: accent,
              pulse: pulse,
            ),
            const Spacer(),
            if (badge != null) _Badge(label: badge!, color: accent),
            if (showPulse)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: LiveDot(color: accent),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bentoTitle(context),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: compactSubtitle ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bentoSubtitle(context),
          ),
        ],
        if (accentWidget != null) ...[
          const SizedBox(height: AppSpacing.xs),
          accentWidget!,
        ],
      ],
    );
  }
}

class ModuleIconOrb extends StatelessWidget {
  const ModuleIconOrb({
    super.key,
    required this.icon,
    required this.color,
    this.pulse,
    this.size = 40,
    this.iconSize = 22,
  });

  final IconData icon;
  final Color color;
  final AnimationController? pulse;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );

    if (pulse != null) {
      iconWidget = AnimatedBuilder(
        animation: pulse!,
        builder: (context, child) {
          final glow = 0.3 + pulse!.value * 0.4;
          return DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: glow),
                  blurRadius: 12,
                ),
              ],
            ),
            child: child,
          );
        },
        child: iconWidget,
      );
    }

    return iconWidget;
  }
}

class LiveDot extends StatelessWidget {
  const LiveDot({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Waveform accent for chat modules.
class AiPulseBars extends StatelessWidget {
  const AiPulseBars({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final h = 6.0 + (i % 3) * 4.0;
        return Padding(
          padding: const EdgeInsets.only(right: 3),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 4, end: h),
            duration: Duration(milliseconds: 400 + i * 80),
            curve: Curves.easeInOut,
            builder: (context, v, _) {
              return Container(
                width: 3,
                height: v,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
