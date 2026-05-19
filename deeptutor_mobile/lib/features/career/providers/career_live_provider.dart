import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/career_ws_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../services/realtime_sync.dart';
import 'career_provider.dart';

/// Keeps `/api/v1/career/ws` open while authenticated; invalidates on pushes.
final careerLiveListenerProvider = Provider<CareerWsClient?>((ref) {
  final auth = ref.watch(authNotifierProvider);
  if (auth is! AuthAuthenticated) return null;

  final config = ref.watch(appConfigProvider);
  final token = ref.watch(authTokenProvider);
  final client = CareerWsClient(wsUrl: config.careerWsUrl, token: token);

  final sub = client.events.listen((msg) {
    final type = msg['type']?.toString();
    if (type == 'career_refresh' || type == 'gamification_update') {
      ref.invalidate(careerPathsProvider);
      refreshAppLiveData(ref.container);
    }
  });

  ref.onDispose(() {
    sub.cancel();
    client.dispose();
  });

  client.connect();
  return client;
});
