import 'dart:async';
import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Client for `/api/v1/book/ws` — block regeneration and compile events.
class BookWsClient {
  BookWsClient({
    required this.wsUrl,
    this.token,
  });

  final String wsUrl;
  final String? token;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  bool _disposed = false;

  final _events = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get isConnected => _channel != null;

  String get _fullUrl {
    final t = token;
    if (t != null && t.isNotEmpty) {
      final sep = wsUrl.contains('?') ? '&' : '?';
      return '$wsUrl${sep}token=${Uri.encodeComponent(t)}';
    }
    return wsUrl;
  }

  Future<void> connect() async {
    if (_disposed) return;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_fullUrl));
      await _channel!.ready;
      _sub = _channel!.stream.listen(
        _onMessage,
        onError: (e) => _log.w('BookWsClient error: $e'),
        onDone: () {
          _channel = null;
          _sub = null;
        },
      );
      _log.i('BookWsClient connected');
    } catch (e) {
      _log.e('BookWsClient connect failed: $e');
      rethrow;
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final map = json.decode(raw as String) as Map<String, dynamic>;
      if (!_events.isClosed) _events.add(map);
    } catch (e) {
      _log.w('BookWsClient parse error: $e');
    }
  }

  void sendRegenerateBlock({
    required String bookId,
    required String pageId,
    required String blockId,
    Map<String, dynamic>? paramsOverride,
  }) {
    _send({
      'type': 'regenerate_block',
      'book_id': bookId,
      'page_id': pageId,
      'block_id': blockId,
      if (paramsOverride != null) 'params_override': paramsOverride,
    });
  }

  void _send(Map<String, dynamic> payload) {
    _channel?.sink.add(json.encode(payload));
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _sub?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    if (!_events.isClosed) _events.close();
  }
}
