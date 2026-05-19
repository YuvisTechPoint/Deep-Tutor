import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/learning_profile.dart';
import '../../auth/providers/auth_provider.dart';
import 'onboarding_provider.dart' show profileRepositoryProvider;

/// Whether the learner must complete onboarding before using the app.
enum OnboardingGate {
  unknown,
  required,
  complete,
}

final onboardingGateProvider =
    StateProvider<OnboardingGate>((ref) => OnboardingGate.unknown);

bool profileNeedsOnboarding(LearningProfile profile) {
  return profile.preparingFor.isEmpty ||
      profile.careerPathId.isEmpty ||
      !profile.diagnosticCompleted;
}

/// Loads learning profile and updates [onboardingGateProvider].
Future<void> refreshOnboardingGate(WidgetRef ref) async {
  final auth = ref.read(authNotifierProvider);
  if (auth is! AuthAuthenticated) {
    ref.read(onboardingGateProvider.notifier).state = OnboardingGate.complete;
    return;
  }

  if (auth.isDemo || ref.read(demoModeProvider)) {
    ref.read(onboardingGateProvider.notifier).state = OnboardingGate.complete;
    return;
  }

  try {
    final profile =
        await ref.read(profileRepositoryProvider).getProfile();
    ref.read(onboardingGateProvider.notifier).state =
        profileNeedsOnboarding(profile)
            ? OnboardingGate.required
            : OnboardingGate.complete;
  } catch (_) {
    // Do not block the app when profile API is unavailable.
    ref.read(onboardingGateProvider.notifier).state =
        OnboardingGate.complete;
  }
}
