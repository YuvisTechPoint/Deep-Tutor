import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/subpage_scaffold.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/providers/composer_providers.dart';
import '../providers/space_providers.dart';

/// "Space" hub: chat sessions, notebooks, question bank, skills, memory.
class SpaceScreen extends ConsumerWidget {
  const SpaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 5,
      child: SubpageScaffold(
        title: 'Space',
        body: Column(
          children: [
            const Material(
              child: TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Sessions'),
                  Tab(text: 'Notebooks'),
                  Tab(text: 'Questions'),
                  Tab(text: 'Skills'),
                  Tab(text: 'Memory'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _SessionsTab(),
                  _NotebooksTab(),
                  _QuestionsTab(),
                  _SkillsTab(),
                  _MemoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(chatSessionsProvider);
    return AsyncValueWidget(
      value: sessionsAsync,
      onRetry: () => ref.invalidate(chatSessionsProvider),
      builder: (sessions) {
        if (sessions.isEmpty) {
          return const _EmptyState(
            icon: Icons.chat_bubble_outline,
            label: 'No sessions yet',
          );
        }
        return ListView.separated(
          itemCount: sessions.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final s = sessions[i];
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: s.lastMessage != null
                  ? Text(
                      s.lastMessage!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              onTap: () => context.push('/chat/${s.id}'),
            );
          },
        );
      },
    );
  }
}

class _NotebooksTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notebooksAsync = ref.watch(notebooksListProvider);
    return Stack(
      children: [
        AsyncValueWidget(
          value: notebooksAsync,
          onRetry: () => ref.invalidate(notebooksListProvider),
          builder: (items) {
            if (items.isEmpty) {
              return const _EmptyState(
                icon: Icons.menu_book_outlined,
                label: 'No notebooks — tap + to create',
              );
            }
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final n = items[i];
                return Dismissible(
                  key: ValueKey('nb-${n.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: Icon(Icons.delete,
                        color: Theme.of(context).colorScheme.onError),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete notebook?'),
                            content: Text('Remove "${n.title}"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        ) ??
                        false;
                  },
                  onDismissed: (_) async {
                    try {
                      await ref
                          .read(notebookRepositoryProvider)
                          .delete(n.id);
                      ref.invalidate(notebooksListProvider);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Delete failed: $e')),
                        );
                        ref.invalidate(notebooksListProvider);
                      }
                    }
                  },
                  child: ListTile(
                    leading:
                        const Icon(Icons.collections_bookmark_outlined),
                    title: Text(n.title),
                    subtitle: n.description != null
                        ? Text(n.description!,
                            maxLines: 1, overflow: TextOverflow.ellipsis)
                        : (n.recordCount != null
                            ? Text('${n.recordCount} records')
                            : null),
                  ),
                );
              },
            );
          },
        ),
        Positioned(
          right: AppSpacing.md,
          bottom: AppSpacing.md,
          child: FloatingActionButton(
            onPressed: () => _createNotebook(context, ref),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Future<void> _createNotebook(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New notebook'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
              autofocus: true,
            ),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (ok != true || titleCtrl.text.trim().isEmpty) return;
    try {
      await ref.read(notebookRepositoryProvider).create(
            title: titleCtrl.text.trim(),
            description: descCtrl.text.trim().isEmpty
                ? null
                : descCtrl.text.trim(),
          );
      ref.invalidate(notebooksListProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Create failed: $e')),
        );
      }
    }
  }
}

class _QuestionsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(questionEntriesProvider);
    return AsyncValueWidget(
      value: entriesAsync,
      onRetry: () => ref.invalidate(questionEntriesProvider),
      builder: (entries) {
        if (entries.isEmpty) {
          return const _EmptyState(
            icon: Icons.help_outline,
            label: 'No saved questions',
          );
        }
        return ListView.separated(
          itemCount: entries.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final e = entries[i];
            final entryId = int.tryParse(e.id);
            return Dismissible(
              key: ValueKey('q-${e.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Theme.of(context).colorScheme.error,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Icon(Icons.delete,
                    color: Theme.of(context).colorScheme.onError),
              ),
              confirmDismiss: (_) async {
                if (entryId == null) return false;
                return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete question?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    ) ??
                    false;
              },
              onDismissed: (_) async {
                if (entryId == null) return;
                try {
                  await ref
                      .read(questionNotebookRepositoryProvider)
                      .deleteEntry(entryId);
                  ref.invalidate(questionEntriesProvider);
                } catch (err) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Delete failed: $err')),
                    );
                    ref.invalidate(questionEntriesProvider);
                  }
                }
              },
              child: ListTile(
                leading: const Icon(Icons.quiz_outlined),
                title: Text(e.question,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: e.topic != null ? Text(e.topic!) : null,
                trailing: entryId != null
                    ? IconButton(
                        icon: const Icon(Icons.bookmark_border),
                        onPressed: () async {
                          try {
                            await ref
                                .read(questionNotebookRepositoryProvider)
                                .setBookmarked(entryId, true);
                            ref.invalidate(questionEntriesProvider);
                          } catch (err) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$err')),
                              );
                            }
                          }
                        },
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}

class _SkillsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skillsAsync = ref.watch(skillsListProvider);
    return AsyncValueWidget(
      value: skillsAsync,
      onRetry: () => ref.invalidate(skillsListProvider),
      builder: (skills) {
        if (skills.isEmpty) {
          return const _EmptyState(
            icon: Icons.workspace_premium_outlined,
            label: 'No skills',
          );
        }
        return ListView.separated(
          itemCount: skills.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final s = skills[i];
            return ListTile(
              leading: const Icon(Icons.stars_outlined),
              title: Text(s.name),
              subtitle: s.description != null
                  ? Text(s.description!,
                      maxLines: 2, overflow: TextOverflow.ellipsis)
                  : null,
            );
          },
        );
      },
    );
  }
}

class _MemoryTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memAsync = ref.watch(memorySnapshotProvider);
    return AsyncValueWidget(
      value: memAsync,
      onRetry: () => ref.invalidate(memorySnapshotProvider),
      builder: (mem) {
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Summary',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SelectableText(
                      mem.displayText.isEmpty
                          ? '(empty)'
                          : mem.displayText,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.sync),
                  label: const Text('Refresh'),
                  onPressed: () async {
                    try {
                      await ref
                          .read(memoryRepositoryProvider)
                          .refresh();
                      ref.invalidate(memorySnapshotProvider);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e')),
                        );
                      }
                    }
                  },
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Enhance'),
                  onPressed: () async {
                    try {
                      await ref
                          .read(memoryRepositoryProvider)
                          .enhance();
                      ref.invalidate(memorySnapshotProvider);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e')),
                        );
                      }
                    }
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear'),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear memory?'),
                        content: const Text(
                            'This deletes all stored long-term memory.'),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  Theme.of(ctx).colorScheme.error,
                            ),
                            onPressed: () =>
                                Navigator.of(ctx).pop(true),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref.read(memoryRepositoryProvider).clear();
                      ref.invalidate(memorySnapshotProvider);
                    }
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: AppSpacing.sm),
          Text(label),
        ],
      ),
    );
  }
}
