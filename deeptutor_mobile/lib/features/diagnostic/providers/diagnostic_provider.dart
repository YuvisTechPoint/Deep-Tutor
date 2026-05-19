import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../data/repositories/diagnostic_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../onboarding/providers/onboarding_provider.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final diagnosticRepositoryProvider = Provider(
  (ref) => DiagnosticRepository(dio: ref.watch(dioProvider)),
);

// ── State ─────────────────────────────────────────────────────────────────────

sealed class DiagnosticState {
  const DiagnosticState();
}

class DiagnosticReady extends DiagnosticState {
  const DiagnosticReady();
}

class DiagnosticLoading extends DiagnosticState {
  const DiagnosticLoading();
}

class DiagnosticActive extends DiagnosticState {
  const DiagnosticActive({
    required this.quizId,
    required this.questions,
    required this.currentIndex,
    required this.answers,
  });

  final String quizId;
  final List<Map<String, dynamic>> questions;
  final int currentIndex;
  final Map<String, int> answers;

  Map<String, dynamic> get current => questions[currentIndex];
  bool get isLast => currentIndex >= questions.length - 1;
}

class DiagnosticSubmitting extends DiagnosticState {
  const DiagnosticSubmitting();
}

class DiagnosticResult extends DiagnosticState {
  const DiagnosticResult({required this.result});
  final Map<String, dynamic> result;
}

class DiagnosticError extends DiagnosticState {
  const DiagnosticError({required this.message});
  final String message;
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class DiagnosticNotifier extends StateNotifier<DiagnosticState> {
  DiagnosticNotifier(this._repo, this._profileRepo) : super(const DiagnosticReady());

  final DiagnosticRepository _repo;
  final ProfileRepository _profileRepo;

  Future<void> start({String? topic}) async {
    state = const DiagnosticLoading();
    try {
      final data = await _repo.start(topic: topic);
      final quizId = data['quiz_id'] as String? ?? '';
      final questions = (data['questions'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      if (questions.isEmpty) {
        state = const DiagnosticError(message: 'No questions returned');
        return;
      }
      state = DiagnosticActive(
        quizId: quizId,
        questions: questions,
        currentIndex: 0,
        answers: {},
      );
    } catch (e) {
      state = DiagnosticError(message: friendlyErrorMessage(e));
    }
  }

  void selectAnswer(String questionId, int optionIndex) {
    final current = state;
    if (current is! DiagnosticActive) return;
    state = DiagnosticActive(
      quizId: current.quizId,
      questions: current.questions,
      currentIndex: current.currentIndex,
      answers: {...current.answers, questionId: optionIndex},
    );
  }

  void next() {
    final current = state;
    if (current is! DiagnosticActive) return;
    if (current.isLast) return;
    state = DiagnosticActive(
      quizId: current.quizId,
      questions: current.questions,
      currentIndex: current.currentIndex + 1,
      answers: current.answers,
    );
  }

  Future<void> finish() async {
    final current = state;
    if (current is! DiagnosticActive) return;

    state = const DiagnosticSubmitting();
    try {
      final answers = <Map<String, dynamic>>[];
      for (final e in current.answers.entries) {
        Map<String, dynamic>? q;
        for (final item in current.questions) {
          if (item['id'] == e.key) {
            q = item;
            break;
          }
        }
        final keys = (q?['option_keys'] as List<dynamic>?)?.cast<String>() ??
            const ['A', 'B', 'C', 'D'];
        final idx = e.value;
        final answer = idx >= 0 && idx < keys.length
            ? keys[idx]
            : String.fromCharCode(65 + idx.clamp(0, 25));
        answers.add({'question_id': e.key, 'answer': answer});
      }
      final result = await _repo.finish(
        quizId: current.quizId,
        answers: answers,
      );
      try {
        final profile = await _profileRepo.getProfile();
        await _profileRepo.updateProfile(
          profile.copyWith(diagnosticCompleted: true),
        );
      } catch (_) {}
      state = DiagnosticResult(result: result);
    } catch (e) {
      state = DiagnosticError(message: friendlyErrorMessage(e));
    }
  }

  void reset() => state = const DiagnosticReady();
}

final diagnosticNotifierProvider =
    StateNotifierProvider.autoDispose<DiagnosticNotifier, DiagnosticState>(
  (ref) => DiagnosticNotifier(
    ref.watch(diagnosticRepositoryProvider),
    ref.watch(profileRepositoryProvider),
  ),
);
