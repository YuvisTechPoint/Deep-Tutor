import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/feature_identity.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/utils/dt_date_utils.dart';
import '../../../core/widgets/design_system/design_system.dart';
import '../providers/co_writer_provider.dart';

class CoWriterListScreen extends ConsumerWidget {
  const CoWriterListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(coWriterDocumentsProvider);
    final accent = FeatureIdentity.of(FeatureId.coWriter).accent;

    return DtPageShell(
      title: 'Co-Writer',
      featureId: FeatureId.coWriter,
      actions: [
        IconButton.filled(
          tooltip: 'New document',
          onPressed: () => _create(context, ref),
          style: IconButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.add),
        ),
      ],
      body: RefreshIndicator(
        color: accent,
        onRefresh: () => ref.read(coWriterDocumentsProvider.notifier).refresh(),
        child: AsyncValueWidget(
          value: docsAsync,
          onRetry: () => ref.invalidate(coWriterDocumentsProvider),
          builder: (docs) {
            if (docs.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  PremiumModuleCard(
                    featureId: FeatureId.coWriter,
                    height: 120,
                    icon: Icons.edit_note_rounded,
                    label: 'Create a document',
                    subtitle: 'AI-assisted writing',
                    color: accent,
                    onTap: () => _create(context, ref),
                  ),
                ],
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                const AiSectionHeader(
                  title: 'Documents',
                  subtitle: 'Swipe left or tap delete',
                ),
                for (var i = 0; i < docs.length; i++)
                  DtDeletableListModule(
                    dismissKey: 'cowriter-${docs[i].id}',
                    index: i,
                    glowColor: accent,
                    leading: ModuleIconOrb(
                      icon: Icons.description_outlined,
                      color: accent,
                    ),
                    title: docs[i].title,
                    subtitle: docs[i].updatedAt != null
                        ? DtDateUtils.chatTimestamp(docs[i].updatedAt!)
                        : null,
                    deleteTooltip: 'Delete document',
                    onTap: () => context.push('/co-writer/${docs[i].id}'),
                    onDelete: () => ref
                        .read(coWriterDocumentsProvider.notifier)
                        .deleteDocument(docs[i].id),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New document'),
        content: TextField(
          controller: titleCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
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
      final doc = await ref.read(coWriterRepositoryProvider).create(
            title: titleCtrl.text.trim(),
          );
      await ref.read(coWriterDocumentsProvider.notifier).refresh();
      if (context.mounted) {
        context.push('/co-writer/${doc.id}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
    }
  }
}
