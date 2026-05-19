import 'dart:async';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../data/models/stream_event.dart';
import '../../data/models/start_turn_message.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Connection state machine for the unified WebSocket.
enum WsConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  /// Host refused / timed out — backend likely not running; no fast reconnect loop.
  unreachable,
}

/// Manages a DeepTutor WebSocket connection.
///
/// Default `wsUrl` is `/api/v1/ws` (unified) but the same client is used for
/// per-bot (`/api/v1/tutorbot/{id}/ws`) and book (`/api/v1/book/ws`) endpoints.
///
/// Responsibilities:
/// - Connect/disconnect lifecycle
/// - Heartbeat ping every 30s with pong-correlated dead-connection watchdog
/// - Exponential-backoff reconnect (up to 5 attempts)
/// - Turn-level `resume_from { turn_id, seq }` on reconnect when a turn is mid-flight;
///   falls back to session-level `subscribe_session` when only a session is known
/// - Exposes [events], [connectionState], and [currentTurnId] streams
class UnifiedWsClient {
  UnifiedWsClient({
    required this.wsUrl,
    required this.token,
  });

  final String wsUrl;
  final String? token;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _heartbeatTimer;
  Timer? _deadTimer;
  Timer? _reconnectTimer;

  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _deadTimeout = Duration(seconds: 45);

  Duration get _reconnectDelay =>
      Duration(seconds: 1 << _reconnectAttempts.clamp(0, 4));

  String? _lastSessionId;
  String? _lastTurnId;
  int? _lastSeq;
  bool _turnInFlight = false;
  bool _disposed = false;

  final _stateController =
      StreamController<WsConnectionState>.broadcast();
  final _eventController = StreamController<StreamEvent>.broadcast();
  final _turnIdController = StreamController<String?>.broadcast();

  Stream<WsConnectionState> get connectionState => _stateController.stream;
  Stream<StreamEvent> get events => _eventController.stream;
  Stream<String?> get currentTurnId => _turnIdController.stream;

  WsConnectionState _state = WsConnectionState.disconnected;
  WsConnectionState get state => _state;

  String? get latestTurnId => _lastTurnId;
  String? get latestSessionId => _lastSessionId;

  String get _fullUrl {
    final t = token;
    if (t != null && t.isNotEmpty) {
      return '$wsUrl?token=${Uri.encodeComponent(t)}';
    }
    return wsUrl;
  }

  /// When true, a failed initial connect uses slow polling instead of backoff spam.
  bool _hostUnreachable = false;

  Future<void> connect() async {
    if (_disposed) return;
    if (_state == WsConnectionState.connected ||
        _state == WsConnectionState.connecting) {
      return;
    }

    _setState(WsConnectionState.connecting);
    _log.i('UnifiedWsClient: connecting to $wsUrl');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_fullUrl));
      await _channel!.ready;

      _setState(WsConnectionState.connected);
      _reconnectAttempts = 0;
      _hostUnreachable = false;

      _sub = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _startHeartbeat();
      _resetDeadTimer();
      _resumeIfNeeded();
    } catch (e) {
      _log.e('UnifiedWsClient: connection error: $e');
      if (_isHostUnreachableError(e)) {
        _hostUnreachable = true;
        _setState(WsConnectionState.unreachable);
        _scheduleUnreachableRetry();
      } else {
        _setState(WsConnectionState.disconnected);
        _scheduleReconnect();
      }
    }
  }

  bool _isHostUnreachableError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('failed to connect') ||
        msg.contains('connection refused') ||
        msg.contains('connection timed out') ||
        msg.contains('network is unreachable') ||
        msg.contains('xhr error') ||
        msg.contains('connection errored');
  }

  void _scheduleUnreachableRetry() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 15), () {
      if (_disposed || _state == WsConnectionState.connected) return;
      _reconnectAttempts = 0;
      connect();
    });
  }

  /// Call when the HTTP health probe succeeds so WS retries immediately.
  void retryAfterBackendUp() {
    if (_disposed) return;
    _hostUnreachable = false;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    if (_state != WsConnectionState.connected) {
      connect();
    }
  }

  void _resumeIfNeeded() {
    if (_turnInFlight && _lastTurnId != null && _lastTurnId!.isNotEmpty) {
      _sendRaw({
        'type': 'resume_from',
        'turn_id': _lastTurnId,
        if (_lastSeq != null) 'seq': _lastSeq,
      });
      return;
    }
    if (_lastSessionId != null && _lastSessionId!.isNotEmpty) {
      _sendRaw({
        'type': 'subscribe_session',
        'session_id': _lastSessionId,
        if (_lastSeq != null) 'after_seq': _lastSeq,
      });
    }
  }

  void _onMessage(dynamic raw) {
    _resetDeadTimer();
    try {
      final map = json.decode(raw as String) as Map<String, dynamic>;
      final event = StreamEvent.fromJson(map);
      if (event.seq != null) _lastSeq = event.seq;
      if (event.sessionId != null && event.sessionId!.isNotEmpty) {
        _lastSessionId = event.sessionId;
      }
      if (event.turnId != null && event.turnId!.isNotEmpty) {
        if (_lastTurnId != event.turnId) {
          _lastTurnId = event.turnId;
          _turnIdController.add(_lastTurnId);
        }
      }
      switch (event.type) {
        case StreamEventType.stageStart:
        case StreamEventType.content:
        case StreamEventType.thinking:
        case StreamEventType.toolCall:
          _turnInFlight = true;
          break;
        case StreamEventType.done:
        case StreamEventType.error:
          _turnInFlight = false;
          break;
        default:
          break;
      }
      _eventController.add(event);
    } catch (e) {
      _log.w('UnifiedWsClient: failed to parse event: $e');
    }
  }

  void _onError(Object error) {
    _log.e('UnifiedWsClient: stream error: $error');
    _setState(WsConnectionState.reconnecting);
    _cleanup();
    _scheduleReconnect();
  }

  void _onDone() {
    _log.w('UnifiedWsClient: connection closed');
    if (_state != WsConnectionState.disconnected) {
      _setState(WsConnectionState.reconnecting);
      _cleanup();
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    if (_hostUnreachable) {
      _scheduleUnreachableRetry();
      return;
    }
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _log.e('UnifiedWsClient: max reconnect attempts reached');
      _setState(WsConnectionState.unreachable);
      _scheduleUnreachableRetry();
      return;
    }

    final delay = _reconnectDelay;
    _log.i(
        'UnifiedWsClient: reconnecting in ${delay.inSeconds}s (attempt ${_reconnectAttempts + 1})');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      connect();
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _sendRaw({'type': 'ping'});
    });
  }

  /// (Re)arm the dead-connection watchdog. Any frame from the server (pong or
  /// data) resets it; if it ever fires, we tear down and reconnect.
  void _resetDeadTimer() {
    _deadTimer?.cancel();
    _deadTimer = Timer(_deadTimeout, () {
      _log.w('UnifiedWsClient: dead connection detected (no frames in '
          '${_deadTimeout.inSeconds}s)');
      _setState(WsConnectionState.reconnecting);
      _cleanup();
      _scheduleReconnect();
    });
  }

  // ── Public message senders ─────────────────────────────────────────────────

  void sendStartTurn(StartTurnMessage message) {
    final payload = Map<String, dynamic>.from(message.toJson());
    final sid = payload['session_id'] as String?;
    if (sid != null && sid.isNotEmpty) _lastSessionId = sid;
    _lastTurnId = null;
    _turnIdController.add(null);
    _turnInFlight = true;
    _sendRaw(payload);
  }

  void sendCancelTurn(String turnId) {
    if (turnId.isEmpty) return;
    _sendRaw({'type': 'cancel_turn', 'turn_id': turnId});
  }

  /// Regenerate the last assistant message for [sessionId].
  ///
  /// `overrides` accepts the server-supported keys: `capability`, `tools`,
  /// `knowledge_bases`, `language`, `config`, `notebook_references`,
  /// `history_references`.
  void sendRegenerate({
    required String sessionId,
    Map<String, dynamic>? overrides,
  }) {
    if (sessionId.isEmpty) return;
    final payload = <String, dynamic>{
      'type': 'regenerate',
      'session_id': sessionId,
    };
    if (overrides != null && overrides.isNotEmpty) {
      payload['overrides'] = overrides;
    }
    _turnInFlight = true;
    _sendRaw(payload);
  }

  void sendSubscribeSession(String sessionId, {int? afterSeq}) {
    if (sessionId.isEmpty) return;
    _lastSessionId = sessionId;
    _sendRaw({
      'type': 'subscribe_session',
      'session_id': sessionId,
      if (afterSeq != null) 'after_seq': afterSeq,
    });
  }

  void sendSubscribeTurn(String turnId, {int? afterSeq}) {
    if (turnId.isEmpty) return;
    _lastTurnId = turnId;
    _sendRaw({
      'type': 'subscribe_turn',
      'turn_id': turnId,
      if (afterSeq != null) 'after_seq': afterSeq,
    });
  }

  void sendUnsubscribe({String? turnId, String? sessionId}) {
    final payload = <String, dynamic>{'type': 'unsubscribe'};
    if (turnId != null && turnId.isNotEmpty) payload['turn_id'] = turnId;
    if (sessionId != null && sessionId.isNotEmpty) {
      payload['session_id'] = sessionId;
    }
    _sendRaw(payload);
  }

  void _sendRaw(Map<String, dynamic> payload) {
    if (_state != WsConnectionState.connected) return;
    try {
      _channel?.sink.add(json.encode(payload));
    } catch (e) {
      _log.e('UnifiedWsClient: send error: $e');
    }
  }

  void _setState(WsConnectionState state) {
    _state = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void _cleanup() {
    _heartbeatTimer?.cancel();
    _deadTimer?.cancel();
    _sub?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _sub = null;
    _channel = null;
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _setState(WsConnectionState.disconnected);
    _cleanup();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _reconnectTimer?.cancel();
    _cleanup();
    if (!_stateController.isClosed) _stateController.close();
    if (!_eventController.isClosed) _eventController.close();
    if (!_turnIdController.isClosed) _turnIdController.close();
  }
}
