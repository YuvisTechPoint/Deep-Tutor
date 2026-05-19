import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../data/models/revision_item.dart';
import '../../../data/repositories/revision_repository.dart';
import '../../auth/providers/auth_provider.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final revisionRepositoryProvider = Provider(
  (ref) => RevisionRepository(dio: ref.watch(dioProvider)),
);

// ── State ─────────────────────────────────────────────────────────────────────

sealed class RevisionState {
  const RevisionState();
}

class RevisionLoading extends RevisionState {
  const RevisionLoading();
}

class RevisionIdle extends RevisionState {
  const RevisionIdle({required this.queue, required this.currentIndex});
  final List<RevisionItem> queue;
  final int currentIndex;

  RevisionItem? get current =>
      currentIndex < queue.length ? queue[currentIndex] : null;
  bool get isLastCard => currentIndex >= queue.length - 1;
}

class RevisionEmpty extends RevisionState {
  const RevisionEmpty();
}

class RevisionDone extends RevisionState {
  const RevisionDone({required this.reviewed});
  final int reviewed;
}

class RevisionError extends RevisionState {
  const RevisionError({required this.message});
  final String message;
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class RevisionNotifier extends StateNotifier<RevisionState> {
  RevisionNotifier(this._repo) : super(const RevisionLoading()) {
    load();
  }

  final RevisionRepository _repo;
  int _reviewedCount = 0;

  Future<void> load() async {
    state = const RevisionLoading();
    try {
      final items = await _repo.getQueue();
      if (items.isEmpty) {
        state = const RevisionEmpty();
      } else {
        state = RevisionIdle(queue: items, currentIndex: 0);
        _reviewedCount = 0;
      }
    } catch (e) {
      state = RevisionError(message: friendlyErrorMessage(e));
    }
  }

  Future<void> submitRating(int rating) async {
    final current = state;
    if (current is! RevisionIdle) return;
    final item = current.current;
    if (item == null) return;

    try {
      await _repo.review(itemId: item.id, rating: rating);
      _reviewedCount++;
    } catch (_) {
      // Continue even if server call fails
    }

    final nextIndex = current.currentIndex + 1;
    if (nextIndex >= current.queue.length) {
      state = RevisionDone(reviewed: _reviewedCount);
    } else {
      state = RevisionIdle(
        queue: current.queue,
        currentIndex: nextIndex,
      );
    }
  }

  void restart() => load();
}

final revisionNotifierProvider =
    StateNotifierProvider.autoDispose<RevisionNotifier, RevisionState>(
  (ref) => RevisionNotifier(ref.watch(revisionRepositoryProvider)),
);

/// Pending revision count badge.
final revisionQueueCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final items = await ref.watch(revisionRepositoryProvider).getQueue();
  return items.length;
});
