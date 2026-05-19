import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/feature_identity.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/design_system/design_system.dart';
import '../../../data/models/knowledge_base.dart';
import '../../chat/providers/composer_providers.dart';
import '../providers/knowledge_provider.dart';

/// Top-level Knowledge tab — lists KBs with create CTA and swipe-to-delete.
class KnowledgeScreen extends ConsumerWidget {
  const KnowledgeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kbAsync = ref.watch(knowledgeBasesProvider);
    final accent = FeatureIdentity.of(FeatureId.knowledge).accent;

    return DtPageShell(
      title: 'Knowledge bases',
      featureId: FeatureId.knowledge,
      actions: [
        IconButton.filled(
          tooltip: 'New knowledge base',
          onPressed: () => _createKb(context, ref),
          style: IconButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.add),
        ),
      ],
      body: RefreshIndicator(
        color: accent,
        onRefresh: () => ref.read(knowledgeBasesProvider.notifier).refresh(),
        child: AsyncValueWidget(
          value: kbAsync,
          onRetry: () => ref.invalidate(knowledgeBasesProvider),
          builder: (items) {
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 96),
                  Icon(
                    Icons.library_books_outlined,
                    size: 64,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Center(child: Text('No knowledge bases yet')),
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _createKb(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Create your first KB'),
                    ),
                  ),
                ],
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                const AiSectionHeader(
                  title: 'Your libraries',
                  subtitle: 'Swipe left or tap delete',
                ),
                for (var i = 0; i < items.length; i++)
                  _KbTile(kb: items[i], index: i),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _createKb(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New knowledge base'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Description (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              try {
                await ref.read(knowledgeRepositoryProvider).create(
                      name,
                      description: descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                    );
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created == true) {
      ref.invalidate(knowledgeBasesProvider);
    }
  }
}

class _KbTile extends ConsumerWidget {
  const _KbTile({required this.kb, required this.index});

  final KnowledgeBaseSummary kb;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = FeatureIdentity.of(FeatureId.knowledge).accent;
    final subtitle = [
      if (kb.fileCount != null) '${kb.fileCount} files',
      if (kb.provider != null) kb.provider,
      if (kb.status != null) kb.status,
    ].whereType<String>().join(' · ');

    return DtDeletableListModule(
      dismissKey: 'kb-${kb.name}',
      index: index,
      glowColor: accent,
      leading: ModuleIconOrb(
        icon: Icons.folder_special_outlined,
        color: accent,
      ),
      title: kb.title,
      subtitle: subtitle.isEmpty ? null : subtitle,
      deleteTooltip: 'Delete knowledge base',
      onTap: () => context.push('/knowledge/${kb.name}'),
      onDelete: () =>
          ref.read(knowledgeBasesProvider.notifier).deleteBase(kb.name),
    );
  }
}
