import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/animated_entrance.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/subpage_scaffold.dart';
import '../providers/progress_providers.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achAsync = ref.watch(achievementsListProvider);

    return SubpageScaffold(
      title: 'Achievements',
      body: AsyncValueWidget(
        value: achAsync,
        onRetry: () => ref.invalidate(achievementsListProvider),
        builder: (badges) {
          if (badges.isEmpty) {
            return const Center(child: Text('No badges yet'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
            ),
            itemCount: badges.length,
            itemBuilder: (_, i) {
              final b = badges[i];
              return AnimatedEntrance(
                delay: AppAnimations.staggerStep * i,
                child: Card(
                color: b.earned
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: InkWell(
                  onTap: () async {
                    if (b.earned) return;
                    try {
                      await ref
                          .read(achievementsRepositoryProvider)
                          .claim(b.badgeId);
                      ref.invalidate(achievementsListProvider);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Claim failed: $e')),
                        );
                      }
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          b.earned
                              ? Icons.emoji_events
                              : Icons.emoji_events_outlined,
                          size: 40,
                          color: b.earned
                              ? AppColors.xpGold
                              : Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          b.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (b.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            b.description!,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              );
            },
          );
        },
      ),
    );
  }
}
