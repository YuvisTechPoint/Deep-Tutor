import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_animations.dart';
import '../../../data/models/learning_profile.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../auth/providers/auth_provider.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final profileRepositoryProvider = Provider(
  (ref) => ProfileRepository(dio: ref.watch(dioProvider)),
);

// ── State ─────────────────────────────────────────────────────────────────────

class OnboardingState {
  const OnboardingState({
    required this.currentStep,
    required this.draft,
    this.isSaving = false,
    this.error,
  });

  static const int totalSteps = 8;

  final int currentStep;
  final LearningProfile draft;
  final bool isSaving;
  final String? error;

  OnboardingState copyWith({
    int? currentStep,
    LearningProfile? draft,
    bool? isSaving,
    String? error,
  }) =>
      OnboardingState(
        currentStep: currentStep ?? this.currentStep,
        draft: draft ?? this.draft,
        isSaving: isSaving ?? this.isSaving,
        error: error ?? this.error,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier(this._repo)
      : super(
          const OnboardingState(
            currentStep: 0,
            draft: LearningProfile(),
          ),
        );

  final ProfileRepository _repo;
  final pageController = PageController();

  bool get canProceed {
    final step = state.currentStep;
    final draft = state.draft;
    return switch (step) {
      0 => true,
      1 => draft.preparingFor.isNotEmpty,
      2 => draft.careerPathId.isNotEmpty,
      3 => draft.domainAnswers.isNotEmpty,
      4 => draft.weeklyHours != null,
      5 => draft.learningStyles.isNotEmpty,
      6 => draft.experienceLevel.isNotEmpty,
      7 => true,
      _ => true,
    };
  }

  void updateDraft(LearningProfile draft) {
    state = state.copyWith(draft: draft);
  }

  Future<void> nextStep() async {
    if (!canProceed) return;

    // Sync to server on each step
    await _syncDraft();

    final next = state.currentStep + 1;
    if (next >= OnboardingState.totalSteps) return;

    state = state.copyWith(currentStep: next);
    pageController.animateToPage(
      next,
      duration: AppAnimations.standard,
      curve: AppAnimations.standardCurve,
    );
  }

  void previousStep() {
    final prev = state.currentStep - 1;
    if (prev < 0) return;
    state = state.copyWith(currentStep: prev);
    pageController.animateToPage(
      prev,
      duration: AppAnimations.standard,
      curve: AppAnimations.standardCurve,
    );
  }

  Future<void> finish() async {
    await _syncDraft();
  }

  Future<void> _syncDraft() async {
    state = state.copyWith(isSaving: true);
    try {
      await _repo.updateProfile(state.draft);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}

final onboardingNotifierProvider =
    StateNotifierProvider.autoDispose<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(ref.watch(profileRepositoryProvider)),
);
