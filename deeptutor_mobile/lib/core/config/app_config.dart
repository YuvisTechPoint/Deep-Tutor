/// Central application configuration.
///
/// Supports dev (Android emulator) and prod flavors.
/// API base is resolved from compile-time env or sensible defaults.
library;

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

enum AppFlavor { dev, prod }

class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.apiBase,
  });

  final AppFlavor flavor;

  /// e.g. "http://localhost:8001" (dev) or "https://api.example.com" (prod)
  final String apiBase;

  /// /api/v1 prefix
  String get apiV1 => '$apiBase/api/v1';

  /// Converts http(s) → ws(s) for WebSocket connections
  String get wsBase => apiBase
      .replaceFirst('https://', 'wss://')
      .replaceFirst('http://', 'ws://');

  String get unifiedWsUrl => '$wsBase/api/v1/ws';
  String get careerWsUrl => '$wsBase/api/v1/career/ws';
  String get bookWsUrl => '$wsBase/api/v1/book/ws';

  bool get isDev => flavor == AppFlavor.dev;

  /// Public privacy policy (opened from Settings).
  static const String privacyPolicyUrl = 'https://deeptutor.app/privacy';

  /// Dev config — no `--dart-define` required for `flutter run -d chrome`.
  ///
  /// - Flutter UI: `http://localhost:<random>` (e.g. 52237) — served by `flutter run`
  /// - API backend: `http://localhost:8001` — separate process, same machine
  static final AppConfig dev = AppConfig(
    flavor: AppFlavor.dev,
    apiBase: _resolveDevApiBase(),
  );

  static String _resolveDevApiBase() {
    const fromEnv = String.fromEnvironment('API_BASE');
    if (fromEnv.isNotEmpty) return fromEnv;

    const port = String.fromEnvironment('BACKEND_PORT', defaultValue: '8001');

    if (kIsWeb) {
      // Match the browser host (localhost) so CORS aligns with the Flutter dev URL.
      final host = Uri.base.host;
      final resolvedHost =
          host.isEmpty || host == '127.0.0.1' ? 'localhost' : host;
      return 'http://$resolvedHost:$port';
    }

    return 'http://10.0.2.2:$port';
  }

  static const AppConfig prod = AppConfig(
    flavor: AppFlavor.prod,
    apiBase: String.fromEnvironment(
      'API_BASE',
      defaultValue: 'https://api.deeptutor.app',
    ),
  );

  /// Active config: `--dart-define=APP_FLAVOR=dev|prod`, else prod in release builds.
  static AppConfig get current {
    const flavor = String.fromEnvironment('APP_FLAVOR');
    if (flavor == 'dev') return dev;
    if (flavor == 'prod') return prod;
    return kReleaseMode ? prod : dev;
  }
}
