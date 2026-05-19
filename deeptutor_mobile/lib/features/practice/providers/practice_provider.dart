import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../data/models/api_mappers.dart';
import '../../../data/models/practice.dart';
import '../../../data/repositories/practice_repository.dart';
import '../../../services/offline_queue.dart';
import '../../auth/providers/auth_provider.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final practiceRepositoryProvider = Provider(
  (ref) => PracticeRepository(dio: ref.watch(dioProvider)),
);

// ── Offline queue ─────────────────────────────────────────────────────────────

final offlineQueueProvider = Provider<HiveOfflineQueue>((ref) {
  final queue = HiveOfflineQueue();
  ref.onDispose(queue.dispose);
  return queue;
});

final practiceTopicsProvider = FutureProvider.autoDispose<List<PracticeTopic>>(
  (ref) => ref.watch(practiceRepositoryProvider).getTopics(),
);

// ── Practice state ────────────────────────────────────────────────────────────

sealed class PracticeState {
  const PracticeState();
}

class PracticeIdle extends PracticeState {
  const PracticeIdle();
}

class PracticeLoading extends PracticeState {
  const PracticeLoading();
}

class PracticeQuizActive extends PracticeState {
  const PracticeQuizActive({
    required this.quizId,
    required this.questions,
    required this.currentIndex,
    required this.answers,
    required this.hints,
  });

  final String quizId;
  final List<PracticeQuestion> questions;
  final int currentIndex;
  final Map<String, int> answers;
  final Map<String, String> hints;
}

class PracticeSubmitting extends PracticeState {
  const PracticeSubmitting();
}

class PracticeResult extends PracticeState {
  const PracticeResult({required this.result});
  final PracticeSubmitResult result;
}

class PracticeError extends PracticeState {
  const PracticeError({required this.message});
  final String message;
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class PracticeNotifier extends StateNotifier<PracticeState> {
  PracticeNotifier(this._repo, this._queue) : super(const PracticeIdle()) {
    _initQueue();
  }

  final PracticeRepository _repo;
  final HiveOfflineQueue _queue;

  Future<void> _initQueue() async {
    await _queue.init();
    _queue.startFlushListener(
      onFlush: (pending) => _repo.submitQuiz(
        quizId: pending.quizId,
        answers: pending.answersDecoded,
      ),
    );
  }

  Future<void> startQuiz({String? topic, String? difficulty}) async {
    state = const PracticeLoading();
    try {
      final response = await _repo.getQuestions(
        topic: topic,
        difficulty: difficulty,
      );
      state = PracticeQuizActive(
        quizId: response.quizId,
        questions: response.questions,
        currentIndex: 0,
        answers: {},
        hints: {},
      );
    } on Exception catch (e) {
      final msg = e.toString().contains('410')
          ? 'Quiz expired. Please try again.'
          : friendlyErrorMessage(e);
      state = PracticeError(message: msg);
    }
  }

  void selectAnswer(String questionId, int optionIndex) {
    final current = state;
    if (current is! PracticeQuizActive) return;
    state = PracticeQuizActive(
      quizId: current.quizId,
      questions: current.questions,
      currentIndex: current.currentIndex,
      answers: {...current.answers, questionId: optionIndex},
      hints: current.hints,
    );
  }

  void nextQuestion() {
    final current = state;
    if (current is! PracticeQuizActive) return;
    if (current.currentIndex >= current.questions.length - 1) return;
    state = PracticeQuizActive(
      quizId: current.quizId,
      questions: current.questions,
      currentIndex: current.currentIndex + 1,
      answers: current.answers,
      hints: current.hints,
    );
  }

  void previousQuestion() {
    final current = state;
    if (current is! PracticeQuizActive) return;
    if (current.currentIndex <= 0) return;
    state = PracticeQuizActive(
      quizId: current.quizId,
      questions: current.questions,
      currentIndex: current.currentIndex - 1,
      answers: current.answers,
      hints: current.hints,
    );
  }

  Future<void> fetchHint(String questionId) async {
    final current = state;
    if (current is! PracticeQuizActive) return;
    try {
      final hint = await _repo.getHint(
        quizId: current.quizId,
        questionId: questionId,
      );
      if (hint != null) {
        state = PracticeQuizActive(
          quizId: current.quizId,
          questions: current.questions,
          currentIndex: current.currentIndex,
          answers: current.answers,
          hints: {...current.hints, questionId: hint},
        );
      }
    } catch (_) {}
  }

  Future<void> submit() async {
    final current = state;
    if (current is! PracticeQuizActive) return;

    state = const PracticeSubmitting();
    final answers = _buildSubmitAnswers(current);

    try {
      // Check connectivity before attempting submit
      final connectivity = await Connectivity().checkConnectivity();
      final isOffline = connectivity.every((r) => r == ConnectivityResult.none);

      if (isOffline) {
        // Persist for later retry
        await _queue.enqueue(quizId: current.quizId, answers: answers);
        state = PracticeError(
          message: 'You\'re offline. Your answers have been saved and will '
              'be submitted automatically when you reconnect.',
        );
        return;
      }

      final result = await _repo.submitQuiz(
        quizId: current.quizId,
        answers: answers,
      );
      state = PracticeResult(result: result);
    } on Exception catch (e) {
      final msg = e.toString();

      // 410 = quiz expired; nothing to queue (server-side state gone)
      if (msg.contains('410')) {
        state = PracticeError(
            message: 'Quiz expired — the server restarted. Please start a new quiz.');
        return;
      }

      // Network error → queue for later
      await _queue.enqueue(quizId: current.quizId, answers: answers);
      state = PracticeError(
        message: 'Submit failed. Your answers have been saved '
            'and will be retried when you reconnect.',
      );
    }
  }

  void reset() => state = const PracticeIdle();

  static List<Map<String, dynamic>> _buildSubmitAnswers(
    PracticeQuizActive quiz,
  ) {
    final result = <Map<String, dynamic>>[];
    for (final e in quiz.answers.entries) {
      PracticeQuestion? question;
      for (final q in quiz.questions) {
        if (q.id == e.key) {
          question = q;
          break;
        }
      }
      result.add({
        'question_id': e.key,
        'answer': question != null
            ? ApiMappers.answerKeyForIndex(question, e.value)
            : String.fromCharCode(65 + e.value.clamp(0, 25)),
      });
    }
    return result;
  }
}

final practiceNotifierProvider =
    StateNotifierProvider.autoDispose<PracticeNotifier, PracticeState>(
  (ref) => PracticeNotifier(
    ref.watch(practiceRepositoryProvider),
    ref.watch(offlineQueueProvider),
  ),
);

/// Exposes count of pending offline submits (for UI badge).
final pendingSubmitsCountProvider = Provider<int>((ref) {
  return ref.watch(offlineQueueProvider).pendingCount;
});
