import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/providers/auth_provider.dart';

/// Opt-in analytics sink.
///
/// When [enabled] is `true`, events are buffered and flushed via POST to
/// `/api/v1/admin/domain-events`. The server may not have an emit endpoint
/// today; failures are swallowed so they don't disrupt the UI.
class TelemetrySink {
  TelemetrySink({required Dio dio}) : _dio = dio {
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => flush());
  }

  final Dio _dio;
  final List<Map<String, dynamic>> _buffer = [];
  late final Timer _timer;
  bool _enabled = false;

  bool get enabled => _enabled;
  set enabled(bool v) {
    _enabled = v;
    if (!v) _buffer.clear();
  }

  void track(String event, {Map<String, dynamic>? props}) {
    if (!_enabled) return;
    _buffer.add({
      'event': event,
      'ts': DateTime.now().toIso8601String(),
      if (props != null) ...props,
    });
    if (_buffer.length >= 50) {
      unawaited(flush());
    }
  }

  Future<void> flush() async {
    if (!_enabled || _buffer.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();
    try {
      await _dio.post<void>('/admin/domain-events', data: {'events': batch});
    } catch (_) {
      // Silently drop — telemetry must never disrupt the UX.
    }
  }

  void dispose() {
    _timer.cancel();
  }
}

class TelemetryEnabledNotifier extends StateNotifier<bool> {
  TelemetryEnabledNotifier(this._sink) : super(false) {
    _load();
  }

  static const _key = 'telemetry_enabled';
  final TelemetrySink _sink;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getBool(_key) ?? false;
    state = v;
    _sink.enabled = v;
  }

  Future<void> set(bool v) async {
    state = v;
    _sink.enabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, v);
  }
}

final telemetrySinkProvider = Provider(
  (ref) => TelemetrySink(dio: ref.watch(dioProvider)),
);

final telemetryEnabledProvider =
    StateNotifierProvider<TelemetryEnabledNotifier, bool>(
  (ref) => TelemetryEnabledNotifier(ref.watch(telemetrySinkProvider)),
);
