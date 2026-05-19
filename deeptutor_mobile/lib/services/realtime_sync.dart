import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/chat/providers/chat_provider.dart';
import '../features/home/providers/home_insights_provider.dart';
import '../features/missions/providers/missions_provider.dart';
import '../features/notifications/providers/notifications_provider.dart';
import '../features/revision/providers/revision_provider.dart';

/// Monotonic tick — widgets can `watch` to re-run lightweight refresh logic.
final realtimeTickProvider = StateProvider<int>((ref) => 0);

/// Invalidates / reloads all user-visible live dashboards.
void refreshAppLiveData(
  ProviderContainer container, {
  bool reloadNotifications = true,
}) {
  container.invalidate(chatSessionsProvider);
  container.invalidate(homeInsightsProvider);
  container.invalidate(gamificationStateProvider);
  container.invalidate(missionsTodayProvider);
  container.invalidate(missionsRewardCatalogProvider);
  container.invalidate(missionsXpHistoryProvider);
  container.invalidate(revisionQueueCountProvider);

  if (container.exists(missionsNotifierProvider)) {
    container.read(missionsNotifierProvider.notifier).load();
  }
  if (reloadNotifications && container.exists(notificationsNotifierProvider)) {
    container.read(notificationsNotifierProvider.notifier).load();
  }

  container.read(realtimeTickProvider.notifier).state++;
}

void bumpRealtimeTick(ProviderContainer container) {
  container.read(realtimeTickProvider.notifier).state++;
}
