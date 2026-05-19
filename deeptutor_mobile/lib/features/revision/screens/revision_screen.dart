import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/subpage_scaffold.dart';
import '../../../data/models/revision_item.dart';
import '../../../navigation/router.dart';
import '../providers/revision_provider.dart';

/// Spaced-repetition review screen.
class RevisionScreen extends ConsumerWidget {
  const RevisionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(revisionNotifierProvider);

    return SubpageScaffold(
      title: 'Revision',
      actions: [
        if (state is RevisionIdle)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: Text(
                '${state.currentIndex + 1}/${state.queue.length}',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
      body: switch (state) {
        RevisionLoading() =>
          const Center(child: CircularProgressIndicator()),
        RevisionEmpty() => _EmptyView(
            onRefresh: () =>
                ref.read(revisionNotifierProvider.notifier).load(),
          ),
        RevisionDone(:final reviewed) => _DoneView(
            reviewed: reviewed,
            onRestart: () =>
                ref.read(revisionNotifierProvider.notifier).restart(),
          ),
        RevisionError(:final message) => FriendlyErrorView(
            message: message,
            onRetry: () =>
                ref.read(revisionNotifierProvider.notifier).load(),
          ),
        RevisionIdle(:final queue, :final currentIndex) =>
          _FlashcardView(
            item: queue[currentIndex],
            currentIndex: currentIndex,
            total: queue.length,
            onRate: (rating) => ref
                .read(revisionNotifierProvider.notifier)
                .submitRating(rating),
          ),
      },
    );
  }
}

// ── Flashcard view ────────────────────────────────────────────────────────────

class _FlashcardView extends StatefulWidget {
  const _FlashcardView({
    required this.item,
    required this.currentIndex,
    required this.total,
    required this.onRate,
  });

  final RevisionItem item;
  final int currentIndex;
  final int total;
  final void Function(int rating) onRate;

  @override
  State<_FlashcardView> createState() => _FlashcardViewState();
}

class _FlashcardViewState extends State<_FlashcardView>
    with SingleTickerProviderStateMixin {
  bool _showAnswer = false;
  late AnimationController _flipController;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didUpdateWidget(_FlashcardView old) {
    super.didUpdateWidget(old);
    if (old.item.id != widget.item.id) {
      _showAnswer = false;
      _flipController.reverse();
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flip() {
    setState(() => _showAnswer = !_showAnswer);
    if (_showAnswer) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Column(
      children: [
        LinearProgressIndicator(
          value: (widget.currentIndex + 1) / widget.total,
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              label: Text(item.topic),
              backgroundColor: AppColors.accent.withOpacity(0.1),
              labelStyle: const TextStyle(fontSize: 12),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: _showAnswer ? null : _flip,
            onHorizontalDragEnd: (d) {
              if (!_showAnswer) return;
              final v = d.primaryVelocity ?? 0;
              if (v < -300) {
                widget.onRate(1); // swipe left → Again
              } else if (v > 300) {
                widget.onRate(3); // swipe right → Good
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Card(
                elevation: 4,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: _showAnswer
                      ? _AnswerSide(answer: item.answer)
                      : _QuestionSide(question: item.question),
                ),
              ),
            ),
          ),
        ),
        if (!_showAnswer)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Tap card to reveal answer',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
            ),
          ),
        if (_showAnswer) _RatingBar(onRate: widget.onRate),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _QuestionSide extends StatelessWidget {
  const _QuestionSide({required this.question});
  final String question;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.help_outline_rounded,
            size: 40, color: AppColors.primary.withOpacity(0.5)),
        const SizedBox(height: AppSpacing.lg),
        Text(
          question,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
        ),
      ],
    );
  }
}

class _AnswerSide extends StatelessWidget {
  const _AnswerSide({required this.answer});
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lightbulb_outline_rounded,
            size: 40, color: AppColors.warning.withOpacity(0.7)),
        const SizedBox(height: AppSpacing.lg),
        Text(
          answer,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
        ),
      ],
    );
  }
}

class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.onRate});
  final void Function(int) onRate;

  static const _ratings = [
    (1, 'Again', AppColors.error),
    (2, 'Hard', AppColors.warning),
    (3, 'Good', AppColors.success),
    (4, 'Easy', AppColors.info),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          Text(
            'How well did you remember?',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: _ratings
                .map((r) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs),
                        child: OutlinedButton(
                          onPressed: () => onRate(r.$1),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: r.$3,
                            side: BorderSide(color: r.$3),
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm),
                          ),
                          child: Text(r.$2,
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Queue empty!',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Complete practice quizzes or chat sessions to build your review queue.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh queue'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.practice),
              icon: const Icon(Icons.quiz_outlined),
              label: const Text('Start practice'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: () => context.push(AppRoutes.learn),
              icon: const Icon(Icons.school_outlined),
              label: const Text('Open Learn hub'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({required this.reviewed, required this.onRestart});
  final int reviewed;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✅', style: TextStyle(fontSize: 64)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Session complete!',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'You reviewed $reviewed card${reviewed == 1 ? '' : 's'}.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.replay),
              label: const Text('Review again'),
            ),
          ],
        ),
      ),
    );
  }
}
