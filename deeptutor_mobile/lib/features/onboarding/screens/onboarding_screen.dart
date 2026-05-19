import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/design_system/ambient_mesh_background.dart';
import '../providers/onboarding_gate_provider.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_step_view.dart';

/// 8-step onboarding flow.
///
/// Mirrors `web/app/(workspace)/onboarding/page.tsx`.
/// Each "Continue" syncs draft to `PUT /api/v1/learning-profile`.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingNotifierProvider);
    final notifier = ref.read(onboardingNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      body: AmbientMeshBackground(
        child: SafeArea(
          child: Column(
          children: [
            // Step progress
            _StepProgress(
              currentStep: state.currentStep,
              totalSteps: OnboardingState.totalSteps,
            ),

            Expanded(
              child: PageView.builder(
                physics: const NeverScrollableScrollPhysics(),
                controller: notifier.pageController,
                itemCount: OnboardingState.totalSteps,
                itemBuilder: (_, step) => OnboardingStepView(
                  step: step,
                  state: state,
                  notifier: notifier,
                ),
              ),
            ),

            // Navigation footer
            _OnboardingFooter(
              currentStep: state.currentStep,
              canProceed: notifier.canProceed,
              isSaving: state.isSaving,
              onBack: notifier.previousStep,
              onContinue: state.currentStep == OnboardingState.totalSteps - 1
                  ? () async {
                      await notifier.finish();
                      await refreshOnboardingGate(ref);
                      if (context.mounted) context.go('/home');
                    }
                  : notifier.nextStep,
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: List.generate(totalSteps, (i) {
              final isActive = i == currentStep;
              final isDone = i < currentStep;
              final filled = isDone || isActive;
              return Expanded(
                child: AnimatedContainer(
                  duration: AppAnimations.standard,
                  curve: AppAnimations.standardCurve,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: isActive ? 6 : 4,
                  decoration: BoxDecoration(
                    color: filled
                        ? AppColors.primary
                        : Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Step ${currentStep + 1} of $totalSteps',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5),
                ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingFooter extends StatelessWidget {
  const _OnboardingFooter({
    required this.currentStep,
    required this.canProceed,
    required this.isSaving,
    required this.onBack,
    required this.onContinue,
  });

  final int currentStep;
  final bool canProceed;
  final bool isSaving;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: AppSpacing.md,
        top: AppSpacing.sm,
      ),
      child: Row(
        children: [
          if (currentStep > 0)
            OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(100, AppSpacing.minTouchTarget),
              ),
              child: const Text('Back'),
            ),
          const Spacer(),
          ElevatedButton(
            onPressed: (canProceed && !isSaving) ? onContinue : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(140, AppSpacing.minTouchTarget),
            ),
            child: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    currentStep == OnboardingState.totalSteps - 1
                        ? 'Finish'
                        : 'Continue',
                  ),
          ),
        ],
      ),
    );
  }
}
