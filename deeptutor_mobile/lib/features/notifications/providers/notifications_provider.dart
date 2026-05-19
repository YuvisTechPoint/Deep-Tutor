import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../data/models/notification_item.dart';
import '../../../data/repositories/notifications_repository.dart';
import '../../auth/providers/auth_provider.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final notificationsRepositoryProvider = Provider(
  (ref) => NotificationsRepository(dio: ref.watch(dioProvider)),
);

// ── State ─────────────────────────────────────────────────────────────────────

class NotificationsState {
  const NotificationsState({
    required this.items,
    this.isLoading = false,
    this.error,
  });

  final List<NotificationItem> items;
  final bool isLoading;
  final String? error;

  int get unreadCount => items.where((n) => !n.isRead).length;

  NotificationsState copyWith({
    List<NotificationItem>? items,
    bool? isLoading,
    String? error,
  }) =>
      NotificationsState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier(this._repo)
      : super(const NotificationsState(items: [])) {
    load();
  }

  final NotificationsRepository _repo;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _repo.getNotifications();
      state = NotificationsState(items: items);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: friendlyErrorMessage(e),
      );
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _repo.markRead(id);
      final updated = state.items
          .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
          .toList();
      state = state.copyWith(items: updated);
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    if (state.unreadCount == 0) return;
    try {
      await _repo.markAllRead();
      final updated =
          state.items.map((n) => n.copyWith(isRead: true)).toList();
      state = state.copyWith(items: updated);
    } catch (_) {}
  }

  Future<bool> deleteNotification(String id) async {
    final previous = state.items;
    state = state.copyWith(
      items: previous.where((n) => n.id != id).toList(),
    );
    try {
      await _repo.delete(id);
      return true;
    } catch (_) {
      state = state.copyWith(items: previous);
      return false;
    }
  }
}

final notificationsNotifierProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier(ref.watch(notificationsRepositoryProvider));
});

/// Unread count for badge indicators (used in home screen AppBar).
final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsNotifierProvider).unreadCount;
});
