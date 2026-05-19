import '../../data/repositories/notifications_repository.dart';

/// Marks one or all notifications read.
///
/// Centralises logic so the UI and background push handler
/// can share the same "mark read" path.
class MarkNotificationsReadUseCase {
  const MarkNotificationsReadUseCase({
    required NotificationsRepository repository,
  }) : _repository = repository;

  final NotificationsRepository _repository;

  Future<void> call(List<String> ids) async {
    if (ids.isEmpty) {
      await _repository.markAllRead();
      return;
    }
    for (final id in ids) {
      await _repository.markRead(id);
    }
  }

  Future<void> single(String id) => _repository.markRead(id);
}
