import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';

/// Whether the DeepTutor API at [AppConfig.apiBase] is reachable.
enum BackendReachability { unknown, reachable, unreachable }

/// Lightweight probe via `GET /auth/status` (no auth required).
///
/// Refreshes when [backendHealthRefreshProvider] is incremented (e.g. pull-to-refresh
/// or after the user starts the backend).
final backendHealthProvider =
    FutureProvider<BackendReachability>((ref) async {
  ref.watch(backendHealthRefreshProvider);
  final dio = ref.watch(dioProvider);
  try {
    await dio.get<void>(
      '/auth/status',
      options: Options(
        sendTimeout: const Duration(seconds: 2),
        receiveTimeout: const Duration(seconds: 2),
      ),
    );
    return BackendReachability.reachable;
  } on DioException catch (e) {
    if (e.response != null) {
      // Any HTTP response means the host is up.
      return BackendReachability.reachable;
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.unknown) {
      return BackendReachability.unreachable;
    }
    return BackendReachability.reachable;
  }
});

/// Bump to re-run [backendHealthProvider].
final backendHealthRefreshProvider = StateProvider<int>((ref) => 0);

void refreshBackendHealth(WidgetRef ref) {
  ref.read(backendHealthRefreshProvider.notifier).state++;
}
