import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/subpage_scaffold.dart';
import '../data/mentor_repository.dart';
import '../providers/mentor_provider.dart';

class MentorPortalScreen extends ConsumerWidget {
  const MentorPortalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: SubpageScaffold(
        title: 'Mentor portal',
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Dashboard'),
            Tab(text: 'Students'),
            Tab(text: 'Interventions'),
            Tab(text: 'Messages'),
          ],
        ),
        body: const TabBarView(
          children: [
            _DashboardTab(),
            _StudentsTab(),
            _InterventionsTab(),
            _MessagesTab(),
          ],
        ),
      ),
    );
  }
}

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mentorDashboardProvider);
    final analytics = ref.watch(mentorCohortAnalyticsProvider);
    return AsyncValueWidget(
      value: async,
      onRetry: () => ref.invalidate(mentorDashboardProvider),
      builder: (data) => ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _StatGrid(stats: [
            ('Students', data.totalStudents.toString()),
            ('Active today', data.activeToday.toString()),
            ('At risk', data.atRiskCount.toString()),
            ('Unread msgs', data.unreadMessages.toString()),
          ]),
          const SizedBox(height: AppSpacing.lg),
          Text('Cohort analytics',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          analytics.when(
            data: (a) => Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in a.entries)
                      Text('${e.key}: ${e.value}'),
                  ],
                ),
              ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});
  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.6,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final s in stats)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(s.$1, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(s.$2,
                      style:
                          Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StudentsTab extends ConsumerWidget {
  const _StudentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mentorStudentsProvider);
    return AsyncValueWidget(
      value: async,
      onRetry: () => ref.invalidate(mentorStudentsProvider),
      builder: (students) {
        if (students.isEmpty) {
          return const Center(child: Text('No students yet'));
        }
        return ListView.separated(
          itemCount: students.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final s = students[i];
            final risk = s.riskScore ?? 0;
            final atRisk = risk >= 0.5;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: atRisk ? Colors.red.shade100 : null,
                child: Text(
                  s.name.isNotEmpty ? s.name[0] : '?',
                  style: TextStyle(
                    color: atRisk ? Colors.red.shade700 : null,
                  ),
                ),
              ),
              title: Text(s.name),
              subtitle: Text(
                '${s.cohort ?? 'No cohort'} • '
                '${s.lastActivity ?? 'No activity'}',
              ),
              trailing: atRisk
                  ? const Icon(Icons.warning_amber, color: Colors.red)
                  : null,
            );
          },
        );
      },
    );
  }
}

class _InterventionsTab extends ConsumerWidget {
  const _InterventionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mentorInterventionsProvider);
    return AsyncValueWidget(
      value: async,
      onRetry: () => ref.invalidate(mentorInterventionsProvider),
      builder: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No interventions'));
        }
        return ListView(
          children: [
            for (final i in items)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(i.title),
                subtitle: Text('Status: ${i.status}'),
              ),
          ],
        );
      },
    );
  }
}

class _MessagesTab extends ConsumerWidget {
  const _MessagesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mentorMessagesProvider);
    return AsyncValueWidget(
      value: async,
      onRetry: () => ref.invalidate(mentorMessagesProvider),
      builder: (msgs) {
        if (msgs.isEmpty) {
          return const Center(child: Text('No messages'));
        }
        return ListView.separated(
          itemCount: msgs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final m = msgs[i];
            return ListTile(
              leading: m.isUnread
                  ? const Icon(Icons.mark_email_unread,
                      color: Colors.orange)
                  : const Icon(Icons.email_outlined),
              title: Text(m.from),
              subtitle: Text(m.body),
              trailing: Text(m.createdAt,
                  style: Theme.of(context).textTheme.bodySmall),
            );
          },
        );
      },
    );
  }
}
