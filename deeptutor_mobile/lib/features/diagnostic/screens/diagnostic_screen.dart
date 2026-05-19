import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/feature_identity.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/design_system/dt_page_shell.dart';
import '../../../navigation/router.dart';
import '../../onboarding/providers/onboarding_gate_provider.dart';
import '../providers/diagnostic_provider.dart';

/// Diagnostic quiz screen.
///
/// Flow: ready → start → questions (MCQ) → submit → result with
/// profile update feedback.  Backend infers topic from learning profile
/// if none is supplied (`deeptutor/api/routers/diagnostic.py`).
class DiagnosticScreen extends ConsumerWidget {
  const DiagnosticScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(diagnosticNotifierProvider);
    final notifier = ref.read(diagnosticNotifierProvider.notifier);

    return DtPageShell(
      title: 'Diagnostic',
      featureId: FeatureId.diagnostic,
      actions: [
        if (state is DiagnosticActive)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: Text(
                '${state.currentIndex + 1}/${state.questions.length}',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
      body: switch (state) {
        DiagnosticReady() => _ReadyView(
            onStart: () => notifier.start(),
          ),
        DiagnosticLoading() =>
          const Center(child: CircularProgressIndicator()),
        DiagnosticActive() => _QuizView(
            state: state,
            onSelect: (qId, idx) => notifier.selectAnswer(qId, idx),
            onNext: state.isLast ? notifier.finish : notifier.next,
          ),
        DiagnosticSubmitting() => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: AppSpacing.md),
                Text('Analysing your results…'),
              ],
            ),
          ),
        DiagnosticResult(:final result) => _ResultView(
            result: result,
            onDone: () async {
              await refreshOnboardingGate(ref);
              if (context.mounted) {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.home);
                }
              }
            },
            onRetake: notifier.reset,
          ),
        DiagnosticError(:final message) => FriendlyErrorView(
            message: message,
            onRetry: notifier.reset,
          ),
      },
    );
  }
}

// ── Views ─────────────────────────────────────────────────────────────────────

class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
            ),
            child: const Icon(Icons.psychology_outlined,
                size: 56, color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Diagnostic Quiz',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'This quiz helps us personalise your learning path. '
            'It takes about 5 minutes and adapts to your answers.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _InfoRow(
              icon: Icons.timer_outlined, text: '~5 minutes'),
          _InfoRow(
              icon: Icons.psychology,
              text: 'Adapts to your level'),
          _InfoRow(
              icon: Icons.auto_graph,
              text: 'Updates your learning profile'),
          const SizedBox(height: AppSpacing.xxxl),
          FilledButton(
            onPressed: onStart,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
            child: const Text('Start Diagnostic'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _QuizView extends StatelessWidget {
  const _QuizView({
    required this.state,
    required this.onSelect,
    required this.onNext,
  });

  final DiagnosticActive state;
  final void Function(String qId, int idx) onSelect;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final q = state.current;
    final qId = q['id'] as String? ?? '';
    final questionText = q['question'] as String? ?? '';
    final options = (q['options'] as List? ?? []).cast<String>();
    final selected = state.answers[qId];

    return Column(
      children: [
        LinearProgressIndicator(
          value: (state.currentIndex + 1) / state.questions.length,
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          valueColor:
              const AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.md),
                Text(
                  questionText,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(height: 1.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.lg),
                ...options.asMap().entries.map(
                      (e) => _OptionCard(
                        label: _label(e.key),
                        text: e.value,
                        selected: selected == e.key,
                        onTap: () => onSelect(qId, e.key),
                      ),
                    ),
              ],
            ),
          ),
        ),
        _Footer(
          canProceed: selected != null,
          isLast: state.isLast,
          onNext: onNext,
        ),
      ],
    );
  }

  static String _label(int i) =>
      ['A', 'B', 'C', 'D', 'E'][i.clamp(0, 4)];
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.label,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusL),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withOpacity(0.08)
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusL),
            border: Border.all(
              color: selected ? AppColors.primary : cs.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : cs.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: selected ? AppColors.primary : cs.outline),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : cs.onSurface,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.canProceed,
    required this.isLast,
    required this.onNext,
  });

  final bool canProceed;
  final bool isLast;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom:
            MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
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
        child: ElevatedButton(
          onPressed: canProceed ? onNext : null,
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52)),
          child: Text(isLast ? 'Submit' : 'Next'),
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.result,
    required this.onDone,
    required this.onRetake,
  });

  final Map<String, dynamic> result;
  final VoidCallback onDone;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final score = result['score'] ?? 0;
    final total = result['total'] ?? 1;
    final feedback = result['feedback'] as String?;
    final pct = (score / total * 100).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Text(
            '$pct%',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
          ),
          Text(
            '$score / $total correct',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (feedback != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusL),
              ),
              child: Text(
                feedback,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          Text(
            'Your learning profile has been updated.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          FilledButton(
            onPressed: onDone,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: const Text('Continue'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: onRetake,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: const Text('Retake'),
          ),
        ],
      ),
    );
  }
}
