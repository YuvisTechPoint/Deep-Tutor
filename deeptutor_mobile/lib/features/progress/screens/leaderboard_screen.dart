import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/subpage_scaffold.dart';
import '../providers/progress_providers.dart';
import '../widgets/leaderboard_tile.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lbAsync = ref.watch(leaderboardProvider);

    return SubpageScaffold(
      title: 'Leaderboard',
      body: AsyncValueWidget(
        value: lbAsync,
        onRetry: () => ref.invalidate(leaderboardProvider),
        builder: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('No leaderboard entries yet'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: entries.length,
            itemBuilder: (_, i) => LeaderboardTile(
              entry: entries[i],
              index: i,
            ),
          );
        },
      ),
    );
  }
}
