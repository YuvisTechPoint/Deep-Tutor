import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/animated_entrance.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/subpage_scaffold.dart';
import '../../../data/repositories/analytics_repository.dart';
import '../providers/progress_providers.dart';

/// Analytics dashboard with charts: XP trend, topic mastery, weak areas.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SubpageScaffold(
      title: 'Progress',
      actions: [
        IconButton(
          icon: const Icon(Icons.emoji_events_outlined),
          tooltip: 'Achievements',
          onPressed: () => context.push('/achievements'),
        ),
        IconButton(
          icon: const Icon(Icons.leaderboard_outlined),
          tooltip: 'Leaderboard',
          onPressed: () => context.push('/leaderboard'),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(analyticsSummaryProvider);
          ref.invalidate(xpTrendProvider);
          ref.invalidate(topicMasteryProvider);
          ref.invalidate(weakAreasProvider);
          ref.invalidate(timeDistributionProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const AnimatedEntrance(child: _SummaryRow()),
            const SizedBox(height: AppSpacing.md),
            AnimatedEntrance(
              delay: AppAnimations.staggerStep,
              child: const _XpTrendCard(),
            ),
            const SizedBox(height: AppSpacing.md),
            AnimatedEntrance(
              delay: AppAnimations.staggerStep * 2,
              child: const _TimeDistributionCard(),
            ),
            const SizedBox(height: AppSpacing.md),
            AnimatedEntrance(
              delay: AppAnimations.staggerStep * 3,
              child: const _TopicMasteryCard(),
            ),
            const SizedBox(height: AppSpacing.md),
            AnimatedEntrance(
              delay: AppAnimations.staggerStep * 4,
              child: const _WeakAreasCard(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends ConsumerWidget {
  const _SummaryRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(analyticsSummaryProvider);
    return AsyncValueWidget(
      value: summaryAsync,
      onRetry: () => ref.invalidate(analyticsSummaryProvider),
      builder: (s) => Row(
        children: [
          Expanded(child: _Stat(label: 'XP', value: '${s.totalXp}')),
          Expanded(child: _Stat(label: 'Streak', value: '${s.streakDays}d')),
          Expanded(
              child: _Stat(label: 'Lessons', value: '${s.lessonsCompleted}')),
          Expanded(
              child: _Stat(label: 'Weekly', value: '${s.weeklyMinutes}m')),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            Text(label,
                style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _XpTrendCard extends ConsumerWidget {
  const _XpTrendCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final xpAsync = ref.watch(xpTrendProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('XP trend',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 180,
              child: AsyncValueWidget(
                value: xpAsync,
                onRetry: () => ref.invalidate(xpTrendProvider),
                builder: (points) {
                  if (points.isEmpty) {
                    return const Center(
                        child: Text('No data yet'));
                  }
                  final spots = <FlSpot>[];
                  for (var i = 0; i < points.length; i++) {
                    spots.add(FlSpot(i.toDouble(), points[i].xp.toDouble()));
                  }
                  return LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: AppColors.primary,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.primary.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeDistributionCard extends ConsumerWidget {
  const _TimeDistributionCard();

  static const _palette = [
    AppColors.primary,
    AppColors.accent,
    AppColors.success,
    AppColors.xpGold,
    Color(0xFF8B5CF6),
    Color(0xFF0EA5E9),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distAsync = ref.watch(timeDistributionProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Study time',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            AsyncValueWidget(
              value: distAsync,
              onRetry: () => ref.invalidate(timeDistributionProvider),
              builder: (data) {
                if (data.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: Text('No time data yet — keep learning!'),
                  );
                }
                final entries = data.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                final total =
                    entries.fold<int>(0, (sum, e) => sum + e.value);
                if (total <= 0) {
                  return const Text('No time data yet');
                }

                final sections = <PieChartSectionData>[];
                for (var i = 0; i < entries.length; i++) {
                  final e = entries[i];
                  final color = _palette[i % _palette.length];
                  sections.add(
                    PieChartSectionData(
                      value: e.value.toDouble(),
                      color: color,
                      radius: 52,
                      title: '${((e.value / total) * 100).round()}%',
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  );
                }

                return Row(
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: PieChart(
                        PieChartData(
                          sections: sections,
                          sectionsSpace: 2,
                          centerSpaceRadius: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < entries.length && i < 5; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _palette[i % _palette.length],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      entries[i].key,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${entries[i].value}m',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
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
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicMasteryCard extends ConsumerWidget {
  const _TopicMasteryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(topicMasteryProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Topic mastery',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            AsyncValueWidget(
              value: topicsAsync,
              onRetry: () => ref.invalidate(topicMasteryProvider),
              builder: (topics) {
                if (topics.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: Text('No topic data yet'),
                  );
                }
                return Column(
                  children: [
                    for (final t in topics) _MasteryRow(item: t),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MasteryRow extends StatelessWidget {
  const _MasteryRow({required this.item});
  final TopicMastery item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(item.topic)),
          Expanded(
            flex: 3,
            child: LinearProgressIndicator(
              value: item.mastery.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text('${(item.mastery * 100).toStringAsFixed(0)}%'),
        ],
      ),
    );
  }
}

class _WeakAreasCard extends ConsumerWidget {
  const _WeakAreasCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weakAsync = ref.watch(weakAreasProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Weak areas',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            AsyncValueWidget(
              value: weakAsync,
              onRetry: () => ref.invalidate(weakAreasProvider),
              builder: (areas) {
                if (areas.isEmpty) {
                  return const Text('No weak areas yet — keep it up!');
                }
                return Column(
                  children: [
                    for (final a in areas)
                      ListTile(
                        leading: const Icon(Icons.flag_outlined),
                        title: Text(a.topic),
                        subtitle: a.recommendation != null
                            ? Text(a.recommendation!)
                            : null,
                        trailing: a.score != null
                            ? Text('${(a.score! * 100).toStringAsFixed(0)}%')
                            : null,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
