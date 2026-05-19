import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Read-through cache for backend resources keyed by (namespace, key).
///
/// Values are JSON-encoded strings to keep Hive happy with mixed shapes.
/// Use [readJson] / [writeJson] for typed maps/lists.
class LocalCache {
  LocalCache._();

  static const _boxName = 'dt_local_cache';
  static bool _hiveInitialized = false;
  static Box<String>? _box;

  static Future<LocalCache> init() async {
    if (!_hiveInitialized) {
      await Hive.initFlutter();
      _hiveInitialized = true;
    }
    _box ??= await Hive.openBox<String>(_boxName);
    return LocalCache._();
  }

  String _k(String namespace, String key) => '$namespace::$key';

  Future<void> writeJson(
    String namespace,
    String key,
    Object value,
  ) async {
    final box = _box;
    if (box == null) return;
    await box.put(_k(namespace, key), json.encode(value));
  }

  dynamic readJson(String namespace, String key) {
    final box = _box;
    if (box == null) return null;
    final raw = box.get(_k(namespace, key));
    if (raw == null) return null;
    try {
      return json.decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear(String namespace) async {
    final box = _box;
    if (box == null) return;
    final keys = box.keys
        .whereType<String>()
        .where((k) => k.startsWith('$namespace::'))
        .toList();
    await box.deleteAll(keys);
  }
}
