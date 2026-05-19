/// Domain entity for gamification progress.
class GamificationEntity {
  const GamificationEntity({
    required this.userId,
    required this.xp,
    required this.level,
    required this.streak,
    this.badges = const [],
  });

  final String userId;
  final int xp;
  final int level;

  /// Consecutive-days streak.
  final int streak;

  /// Earned badge identifiers.
  final List<String> badges;

  GamificationEntity copyWith({
    String? userId,
    int? xp,
    int? level,
    int? streak,
    List<String>? badges,
  }) =>
      GamificationEntity(
        userId: userId ?? this.userId,
        xp: xp ?? this.xp,
        level: level ?? this.level,
        streak: streak ?? this.streak,
        badges: badges ?? this.badges,
      );
}
