import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/feature_identity.dart';
import '../../../core/widgets/design_system/dt_page_shell.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/dt_skeleton.dart';
import '../../../data/models/practice.dart';
import '../providers/practice_provider.dart';
import '../widgets/practice_question_transition.dart';
import '../widgets/practice_result_sheet.dart';
import '../widgets/topic_selector.dart';

/// Practice (MCQ) screen.
///
/// Flow: topic select → question fetch → quiz → submit → result sheet.
class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(practiceNotifierProvider);

    return DtPageShell(
      title: 'Practice',
      featureId: FeatureId.practice,
      actions: [
        if (state is PracticeQuizActive)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Center(
              child: Text(
                '${state.currentIndex + 1} / ${state.questions.length}',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
      body: switch (state) {
        PracticeIdle() => TopicSelector(
            onStart: (topic, difficulty) => ref
                .read(practiceNotifierProvider.notifier)
                .startQuiz(topic: topic, difficulty: difficulty),
          ),
        PracticeLoading() => const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: DtSkeletonTextBlock(lines: 8),
          ),
        PracticeQuizActive() => _QuizView(state: state),
        PracticeSubmitting() => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: AppSpacing.md),
                Text('Submitting quiz...'),
              ],
            ),
          ),
        PracticeResult() => PracticeResultSheet(
            result: state.result,
            onRetry: () =>
                ref.read(practiceNotifierProvider.notifier).reset(),
          ),
        PracticeError() => FriendlyErrorView(
            message: state.message,
            onRetry: () =>
                ref.read(practiceNotifierProvider.notifier).reset(),
          ),
      },
    );
  }
}

// ── Quiz view ─────────────────────────────────────────────────────────────────

class _QuizView extends ConsumerStatefulWidget {
  const _QuizView({required this.state});
  final PracticeQuizActive state;

  @override
  ConsumerState<_QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends ConsumerState<_QuizView> {
  int _lastIndex = 0;
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    _lastIndex = widget.state.currentIndex;
  }

  @override
  void didUpdateWidget(_QuizView old) {
    super.didUpdateWidget(old);
    if (widget.state.currentIndex != _lastIndex) {
      _forward = widget.state.currentIndex > _lastIndex;
      _lastIndex = widget.state.currentIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final notifier = ref.read(practiceNotifierProvider.notifier);
    final question = state.questions[state.currentIndex];
    final isLast = state.currentIndex == state.questions.length - 1;

    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(
            begin: 0,
            end: (state.currentIndex + 1) / state.questions.length,
          ),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (_, value, __) => LinearProgressIndicator(
            value: value,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: PracticeQuestionTransition(
              questionKey: question.id,
              forward: _forward,
              question: question,
              selectedIndex: state.answers[question.id],
              hint: state.hints[question.id],
              onOptionSelected: (idx) =>
                  notifier.selectAnswer(question.id, idx),
              onHintRequested: () => notifier.fetchHint(question.id),
            ),
          ),
        ),

        // Bottom actions
        _QuizActions(
          hasPrevious: state.currentIndex > 0,
          isLast: isLast,
          canProceed: state.answers.containsKey(question.id),
          onPrevious: notifier.previousQuestion,
          onNext: isLast
              ? notifier.submit
              : notifier.nextQuestion,
        ),
      ],
    );
  }
}

class _QuizActions extends StatelessWidget {
  const _QuizActions({
    required this.hasPrevious,
    required this.isLast,
    required this.canProceed,
    required this.onPrevious,
    required this.onNext,
  });

  final bool hasPrevious;
  final bool isLast;
  final bool canProceed;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
        top: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (hasPrevious)
              OutlinedButton(
                onPressed: onPrevious,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(100, AppSpacing.minTouchTarget),
                ),
                child: const Text('Previous'),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: canProceed ? onNext : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(120, AppSpacing.minTouchTarget),
              ),
              child: Text(isLast ? 'Submit' : 'Next'),
            ),
          ],
        ),
      ),
    );
  }
}
