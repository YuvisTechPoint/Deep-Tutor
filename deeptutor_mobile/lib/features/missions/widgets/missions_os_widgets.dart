import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/design_system/dt_copper_button.dart';
import '../../../core/widgets/design_system/dt_premium_skeleton.dart';
import '../../../core/widgets/design_system/glass_surface.dart';
import '../../../core/widgets/dt_animated_counter.dart';
import '../../../data/models/gamification.dart';
import '../../../navigation/route_resolver.dart';
import '../providers/missions_provider.dart';

/// Shimmer placeholder for the gamification hero on missions.
class MissionsGamSkeleton extends StatelessWidget {
  const MissionsGamSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: GlassSurface(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const DtPremiumSkeleton(
                  width: 72,
                  height: 72,
                  borderRadius: BorderRadius.all(Radius.circular(36)),
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DtPremiumSkeleton(height: 18),
                      SizedBox(height: AppSpacing.sm),
                      DtPremiumSkeleton(height: 10),
                      SizedBox(height: AppSpacing.xs),
                      DtPremiumSkeleton(width: 120, height: 10),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const DtPremiumSkeleton(height: 36),
          ],
        ),
      ),
    );
  }
}

/// XP, streak, and reward balance hero — live from `GET /gamification/state`.
class MissionsGamHero extends StatelessWidget {
  const MissionsGamHero({super.key, required this.state});

  final GamificationState state;

  @override
  Widget build(BuildContext context) {
    final progress = state.levelProgress.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: GlassSurface(
        glowColor: AppColors.copperPrimary,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _LevelOrb(level: state.level, progress: progress),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mission command',
                        style: AppTextStyles.moduleTitle(context),
                      ),
                      const SizedBox(height: 4),
                      DtAnimatedCounter(
                        value: state.xp,
                        suffix: ' total XP',
                        textStyle:
                            Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppColors.copperLight,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      if (state.nextLevelXp != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${state.xpToNextLevel} XP to Level ${state.level + 1}',
                          style: AppTextStyles.caption(context),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: AppColors.streakFire,
                      size: 28,
                    ),
                    DtAnimatedCounter(
                      value: state.streak,
                      textStyle: const TextStyle(
                        color: AppColors.streakFire,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    Text('streak', style: AppTextStyles.caption(context)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearPercentIndicator(
                padding: EdgeInsets.zero,
                percent: progress,
                lineHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                progressColor: AppColors.copperPrimary,
                barRadius: const Radius.circular(8),
                animation: true,
                animationDuration: 800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.redeem_rounded,
                  size: 16,
                  color: AppColors.copperLight.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 6),
                Text(
                  '${state.rewardXpBalance} reward XP available',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.copperLight,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelOrb extends StatelessWidget {
  const _LevelOrb({required this.level, required this.progress});

  final int level;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation(AppColors.copperPrimary),
          ),
          Column(
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
                '$level',
                style: AppTextStyles.numericStat(context).copyWith(
                  color: Colors.white,
                  fontSize: 22,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Today's mission completion strip — from `GET /missions/today` totals.
class MissionsTodayProgress extends StatelessWidget {
  const MissionsTodayProgress({super.key, required this.today});

  final MissionsToday today;

  @override
  Widget build(BuildContext context) {
    final ratio = today.completionRatio.clamp(0.0, 1.0);
    final xpRatio = today.xpTarget > 0
        ? (today.xpEarned / today.xpTarget).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: GlassSurface(
        glowColor: AppColors.copperPrimary,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Today\'s progress',
                  style: AppTextStyles.moduleTitle(context).copyWith(fontSize: 16),
                ),
                const Spacer(),
                if (today.date != null)
                  Text(
                    today.date!,
                    style: AppTextStyles.caption(context),
                  ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${today.completedCount}/${today.totalCount} done',
                  style: AppTextStyles.caption(context).copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.copperPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearPercentIndicator(
              padding: EdgeInsets.zero,
              percent: ratio,
              lineHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              progressColor: AppColors.copperPrimary,
              barRadius: const Radius.circular(6),
              animation: true,
              animationDuration: 600,
            ),
            if (today.xpTarget > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${today.xpEarned} / ${today.xpTarget} daily XP target',
                style: AppTextStyles.caption(context),
              ),
              const SizedBox(height: 4),
              LinearPercentIndicator(
                padding: EdgeInsets.zero,
                percent: xpRatio,
                lineHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                progressColor: AppColors.copperLight,
                barRadius: const Radius.circular(4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Live XP ledger from `GET /gamification/xp-history`.
class MissionsXpFeed extends StatelessWidget {
  const MissionsXpFeed({super.key, required this.entries});

  final List<XpLedgerEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: GlassSurface(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent XP', style: AppTextStyles.moduleTitle(context)),
            const SizedBox(height: AppSpacing.sm),
            for (final e in entries.take(6)) ...[
              Row(
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 16,
                    color: AppColors.copperPrimary.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      e.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption(context),
                    ),
                  ),
                  Text(
                    '+${e.xp}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.copperLight,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reward catalog — `GET /missions/rewards/catalog` + claim state from gamification.
class MissionsRewardShop extends StatelessWidget {
  const MissionsRewardShop({
    super.key,
    required this.items,
    required this.shopXp,
    required this.claimingId,
    required this.onClaim,
  });

  final List<RewardCatalogItem> items;
  final int shopXp;
  final String? claimingId;
  final void Function(RewardCatalogItem item) onClaim;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'No rewards in the catalog yet.',
          style: AppTextStyles.caption(context),
          textAlign: TextAlign.center,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppSpacing.tabletBreakpoint;
        final children = items
            .map(
              (item) => _RewardTile(
                item: item,
                shopXp: shopXp,
                claiming: claimingId == item.id,
                onClaim: () => onClaim(item),
              ),
            )
            .toList();

        if (!wide) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                children[i],
              ],
            ]),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: children
                .map(
                  (c) => SizedBox(
                    width: (constraints.maxWidth - AppSpacing.sm) / 2,
                    child: c,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.item,
    required this.shopXp,
    required this.claiming,
    required this.onClaim,
  });

  final RewardCatalogItem item;
  final int shopXp;
  final bool claiming;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final canAfford = shopXp >= item.xpCost;
    final claimed = item.claimed;

    return GlassSurface(
      glowColor: AppColors.copperPrimary,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.copperPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusM),
            ),
            child: Icon(_iconFor(item.icon), color: AppColors.copperLight),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(item.description, style: AppTextStyles.caption(context)),
                const SizedBox(height: 6),
                Text(
                  '${item.xpCost} reward XP',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.copperLight,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (claimed)
            Chip(
              label: const Text('Claimed'),
              backgroundColor: AppColors.success.withValues(alpha: 0.15),
              labelStyle: const TextStyle(
                color: AppColors.success,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            )
          else
            DtCopperButton(
              label: canAfford ? 'Claim' : 'Need XP',
              expand: false,
              loading: claiming,
              onPressed: (!canAfford || claiming) ? null : onClaim,
            ),
        ],
      ),
    );
  }

  IconData _iconFor(String? key) {
    return switch (key) {
      'badge' => Icons.military_tech_rounded,
      'gift' => Icons.card_giftcard_rounded,
      'book' => Icons.menu_book_rounded,
      'coffee' => Icons.local_cafe_rounded,
      _ => Icons.redeem_rounded,
    };
  }
}

/// Live mission card — complete + CTA from backend `cta_href`.
class MissionLiveCard extends StatefulWidget {
  const MissionLiveCard({
    super.key,
    required this.mission,
    required this.completing,
    required this.onComplete,
    this.highlight = false,
  });

  final Mission mission;
  final bool completing;
  final VoidCallback onComplete;
  final bool highlight;

  @override
  State<MissionLiveCard> createState() => _MissionLiveCardState();
}

class _MissionLiveCardState extends State<MissionLiveCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.highlight) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant MissionLiveCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlight && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.highlight && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String? get _metaLine {
    final parts = <String>[];
    if (widget.mission.category != null &&
        widget.mission.category!.isNotEmpty) {
      parts.add(widget.mission.category!);
    }
    if (widget.mission.duration != null &&
        widget.mission.duration!.isNotEmpty) {
      parts.add(widget.mission.duration!);
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.mission.completed;
    final hasProgress =
        widget.mission.target != null && widget.mission.target! > 0;
    final hasCta = widget.mission.ctaHref != null &&
        widget.mission.ctaHref!.isNotEmpty &&
        resolveAppRoute(widget.mission.ctaHref!) != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final glow = widget.highlight
              ? AppColors.copperPrimary.withValues(alpha: 0.12 + _pulse.value * 0.08)
              : null;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
              boxShadow: glow != null
                  ? [
                      BoxShadow(
                        color: glow,
                        blurRadius: 24,
                        spreadRadius: -4,
                      ),
                    ]
                  : null,
            ),
            child: child,
          );
        },
        child: GlassSurface(
          glowColor: done ? AppColors.success : AppColors.copperPrimary,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    done ? Icons.check_circle_rounded : Icons.flag_rounded,
                    color: done ? AppColors.success : AppColors.copperPrimary,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.mission.title,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    decoration: done
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: done
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.5)
                                        : null,
                                  ),
                        ),
                        if (widget.mission.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.mission.description,
                            style: AppTextStyles.caption(context),
                          ),
                        ],
                        if (_metaLine != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _metaLine!,
                            style: AppTextStyles.caption(context).copyWith(
                              color: AppColors.copperPrimary
                                  .withValues(alpha: 0.75),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.copperPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusS),
                      border: Border.all(
                        color: AppColors.copperPrimary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      '+${widget.mission.xpReward} XP',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.copperLight,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
              if (hasProgress && !done) ...[
                const SizedBox(height: AppSpacing.sm),
                LinearPercentIndicator(
                  padding: EdgeInsets.zero,
                  percent: widget.mission.progressRatio.clamp(0.0, 1.0),
                  lineHeight: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  progressColor: AppColors.copperPrimary,
                  barRadius: const Radius.circular(4),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.mission.progress ?? 0} / ${widget.mission.target}',
                  style: AppTextStyles.caption(context),
                ),
              ],
              if (done)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Completed',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                const SizedBox(height: AppSpacing.md),
                LayoutBuilder(
                  builder: (context, c) {
                    final stack = c.maxWidth < 340;
                    if (stack) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (hasCta)
                            TextButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                openAppHref(
                                  context,
                                  widget.mission.ctaHref!,
                                );
                              },
                              child: const Text('Go to activity'),
                            ),
                          DtCopperButton(
                            label: 'Mark complete',
                            loading: widget.completing,
                            onPressed: widget.completing
                                ? null
                                : () {
                                    HapticFeedback.mediumImpact();
                                    widget.onComplete();
                                  },
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        if (hasCta) ...[
                          TextButton(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              openAppHref(context, widget.mission.ctaHref!);
                            },
                            child: const Text('Go to activity'),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Expanded(
                          child: DtCopperButton(
                            label: 'Mark complete',
                            loading: widget.completing,
                            onPressed: widget.completing
                                ? null
                                : () {
                                    HapticFeedback.mediumImpact();
                                    widget.onComplete();
                                  },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
