import '../../data/models/revision_item.dart';
import '../../data/repositories/revision_repository.dart';

/// Fetches the spaced-repetition queue and filters to only due items.
class GetRevisionQueueUseCase {
  const GetRevisionQueueUseCase({required RevisionRepository repository})
      : _repository = repository;

  final RevisionRepository _repository;

  Future<List<RevisionItem>> call() async {
    final items = await _repository.getQueue();
    // Items without a dueAt are always due; those with it must be <= now.
    final now = DateTime.now();
    return items.where((item) {
      if (item.dueAt == null) return true;
      try {
        return !DateTime.parse(item.dueAt!).isAfter(now);
      } catch (_) {
        return true;
      }
    }).toList();
  }
}
