import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/subpage_scaffold.dart';
import '../providers/recruiter_provider.dart';

class RecruiterPortalScreen extends ConsumerWidget {
  const RecruiterPortalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: SubpageScaffold(
        title: 'Recruiter portal',
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Search'),
            Tab(text: 'Shortlists'),
          ],
        ),
        body: const TabBarView(
          children: [
            _SearchTab(),
            _ShortlistsTab(),
          ],
        ),
      ),
    );
  }
}

class _SearchTab extends ConsumerStatefulWidget {
  const _SearchTab();

  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final candidatesAsync = ref.watch(recruiterSearchProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              hintText: 'Search candidates…',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () => ref
                    .read(recruiterSearchQueryProvider.notifier)
                    .state = RecruiterSearchQuery(query: _ctrl.text.trim()),
              ),
            ),
            onSubmitted: (v) => ref
                .read(recruiterSearchQueryProvider.notifier)
                .state = RecruiterSearchQuery(query: v.trim()),
          ),
        ),
        Expanded(
          child: AsyncValueWidget(
            value: candidatesAsync,
            onRetry: () => ref.invalidate(recruiterSearchProvider),
            builder: (candidates) {
              if (candidates.isEmpty) {
                return const Center(child: Text('No candidates'));
              }
              return ListView.separated(
                itemCount: candidates.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final c = candidates[i];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(c.name[0]),
                    ),
                    title: Text(c.name),
                    subtitle: Text(
                      [c.headline, c.skills.join(' • ')]
                          .where((s) => s != null && s.isNotEmpty)
                          .join(' — '),
                    ),
                    trailing: c.matchScore != null
                        ? Chip(
                            label: Text(
                              '${(c.matchScore! * 100).toStringAsFixed(0)}%',
                            ),
                          )
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ShortlistsTab extends ConsumerWidget {
  const _ShortlistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recruiterShortlistsProvider);
    return AsyncValueWidget(
      value: async,
      onRetry: () => ref.invalidate(recruiterShortlistsProvider),
      builder: (lists) {
        if (lists.isEmpty) {
          return const Center(child: Text('No shortlists yet'));
        }
        return ListView(
          children: [
            for (final s in lists)
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: Text(s.title),
                trailing: Text('${s.candidateCount}'),
              ),
          ],
        );
      },
    );
  }
}
