/// Domain-layer snapshot of a learner's profile.
///
/// Derived from `LearningProfile` (data layer) — stripped to
/// what business logic actually needs.
class LearningProfileEntity {
  const LearningProfileEntity({
    required this.userId,
    this.goals = const [],
    this.topics = const [],
    this.preferredDifficulty = 'medium',
    this.sessionLengthMinutes = 30,
    this.learningStyle,
  });

  final String userId;

  /// User-supplied learning goals (free-text lines).
  final List<String> goals;

  /// Topics the learner is interested in.
  final List<String> topics;

  /// "easy" | "medium" | "hard"
  final String preferredDifficulty;

  /// Preferred session duration in minutes.
  final int sessionLengthMinutes;

  /// "visual" | "textual" | "mixed" — optional.
  final String? learningStyle;

  LearningProfileEntity copyWith({
    String? userId,
    List<String>? goals,
    List<String>? topics,
    String? preferredDifficulty,
    int? sessionLengthMinutes,
    String? learningStyle,
  }) =>
      LearningProfileEntity(
        userId: userId ?? this.userId,
        goals: goals ?? this.goals,
        topics: topics ?? this.topics,
        preferredDifficulty: preferredDifficulty ?? this.preferredDifficulty,
        sessionLengthMinutes: sessionLengthMinutes ?? this.sessionLengthMinutes,
        learningStyle: learningStyle ?? this.learningStyle,
      );
}
