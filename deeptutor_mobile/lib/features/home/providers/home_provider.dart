import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/gamification.dart';
import '../../../data/repositories/gamification_repository.dart';
import '../../auth/providers/auth_provider.dart';

// ── Repository providers ──────────────────────────────────────────────────────

final gamificationRepositoryProvider = Provider(
  (ref) => GamificationRepository(dio: ref.watch(dioProvider)),
);

// ── Async data providers ──────────────────────────────────────────────────────

final gamificationStateProvider =
    FutureProvider.autoDispose<GamificationState>((ref) async {
  final repo = ref.watch(gamificationRepositoryProvider);
  return repo.getState();
});

final missionsTodayProvider =
    FutureProvider.autoDispose<MissionsToday>((ref) async {
  final repo = ref.watch(gamificationRepositoryProvider);
  return repo.getMissionsToday();
});

// ── Mission completion (live API) ─────────────────────────────────────────────

class MissionsNotifier extends StateNotifier<MissionsNotifierState> {
  MissionsNotifier(this._repo) : super(const MissionsNotifierState.loading()) {
    load();
  }

  final GamificationRepository _repo;

  Future<void> load() async {
    if (state.missions == null) {
      state = const MissionsNotifierState.loading();
    } else {
      state = state.copyWith(syncing: true);
    }
    try {
      final data = await _repo.getMissionsToday();
      state = MissionsNotifierState.ready(
        data: data,
        completingId: null,
        syncing: false,
      );
    } catch (e, s) {
      state = MissionsNotifierState.error(e, s, previous: state.missions);
    }
  }

  Future<MissionCompleteResult?> complete(
    String missionId, {
    int? xpReward,
  }) async {
    final current = state.missions;
    if (current == null) return null;

    state = state.copyWith(
      completingId: missionId,
      missions: _markMissionComplete(current, missionId),
    );
    try {
      final result = await _repo.completeMissionWithResult(
        missionId,
        xpReward: xpReward,
      );
      await load();
      return result;
    } catch (e, s) {
      state = MissionsNotifierState.error(e, s, previous: current);
      rethrow;
    }
  }

  static MissionsToday _markMissionComplete(MissionsToday today, String id) {
    var completed = today.completedCount;
    final missions = today.missions.map((m) {
      if (m.id == id && !m.completed) {
        completed++;
        return Mission(
          id: m.id,
          title: m.title,
          description: m.description,
          xpReward: m.xpReward,
          completed: true,
          progress: m.target ?? m.progress,
          target: m.target,
          type: m.type,
          category: m.category,
          duration: m.duration,
          ctaHref: m.ctaHref,
          iconKey: m.iconKey,
          colorKey: m.colorKey,
        );
      }
      return m;
    }).toList();

    Mission? bonus = today.bonus;
    if (bonus != null && bonus.id == id && !bonus.completed) {
      completed++;
      bonus = Mission(
        id: bonus.id,
        title: bonus.title,
        description: bonus.description,
        xpReward: bonus.xpReward,
        completed: true,
        category: bonus.category,
        duration: bonus.duration,
        ctaHref: bonus.ctaHref,
        iconKey: bonus.iconKey,
        colorKey: bonus.colorKey,
      );
    }

    return MissionsToday(
      missions: missions,
      completedCount: completed,
      totalCount: today.totalCount,
      date: today.date,
      xpEarned: today.xpEarned,
      xpTarget: today.xpTarget,
      bonus: bonus,
    );
  }
}

class MissionsNotifierState {
  const MissionsNotifierState._({
    this.missions,
    this.error,
    this.stackTrace,
    this.completingId,
    this.syncing = false,
    this.isLoading = false,
  });

  const MissionsNotifierState.loading()
      : this._(isLoading: true);

  const MissionsNotifierState.ready({
    required MissionsToday data,
    String? completingId,
    bool syncing = false,
  }) : this._(missions: data, completingId: completingId, syncing: syncing);

  const MissionsNotifierState.error(
    Object error,
    StackTrace stackTrace, {
    MissionsToday? previous,
  }) : this._(
          missions: previous,
          error: error,
          stackTrace: stackTrace,
        );

  final MissionsToday? missions;
  final Object? error;
  final StackTrace? stackTrace;
  final String? completingId;
  final bool syncing;
  final bool isLoading;

  bool get hasError => error != null;
  bool get isInitialLoading => isLoading && missions == null;

  MissionsNotifierState copyWith({
    MissionsToday? missions,
    String? completingId,
    bool? syncing,
    bool clearError = false,
  }) {
    return MissionsNotifierState._(
      missions: missions ?? this.missions,
      error: clearError ? null : error,
      stackTrace: clearError ? null : stackTrace,
      completingId: completingId,
      syncing: syncing ?? this.syncing,
    );
  }
}

final missionsNotifierProvider = StateNotifierProvider.autoDispose<
    MissionsNotifier, MissionsNotifierState>(
  (ref) => MissionsNotifier(ref.watch(gamificationRepositoryProvider)),
);
