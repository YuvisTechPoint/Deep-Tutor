import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/design_system/dt_ai_pulse.dart';
import '../../../core/widgets/design_system/dt_particle_field.dart';
import '../../../core/widgets/design_system/glass_surface.dart';
import '../../../navigation/router.dart';
import '../../notifications/providers/notifications_provider.dart';

/// Cinematic AI greeting hero — adaptive copy, orb presence, live indicators.
class AiHeroSection extends ConsumerStatefulWidget {
  const AiHeroSection({
    super.key,
    required this.username,
    this.insight,
  });

  final String username;
  final String? insight;

  @override
  ConsumerState<AiHeroSection> createState() => _AiHeroSectionState();
}

class _AiHeroSectionState extends ConsumerState<AiHeroSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _motivation {
    final h = DateTime.now().hour;
    if (h < 10) return 'Your focus window is open — start with one high-impact task.';
    if (h < 14) return 'Momentum builds fast. A 15-minute session compounds.';
    if (h < 20) return 'Evening review locks in retention. Quick revision wins.';
    return 'Rest well — tomorrow\'s streak starts with one small win.';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unread = ref.watch(unreadNotificationsCountProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned.fill(child: DtParticleField()),
        GlassSurface(
          glowColor: AppColors.copperPrimary,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  final scale = 1.0 + _pulse.value * 0.06;
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: _AiOrb(),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const DtAiPulse(label: 'AI ONLINE'),
                        const Spacer(),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Badge(
                            isLabelVisible: unread > 0,
                            label: Text(unread > 9 ? '9+' : '$unread'),
                            child: const Icon(Icons.notifications_none_rounded),
                          ),
                          onPressed: () =>
                              context.push(AppRoutes.notifications),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _greeting,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.55),
                            letterSpacing: 0.3,
                          ),
                    ),
                    Text(
                      widget.username,
                      style:
                          AppTextStyles.osHero(context).copyWith(fontSize: 26),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      widget.insight ?? _motivation,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.72),
                            height: 1.45,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AiOrb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  AppColors.copperLight,
                  AppColors.copperPrimary,
                  AppColors.copperDeep,
                  AppColors.copperLight,
                ],
                transform: GradientRotation(math.pi / 4),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.copperPrimary.withValues(alpha: 0.45),
                  blurRadius: 24,
                  spreadRadius: -2,
                ),
              ],
            ),
          ),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.voidElevated.withValues(alpha: 0.9),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.copperPrimary,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

