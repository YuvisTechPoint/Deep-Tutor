import 'dart:async';
import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Lightweight client for `GET /api/v1/career/ws` career & gamification pushes.
class CareerWsClient {
  CareerWsClient({
    required this.wsUrl,
    required this.token,
    this.sessionId = 'default',
  });

  final String wsUrl;
  final String? token;
  final String sessionId;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _heartbeat;
  bool _disposed = false;

  final _events = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _events.stream;

  String get _fullUrl {
    final base = wsUrl.contains('?')
        ? '$wsUrl&session_id=${Uri.encodeComponent(sessionId)}'
        : '$wsUrl?session_id=${Uri.encodeComponent(sessionId)}';
    final t = token;
    if (t != null && t.isNotEmpty) {
      return '$base&token=${Uri.encodeComponent(t)}';
    }
    return base;
  }

  Future<void> connect() async {
    if (_disposed) return;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_fullUrl));
      await _channel!.ready;
      _sub = _channel!.stream.listen(
        _onMessage,
        onError: (e) => _log.w('CareerWsClient error: $e'),
        onDone: () => _log.d('CareerWsClient closed'),
      );
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _send({'type': 'ping'}),
      );
      _log.i('CareerWsClient connected');
    } catch (e) {
      _log.e('CareerWsClient connect failed: $e');
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final map = json.decode(raw as String) as Map<String, dynamic>;
      final type = map['type']?.toString();
      if (type == 'pong') return;
      if (!_events.isClosed) _events.add(map);
    } catch (e) {
      _log.w('CareerWsClient parse error: $e');
    }
  }

  void _send(Map<String, dynamic> payload) {
    try {
      _channel?.sink.add(json.encode(payload));
    } catch (_) {}
  }

  Future<void> disconnect() async {
    _send({'type': 'unsubscribe'});
    _cleanup();
  }

  void _cleanup() {
    _heartbeat?.cancel();
    _sub?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _sub = null;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cleanup();
    if (!_events.isClosed) _events.close();
  }
}
