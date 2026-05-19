import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/stream_event.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../services/realtime_sync.dart';
import 'backend_health.dart';
import 'ws_client.dart';

/// App-wide unified chat WebSocket — stays connected while authenticated.
final globalUnifiedWsProvider = Provider<UnifiedWsClient?>((ref) {
  final auth = ref.watch(authNotifierProvider);
  if (auth is! AuthAuthenticated) return null;

  final config = ref.watch(appConfigProvider);
  final token = ref.watch(authTokenProvider);
  final client = UnifiedWsClient(
    wsUrl: config.unifiedWsUrl,
    token: token,
  );

  var lastSessionRefresh = DateTime.fromMillisecondsSinceEpoch(0);

  void maybeRefreshSessions(StreamEvent event) {
    final t = event.type;
    if (t != StreamEventType.done &&
        t != StreamEventType.error &&
        t != StreamEventType.session) {
      return;
    }
    final now = DateTime.now();
    if (now.difference(lastSessionRefresh).inMilliseconds < 800) return;
    lastSessionRefresh = now;
    refreshAppLiveData(
      ref.container,
      reloadNotifications: t != StreamEventType.session,
    );
  }

  final eventSub = client.events.listen(maybeRefreshSessions);

  ref.listen<AsyncValue<BackendReachability>>(backendHealthProvider, (_, next) {
    if (next.value == BackendReachability.reachable) {
      client.retryAfterBackendUp();
    }
  });

  ref.onDispose(() {
    eventSub.cancel();
    client.dispose();
  });

  client.connect();
  return client;
});

/// Live connection state for chrome indicators (chat header, etc.).
final globalWsConnectionStateProvider = StreamProvider<WsConnectionState>((ref) {
  final client = ref.watch(globalUnifiedWsProvider);
  if (client == null) {
    return Stream.value(WsConnectionState.disconnected);
  }
  return client.connectionState;
});
