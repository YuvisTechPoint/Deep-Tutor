import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Key used for the Hive box that persists pending practice submits.
const _kBoxName = 'pending_submits';

bool _hiveInitialized = false;

/// A pending quiz submission persisted to Hive for offline retry.
class PendingSubmit {
  const PendingSubmit({
    required this.id,
    required this.quizId,
    required this.answers,
    required this.createdAt,
  });

  final String id;
  final String quizId;

  /// JSON-encoded list of `{ "question_id": ..., "answer_index": ... }` maps.
  final String answers;
  final DateTime createdAt;

  factory PendingSubmit.fromMap(Map<dynamic, dynamic> m) => PendingSubmit(
        id: m['id'] as String,
        quizId: m['quiz_id'] as String,
        answers: m['answers'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'quiz_id': quizId,
        'answers': answers,
        'created_at': createdAt.toIso8601String(),
      };

  List<Map<String, dynamic>> get answersDecoded =>
      (jsonDecode(answers) as List)
          .cast<Map<String, dynamic>>();
}

/// Manages persistence and background retry of offline practice submissions.
///
/// Usage:
/// ```dart
/// final queue = HiveOfflineQueue();
/// await queue.init();
///
/// // Enqueue when offline:
/// await queue.enqueue(quizId: 'abc', answers: [...]);
///
/// // On connectivity restore, flush:
/// queue.startFlushListener(onFlush: (pending) async {
///   await practiceRepository.submitQuiz(pending.quizId, pending.answersDecoded);
/// });
/// ```
class HiveOfflineQueue {
  late Box<Map> _box;
  StreamSubscription? _connectivitySub;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    if (!_hiveInitialized) {
      await Hive.initFlutter();
      _hiveInitialized = true;
    }
    _box = await Hive.openBox<Map>(_kBoxName);
    _initialized = true;
    _log.i('HiveOfflineQueue: initialized (${_box.length} pending)');
  }

  /// Add a quiz submit to the offline queue.
  Future<void> enqueue({
    required String quizId,
    required List<Map<String, dynamic>> answers,
  }) async {
    assert(_initialized, 'Call init() before enqueue()');
    final id = '${quizId}_${DateTime.now().millisecondsSinceEpoch}';
    final pending = PendingSubmit(
      id: id,
      quizId: quizId,
      answers: jsonEncode(answers),
      createdAt: DateTime.now(),
    );
    await _box.put(id, pending.toMap());
    _log.i('HiveOfflineQueue: queued $id');
  }

  /// Remove a successfully flushed item.
  Future<void> remove(String id) async {
    await _box.delete(id);
    _log.i('HiveOfflineQueue: removed $id');
  }

  /// All pending submissions.
  List<PendingSubmit> get pending => _box.values
      .map((m) => PendingSubmit.fromMap(m))
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  int get pendingCount => _box.length;

  /// Listen for connectivity restoration and attempt to flush each pending item.
  ///
  /// [onFlush] receives one [PendingSubmit] at a time. If it completes without
  /// throwing, the item is removed. If it throws (e.g. 410 quiz expired),
  /// the item is also removed (stale quiz — can't retry).
  void startFlushListener({
    required Future<void> Function(PendingSubmit pending) onFlush,
  }) {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((results) async {
      final hasConnection = results
          .any((r) => r != ConnectivityResult.none);
      if (hasConnection && pending.isNotEmpty) {
        await _flush(onFlush: onFlush);
      }
    });

    // Also attempt immediate flush in case we're already online.
    Connectivity().checkConnectivity().then((results) async {
      final hasConnection = results
          .any((r) => r != ConnectivityResult.none);
      if (hasConnection && pending.isNotEmpty) {
        await _flush(onFlush: onFlush);
      }
    });
  }

  Future<void> _flush({
    required Future<void> Function(PendingSubmit) onFlush,
  }) async {
    final items = pending;
    _log.i('HiveOfflineQueue: flushing ${items.length} item(s)');
    for (final item in items) {
      try {
        await onFlush(item);
        await remove(item.id);
        _log.i('HiveOfflineQueue: flushed ${item.id}');
      } catch (e) {
        _log.w('HiveOfflineQueue: flush failed for ${item.id}: $e');
        // 410 = quiz expired → remove anyway (unretryable)
        if (e.toString().contains('410')) {
          await remove(item.id);
          _log.w('HiveOfflineQueue: dropped expired ${item.id}');
        }
        // Other errors: keep in queue for next connectivity event
      }
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}
