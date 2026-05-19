import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/tutorbot_repository.dart';
import '../../auth/providers/auth_provider.dart';

final tutorBotRepositoryProvider = Provider(
  (ref) => TutorBotRepository(dio: ref.watch(dioProvider)),
);

/// Live TutorBot list with pull-to-refresh and periodic sync while mounted.
final tutorBotsListProvider =
    StateNotifierProvider.autoDispose<TutorBotsListNotifier, TutorBotsListState>(
  (ref) {
    final notifier = TutorBotsListNotifier(ref.watch(tutorBotRepositoryProvider));
    ref.onDispose(notifier.dispose);
    return notifier;
  },
);

class TutorBotsListState {
  const TutorBotsListState({
    this.bots = const [],
    this.isLoading = true,
    this.isSyncing = false,
    this.error,
  });

  final List<TutorBotSummary> bots;
  final bool isLoading;
  final bool isSyncing;
  final Object? error;

  bool get hasError => error != null;
}

class TutorBotsListNotifier extends StateNotifier<TutorBotsListState> {
  TutorBotsListNotifier(this._repo) : super(const TutorBotsListState()) {
    load();
    _poll = Timer.periodic(const Duration(seconds: 12), (_) => load(sync: true));
  }

  final TutorBotRepository _repo;
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> load({bool sync = false}) async {
    if (!sync || state.bots.isEmpty) {
      state = TutorBotsListState(
        bots: state.bots,
        isLoading: state.bots.isEmpty,
        isSyncing: sync && state.bots.isNotEmpty,
        error: null,
      );
    } else {
      state = TutorBotsListState(
        bots: state.bots,
        isLoading: false,
        isSyncing: true,
        error: null,
      );
    }
    try {
      final bots = await _repo.list();
      state = TutorBotsListState(bots: bots);
    } catch (e) {
      state = TutorBotsListState(
        bots: state.bots,
        isLoading: false,
        isSyncing: false,
        error: e,
      );
    }
  }

  Future<TutorBotSummary?> create({
    required String name,
    String? description,
    String? focus,
  }) async {
    try {
      final created = await _repo.create(
        name: name,
        description: description,
        persona: focus,
      );
      await load(sync: true);
      return created;
    } catch (e) {
      state = TutorBotsListState(
        bots: state.bots,
        error: e,
      );
      rethrow;
    }
  }

  Future<void> destroy(String id) async {
    final previous = state.bots;
    state = TutorBotsListState(
      bots: previous.where((b) => b.id != id).toList(),
      isSyncing: true,
    );
    try {
      await _repo.destroy(id);
      await load(sync: true);
    } catch (e) {
      state = TutorBotsListState(bots: previous, error: e);
      rethrow;
    }
  }
}
