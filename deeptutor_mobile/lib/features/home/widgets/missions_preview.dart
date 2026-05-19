import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/design_system/dt_premium_skeleton.dart';
import '../../../core/widgets/design_system/glass_surface.dart';
import '../../../data/models/gamification.dart';
import '../../../navigation/route_resolver.dart';
import '../../../navigation/router.dart';
import '../providers/home_provider.dart';

/// Today's missions on the home feed — summary + up to 3 actionable cards.
class MissionsPreview extends ConsumerWidget {
  const MissionsPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionsAsync = ref.watch(missionsTodayProvider);

    return missionsAsync.when(
      loading: () => const _SkeletonList(),
      error: (_, __) => _MissionsError(
        onRetry: () => ref.invalidate(missionsTodayProvider),
      ),
      data: (data) {
        if (data.missions.isEmpty) {
          return const _EmptyMissions();
        }
        final preview = data.missions.take(3).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MissionsSummaryBar(today: data),
            const SizedBox(height: AppSpacing.sm),
            ...preview.map((m) => _MissionItem(mission: m)),
            if (data.missions.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: TextButton(
                  onPressed: () => context.push(AppRoutes.missions),
                  child: Text(
                    'View ${data.missions.length - 3} more missions',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MissionsSummaryBar extends StatelessWidget {
  const _MissionsSummaryBar({required this.today});

  final MissionsToday today;

  @override
  Widget build(BuildContext context) {
    final ratio = today.completionRatio.clamp(0.0, 1.0);

    return GlassSurface(
      glowColor: AppFeatureColors.missions,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${today.completedCount} of ${today.totalCount} complete',
                  style: AppTextStyles.moduleTitle(context).copyWith(fontSize: 14),
                ),
                if (today.xpTarget > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${today.xpEarned} / ${today.xpTarget} daily XP',
                    style: AppTextStyles.caption(context),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 88,
            child: LinearPercentIndicator(
              padding: EdgeInsets.zero,
              percent: ratio,
              lineHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              progressColor: AppFeatureColors.missions,
              barRadius: const Radius.circular(6),
              animation: true,
              animationDuration: 500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionItem extends StatelessWidget {
  const _MissionItem({required this.mission});
  final Mission mission;

  void _onTap(BuildContext context) {
    if (mission.completed) {
      context.push(AppRoutes.missions);
      return;
    }
    if (mission.ctaHref != null) {
      openAppHref(context, mission.ctaHref!);
    } else {
      context.push(AppRoutes.missions);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rarityColor = mission.completed
        ? AppColors.success
        : (mission.xpReward >= 50
            ? AppColors.copperLight
            : AppColors.copperPrimary);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GlassSurface(
        glowColor: rarityColor,
        onTap: () => _onTap(context),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        child: Row(
          children: [
            _MissionLeading(mission: mission, rarityColor: rarityColor),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _MissionBody(mission: mission, cs: cs)),
            _XpChip(xp: mission.xpReward),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              mission.completed
                  ? Icons.check_circle_rounded
                  : Icons.chevron_right_rounded,
              color: rarityColor.withValues(alpha: 0.9),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionLeading extends StatelessWidget {
  const _MissionLeading({
    required this.mission,
    required this.rarityColor,
  });

  final Mission mission;
  final Color rarityColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            rarityColor.withValues(alpha: 0.35),
            rarityColor.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: rarityColor.withValues(alpha: 0.4)),
      ),
      child: Icon(
        mission.completed ? Icons.check_circle_rounded : Icons.bolt_rounded,
        color: rarityColor,
        size: 24,
      ),
    );
  }
}

class _MissionBody extends StatelessWidget {
  const _MissionBody({required this.mission, required this.cs});

  final Mission mission;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          mission.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                decoration:
                    mission.completed ? TextDecoration.lineThrough : null,
              ),
        ),
        if (mission.description.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            mission.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption(context),
          ),
        ],
        if (mission.target != null)
          Text(
            '${mission.progress ?? 0} / ${mission.target}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
          ),
      ],
    );
  }
}

class _XpChip extends StatelessWidget {
  const _XpChip({required this.xp});
  final int xp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.copperPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(
          color: AppColors.copperPrimary.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        '+$xp XP',
        style: const TextStyle(
          color: AppColors.copperLight,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const DtPremiumSkeleton(
          height: 52,
          borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusXL)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: DtPremiumSkeleton(
              height: 68,
              borderRadius:
                  BorderRadius.all(Radius.circular(AppSpacing.radiusXL)),
            ),
          ),
        ),
      ],
    );
  }
}

class _MissionsError extends StatelessWidget {
  const _MissionsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Could not load missions',
              style: AppTextStyles.caption(context),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyMissions extends StatelessWidget {
  const _EmptyMissions();

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: () => context.push(AppRoutes.missions),
      child: Row(
        children: [
          Icon(
            Icons.emoji_events_outlined,
            color: AppColors.copperPrimary.withValues(alpha: 0.85),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All clear for today',
                  style: AppTextStyles.moduleTitle(context).copyWith(fontSize: 15),
                ),
                Text(
                  'Open Missions for rewards and tomorrow\'s objectives',
                  style: AppTextStyles.caption(context),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
