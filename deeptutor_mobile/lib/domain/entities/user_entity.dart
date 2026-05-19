/// Core user entity — auth-layer identity only.
///
/// UI layers that need learning-profile details should use
/// `LearningProfile` from the data layer instead.
class UserEntity {
  const UserEntity({
    required this.id,
    required this.username,
    this.email,
    this.avatarUrl,
    this.createdAt,
  });

  final String id;
  final String username;
  final String? email;
  final String? avatarUrl;
  final String? createdAt;

  UserEntity copyWith({
    String? id,
    String? username,
    String? email,
    String? avatarUrl,
    String? createdAt,
  }) =>
      UserEntity(
        id: id ?? this.id,
        username: username ?? this.username,
        email: email ?? this.email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserEntity && other.id == id && other.username == username);

  @override
  int get hashCode => Object.hash(id, username);

  @override
  String toString() => 'UserEntity(id: $id, username: $username)';
}
