import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the chat composer should pre-send through `/safety/moderate`.
class SafetyEnabledNotifier extends StateNotifier<bool> {
  SafetyEnabledNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('safety_moderate_enabled') ?? false;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('safety_moderate_enabled', value);
  }
}

final safetyEnabledProvider =
    StateNotifierProvider<SafetyEnabledNotifier, bool>(
  (_) => SafetyEnabledNotifier(),
);
