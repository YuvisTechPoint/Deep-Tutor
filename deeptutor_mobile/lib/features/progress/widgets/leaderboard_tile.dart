import 'package:flutter/material.dart';

import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/animated_entrance.dart';
import '../../../core/widgets/dt_animated_counter.dart';
import '../../../data/repositories/achievements_repository.dart';

/// Single leaderboard row with rank styling and entrance animation.
class LeaderboardTile extends StatelessWidget {
  const LeaderboardTile({
    super.key,
    required this.entry,
    required this.index,
  });

  final LeaderboardEntry entry;
  final int index;

  Color _rankColor(int rank) => switch (rank) {
        1 => AppColors.xpGold,
        2 => const Color(0xFFC0C0C0),
        3 => const Color(0xFFCD7F32),
        _ => AppColors.grey400,
      };

  IconData? _rankIcon(int rank) => switch (rank) {
        1 => Icons.emoji_events,
        2 => Icons.military_tech_outlined,
        3 => Icons.military_tech_outlined,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isTop = entry.rank <= 3;
    final rankColor = _rankColor(entry.rank);

    return AnimatedEntrance(
      delay: AppAnimations.staggerStep * index,
      slideOffset: 16,
      child: Card(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        color: entry.isCurrentUser
            ? cs.primaryContainer.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.35
                    : 1.0,
              )
            : (isTop
                ? rankColor.withValues(alpha: 0.08)
                : cs.surfaceContainerLowest),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isTop
                ? rankColor.withValues(alpha: 0.25)
                : cs.surfaceContainerHighest,
            child: _rankIcon(entry.rank) != null
                ? Icon(_rankIcon(entry.rank), color: rankColor, size: 22)
                : Text(
                    '${entry.rank}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
          ),
          title: Text(
            entry.name,
            style: TextStyle(
              fontWeight:
                  entry.isCurrentUser ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          subtitle: entry.isCurrentUser
              ? Text(
                  'You',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                )
              : null,
          trailing: DtAnimatedCounter(
            value: entry.xp,
            suffix: ' XP',
            textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isTop ? rankColor : cs.primary,
                ),
          ),
        ),
      ),
    );
  }
}
