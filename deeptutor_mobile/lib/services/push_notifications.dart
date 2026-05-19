import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Push notification facade — FCM when the host app adds Firebase config.
///
/// Enable native FCM by adding `firebase_messaging` + `google-services.json`,
/// then build with `--dart-define=FCM_ENABLED=true`.
class PushNotificationsService {
  PushNotificationsService();

  static const _tokenKey = 'pending_fcm_token';
  static const _enabled =
      bool.fromEnvironment('FCM_ENABLED', defaultValue: false);

  bool get isConfigured => _enabled && !kIsWeb;

  /// Returns the FCM token when Firebase is configured in the host app.
  Future<String?> token() async {
    if (!isConfigured) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    }
    // Host integrates firebase_messaging and calls [saveToken] from native setup.
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Called from Firebase `onTokenRefresh` once messaging is wired in.
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    // POST /notifications/device can be added when the backend exposes it.
  }

  Future<void> subscribe(String topic) async {
    if (!isConfigured) return;
  }

  Future<void> unsubscribe(String topic) async {}

  Future<void> onLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}

final pushNotificationsServiceProvider =
    Provider((_) => PushNotificationsService());
