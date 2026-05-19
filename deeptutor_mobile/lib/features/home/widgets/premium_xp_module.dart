import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/design_system/glass_surface.dart';
import '../../../core/widgets/dt_animated_counter.dart';
import '../../../data/models/gamification.dart';

/// Floating premium XP / streak / milestone module.
class PremiumXpModule extends StatefulWidget {
  const PremiumXpModule({
    super.key,
    required this.state,
    this.onTap,
  });

  final GamificationState state;
  final VoidCallback? onTap;

  @override
  State<PremiumXpModule> createState() => _PremiumXpModuleState();
}

class _PremiumXpModuleState extends State<PremiumXpModule>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flame;

  @override
  void initState() {
    super.initState();
    _flame = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _flame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final progress = s.levelProgress.clamp(0.0, 1.0);

    return GlassSurface(
      onTap: widget.onTap,
      glowColor: AppColors.copperPrimary,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircularPercentIndicator(
                radius: 36,
                lineWidth: 5,
                percent: progress,
                animation: true,
                animationDuration: 900,
                circularStrokeCap: CircularStrokeCap.round,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                linearGradient: const LinearGradient(
                  colors: [AppColors.copperLight, AppColors.copperPrimary],
                ),
                center: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'LV',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white54,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      '${s.level}',
                      style: AppTextStyles.numericStat(context).copyWith(
                        color: Colors.white,
                        fontSize: 20,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Learning momentum',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const Spacer(),
                        DtAnimatedCounter(
                          value: s.xp,
                          suffix: ' XP',
                          textStyle: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: AppColors.xpGold,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) {
                          return LinearProgressIndicator(
                            value: v,
                            minHeight: 8,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.08),
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.copperPrimary,
                            ),
                          );
                        },
                      ),
                    ),
                    if (s.nextLevelXp != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${s.xpToNextLevel} XP to Level ${s.level + 1}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StreakFlame(streak: s.streak, animation: _flame),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _MilestoneStrip(
            nextLabel: s.nextLevelXp != null
                ? 'Level ${s.level + 1} unlock'
                : 'Max level',
            rank: s.rank,
            badgeCount: s.badges.length,
          ),
        ],
      ),
    );
  }
}

class _StreakFlame extends StatelessWidget {
  const _StreakFlame({required this.streak, required this.animation});
  final int streak;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final scale = 1.0 + animation.value * 0.12;
        return Transform.scale(scale: scale, child: child);
      },
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.streakFire, AppColors.xpGold],
            ).createShader(bounds),
            child: const Icon(
              Icons.local_fire_department_rounded,
              size: 32,
              color: Colors.white,
            ),
          ),
          DtAnimatedCounter(
            value: streak,
            textStyle: const TextStyle(
              color: AppColors.streakFire,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          Text(
            'day streak',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white54,
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneStrip extends StatelessWidget {
  const _MilestoneStrip({
    required this.nextLabel,
    this.rank,
    required this.badgeCount,
  });

  final String nextLabel;
  final String? rank;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniChip(
            icon: Icons.flag_rounded,
            label: nextLabel,
            color: AppColors.copperPrimary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        if (rank != null && rank!.isNotEmpty)
          Expanded(
            child: _MiniChip(
              icon: Icons.leaderboard_rounded,
              label: rank!,
              color: AppColors.copperLight,
            ),
          ),
        const SizedBox(width: AppSpacing.sm),
        _MiniChip(
          icon: Icons.military_tech_rounded,
          label: '$badgeCount badges',
          color: AppColors.xpGold,
        ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusM),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
