import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/gamification.dart';
import '../../home/providers/home_provider.dart';

export '../../home/providers/home_provider.dart'
    show
        gamificationRepositoryProvider,
        gamificationStateProvider,
        missionsTodayProvider,
        missionsNotifierProvider,
        MissionsNotifier,
        MissionsNotifierState;

/// Reward catalog merged with live claim state from gamification.
final missionsRewardCatalogProvider =
    FutureProvider.autoDispose<List<RewardCatalogItem>>((ref) async {
  final repo = ref.watch(gamificationRepositoryProvider);
  final catalog = await repo.getRewardCatalog();
  final gam = await ref.watch(gamificationStateProvider.future);
  final claimed = gam.claimedRewardIds.toSet();
  return catalog
      .map((r) => r.copyWith(claimed: claimed.contains(r.id)))
      .toList();
});

/// Live XP ledger entries for missions hub activity feed.
final missionsXpHistoryProvider =
    FutureProvider.autoDispose<List<XpLedgerEntry>>((ref) async {
  final repo = ref.watch(gamificationRepositoryProvider);
  final raw = await repo.getXpHistory(limit: 12);
  return raw.map(XpLedgerEntry.fromJson).toList();
});

/// Refresh missions + gamification + rewards (pull, WS, completion).
void refreshMissionsHub(WidgetRef ref) {
  ref.read(missionsNotifierProvider.notifier).load();
  ref.invalidate(gamificationStateProvider);
  ref.invalidate(missionsTodayProvider);
  ref.invalidate(missionsRewardCatalogProvider);
  ref.invalidate(missionsXpHistoryProvider);
}

/// One row from `GET /gamification/xp-history`.
class XpLedgerEntry {
  const XpLedgerEntry({
    required this.action,
    required this.xp,
    required this.source,
    required this.timestamp,
  });

  final String action;
  final int xp;
  final String source;
  final String timestamp;

  factory XpLedgerEntry.fromJson(Map<String, dynamic> json) => XpLedgerEntry(
        action: json['action']?.toString() ?? '',
        xp: (json['xp'] as num?)?.toInt() ?? 0,
        source: json['source']?.toString() ?? '',
        timestamp: json['timestamp']?.toString() ?? '',
      );

  String get label {
    final a = action.replaceAll('.', ' · ');
    if (source.startsWith('mission:')) return 'Mission · $a';
    return a;
  }
}
