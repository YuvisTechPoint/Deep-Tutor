import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles all persistent credential and lightweight preference storage.
///
/// - JWT token → [FlutterSecureStorage] on mobile (AES-backed)
/// - Web → [SharedPreferences] (secure storage can hang on some browsers)
/// - Username / role → [SharedPreferences] (non-sensitive cache)
class SecureTokenStore {
  SecureTokenStore({
    FlutterSecureStorage? secure,
  }) : _secure = secure ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _secure;

  static const _keyToken = 'dt_token';
  static const _keyUsername = 'dt_username';
  static const _keyRole = 'dt_role';
  static const _keyDemoMode = 'dt_demo_mode';

  Future<void> writeToken(String token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyToken, token);
      return;
    }
    await _secure.write(key: _keyToken, value: token);
  }

  Future<String?> readToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyToken);
    }
    return _secure.read(key: _keyToken);
  }

  Future<void> deleteToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyToken);
      return;
    }
    await _secure.delete(key: _keyToken);
  }

  Future<void> writeUser({
    required String username,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyRole, role);
  }

  Future<({String? username, String? role})> readUser() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      username: prefs.getString(_keyUsername),
      role: prefs.getString(_keyRole),
    );
  }

  Future<bool> readDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDemoMode) ?? false;
  }

  Future<void> setDemoMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    if (enabled) {
      await prefs.setBool(_keyDemoMode, true);
    } else {
      await prefs.remove(_keyDemoMode);
    }
  }

  Future<void> clearAll() async {
    if (!kIsWeb) {
      await _secure.deleteAll();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyDemoMode);
  }
}
