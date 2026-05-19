import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/career/providers/career_live_provider.dart';
import '../../services/realtime_sync.dart';
import 'backend_health.dart';
import 'global_chat_ws.dart';

/// Keeps global realtime channels alive while the user is authenticated.
///
/// - Career/gamification WS ([careerLiveListenerProvider])
/// - Unified chat WS ([globalUnifiedWsProvider])
/// - Backend health probe every 30s
/// - Live data refresh every 45s (missions, XP, sessions, notifications)
final realtimeHubProvider = Provider<void>((ref) {
  final auth = ref.watch(authNotifierProvider);
  if (auth is! AuthAuthenticated) return;

  ref.watch(careerLiveListenerProvider);
  ref.watch(globalUnifiedWsProvider);

  Timer? healthPoll;
  Timer? liveRefresh;

  healthPoll = Timer.periodic(const Duration(seconds: 30), (_) {
    ref.read(backendHealthRefreshProvider.notifier).state++;
  });

  liveRefresh = Timer.periodic(const Duration(seconds: 45), (_) {
    refreshAppLiveData(ref.container);
  });

  ref.onDispose(() {
    healthPoll?.cancel();
    liveRefresh?.cancel();
  });

  ref.read(backendHealthRefreshProvider.notifier).state++;
  refreshAppLiveData(ref.container);
});
