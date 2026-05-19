import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/animated_entrance.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/spring_check_tile.dart';
import '../../../core/widgets/subpage_scaffold.dart';
import '../providers/roadmap_provider.dart';

/// Learning roadmap: milestones + cross-links to career paths.
class RoadmapScreen extends ConsumerWidget {
  const RoadmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(learningPlanProvider);

    return SubpageScaffold(
      title: 'Roadmap',
      actions: [
        IconButton(
          icon: const Icon(Icons.work_outline),
          tooltip: 'Career paths',
          onPressed: () => context.push('/career'),
        ),
      ],
      body: AsyncValueWidget(
        value: planAsync,
        onRetry: () => ref.invalidate(learningPlanProvider),
        builder: (plan) {
          if (plan.milestones.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const SizedBox(height: 96),
                Icon(Icons.map_outlined,
                    size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 12),
                const Center(child: Text('No milestones in your plan yet')),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => context.push('/career'),
                    child: const Text('Pick a career path'),
                  ),
                ),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(learningPlanProvider);
              await ref.read(learningPlanProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              children: [
                if (plan.target != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      'Target: ${plan.target}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                for (var i = 0; i < plan.milestones.length; i++)
                  AnimatedEntrance(
                    delay: AppAnimations.staggerStep * i,
                    child: SpringCheckTile(
                      title: plan.milestones[i].title,
                      leadingLabel: '${i + 1}',
                      completed: plan.milestones[i].isCompleted,
                      subtitle: plan.milestones[i].description ??
                          (plan.milestones[i].dueAt != null
                              ? 'Due: ${plan.milestones[i].dueAt!.substring(0, plan.milestones[i].dueAt!.length.clamp(0, 10))}'
                              : null),
                      onToggle: (done) async {
                        await ref
                            .read(learningPlanRepositoryProvider)
                            .patchMilestone(plan.milestones[i].id, {
                          'status': done ? 'completed' : 'pending',
                        });
                        ref.invalidate(learningPlanProvider);
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

