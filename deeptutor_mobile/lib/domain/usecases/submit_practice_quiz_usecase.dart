import '../../data/models/practice.dart';
import '../../data/repositories/practice_repository.dart';

/// Submits a practice quiz and returns the scored result.
///
/// Delegates directly to the repository; exists in the domain layer
/// to centralise any future validation / retry logic.
class SubmitPracticeQuizUseCase {
  const SubmitPracticeQuizUseCase({required PracticeRepository repository})
      : _repository = repository;

  final PracticeRepository _repository;

  Future<PracticeSubmitResult> call({
    required String quizId,
    required List<Map<String, dynamic>> answers,
  }) =>
      _repository.submitQuiz(quizId: quizId, answers: answers);
}
