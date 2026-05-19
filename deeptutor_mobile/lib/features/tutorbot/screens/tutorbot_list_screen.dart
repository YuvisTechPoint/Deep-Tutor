import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/feature_identity.dart';
import '../../../core/widgets/design_system/dt_copper_button.dart';
import '../../../core/widgets/design_system/dt_list_module.dart';
import '../../../core/widgets/design_system/dt_page_shell.dart';
import '../../../core/widgets/design_system/glass_surface.dart';
import '../../../core/widgets/design_system/premium_module_card.dart';
import '../../../data/repositories/tutorbot_repository.dart';
import '../providers/tutorbot_provider.dart';

/// User-owned TutorBots — live from ``GET /api/v1/tutorbot`` (per-user storage).
class TutorBotListScreen extends ConsumerStatefulWidget {
  const TutorBotListScreen({super.key});

  @override
  ConsumerState<TutorBotListScreen> createState() => _TutorBotListScreenState();
}

class _TutorBotListScreenState extends ConsumerState<TutorBotListScreen> {
  String? _deletingId;

  Future<void> _refresh() async {
    await ref.read(tutorBotsListProvider.notifier).load(sync: true);
  }

  Future<void> _createBot() async {
    final nameCtrl = TextEditingController();
    final topicCtrl = TextEditingController();
    final focusCtrl = TextEditingController();

    TutorBotSummary? createdBot;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: GlassSurface(
            margin: const EdgeInsets.all(AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.lg),
            glowColor: AppColors.copperPrimary,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Create your TutorBot',
                  style: AppTextStyles.moduleTitle(ctx),
                ),
                const SizedBox(height: 4),
                Text(
                  'Name any subject or goal — your private AI tutor.',
                  style: AppTextStyles.caption(ctx),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    hintText: 'e.g. Organic Chemistry',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: topicCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'What should it teach? (optional)',
                    hintText: 'Exam prep, projects, interview drills…',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: focusCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Teaching style (optional)',
                    hintText: 'Socratic, concise, visual…',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: DtCopperButton(
                        label: 'Create',
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Enter a name')),
                            );
                            return;
                          }
                          try {
                            createdBot = await ref
                                .read(tutorBotsListProvider.notifier)
                                .create(
                                  name: name,
                                  description: topicCtrl.text.trim().isEmpty
                                      ? null
                                      : topicCtrl.text.trim(),
                                  focus: focusCtrl.text.trim().isEmpty
                                      ? null
                                      : focusCtrl.text.trim(),
                                );
                            if (ctx.mounted) Navigator.of(ctx).pop(true);
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Could not create: $e')),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (created == true && createdBot != null && mounted) {
      context.push('/tutorbot/${createdBot!.id}');
    }
  }

  Future<void> _confirmDelete(TutorBotSummary bot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${bot.name}"?'),
        content: const Text(
          'This removes the tutor and its chat history permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deletingId = bot.id);
    try {
      await ref.read(tutorBotsListProvider.notifier).destroy(bot.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${bot.name}" deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(tutorBotsListProvider);
    final accent = FeatureIdentity.of(FeatureId.tutorBot).accent;

    return DtPageShell(
      title: 'TutorBots',
      featureId: FeatureId.tutorBot,
      actions: [
        if (listState.isSyncing)
          const Padding(
            padding: EdgeInsets.only(right: AppSpacing.sm),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Sync',
          onPressed: _refresh,
        ),
      ],
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.copperPrimary,
        foregroundColor: Colors.white,
        onPressed: _createBot,
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        color: AppColors.copperPrimary,
        onRefresh: _refresh,
        child: _buildBody(context, listState, accent),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    TutorBotsListState listState,
    Color accent,
  ) {
    if (listState.isLoading && listState.bots.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (listState.hasError && listState.bots.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const SizedBox(height: 64),
          Icon(Icons.cloud_off_rounded,
              size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Could not load your TutorBots',
            style: AppTextStyles.moduleTitle(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${listState.error}',
            style: AppTextStyles.caption(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: FilledButton(
              onPressed: _refresh,
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    if (listState.bots.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const SizedBox(height: 48),
          GlassSurface(
            glowColor: AppColors.copperPrimary,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Icon(Icons.smart_toy_outlined,
                    size: 56, color: accent.withValues(alpha: 0.9)),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Build your own AI tutor',
                  style: AppTextStyles.moduleTitle(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Create a TutorBot for any topic you are learning. '
                  'Only you see your tutors — nothing is pre-loaded.',
                  style: AppTextStyles.caption(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                DtCopperButton(
                  label: 'Create TutorBot',
                  onPressed: _createBot,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.dockClearance + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: listState.bots.length,
      itemBuilder: (_, i) {
        final bot = listState.bots[i];
        final deleting = _deletingId == bot.id;

        return Dismissible(
          key: ValueKey(bot.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            HapticFeedback.mediumImpact();
            await _confirmDelete(bot);
            return false;
          },
          background: Container(
            alignment: Alignment.centerRight,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
            ),
            child: deleting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.delete_outline_rounded, color: Colors.white),
          ),
          child: DtListModule(
            index: i,
            glowColor: accent,
            leading: ModuleIconOrb(
              icon: Icons.smart_toy_outlined,
              color: accent,
            ),
            title: bot.name,
            subtitle: bot.description ?? bot.persona,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (bot.running)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: AppSpacing.sm),
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  tooltip: 'Delete',
                  onPressed: deleting ? null : () => _confirmDelete(bot),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            onTap: () => context.push('/tutorbot/${bot.id}'),
          ),
        );
      },
    );
  }
}
