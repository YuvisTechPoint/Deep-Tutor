import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_errors.dart';
import '../../../core/network/global_chat_ws.dart';
import '../../../core/network/ws_client.dart';
import '../../../services/realtime_sync.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/chat_session.dart';
import '../../../data/models/start_turn_message.dart';
import '../../../data/models/stream_event.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../auth/providers/auth_provider.dart';

// ── Composer overrides ───────────────────────────────────────────────────────

/// Per-turn composer overrides chosen by the user (capability, tools, KBs, …).
class ChatComposerOverrides {
  const ChatComposerOverrides({
    this.capability = 'chat',
    this.tools = const [],
    this.knowledgeBases = const [],
    this.skills = const [],
    this.language,
    this.config = const {},
    this.llmProvider,
    this.llmModel,
    this.attachments = const [],
  });

  final String capability;
  final List<String> tools;
  final List<String> knowledgeBases;
  final List<String> skills;
  final String? language;
  final Map<String, dynamic> config;
  final String? llmProvider;
  final String? llmModel;
  final List<ChatAttachment> attachments;

  ChatComposerOverrides copyWith({
    String? capability,
    List<String>? tools,
    List<String>? knowledgeBases,
    List<String>? skills,
    String? language,
    Map<String, dynamic>? config,
    String? llmProvider,
    String? llmModel,
    List<ChatAttachment>? attachments,
  }) =>
      ChatComposerOverrides(
        capability: capability ?? this.capability,
        tools: tools ?? this.tools,
        knowledgeBases: knowledgeBases ?? this.knowledgeBases,
        skills: skills ?? this.skills,
        language: language ?? this.language,
        config: config ?? this.config,
        llmProvider: llmProvider ?? this.llmProvider,
        llmModel: llmModel ?? this.llmModel,
        attachments: attachments ?? this.attachments,
      );

  /// Serialises the user-controlled overrides into the form the server expects
  /// for `regenerate.overrides` and as fields on `start_turn`.
  Map<String, dynamic> toOverridesMap() {
    final map = <String, dynamic>{};
    if (capability.isNotEmpty && capability != 'chat') {
      map['capability'] = capability;
    }
    if (tools.isNotEmpty) map['tools'] = tools;
    if (knowledgeBases.isNotEmpty) map['knowledge_bases'] = knowledgeBases;
    if (language != null && language!.isNotEmpty) map['language'] = language;
    if (config.isNotEmpty) map['config'] = config;
    return map;
  }
}

final composerOverridesProvider =
    StateProvider.autoDispose<ChatComposerOverrides>(
  (ref) => const ChatComposerOverrides(),
);

// ── Chat session list ─────────────────────────────────────────────────────────

final chatRepositoryProvider = Provider(
  (ref) => ChatRepository(dio: ref.watch(dioProvider)),
);

final chatSessionsProvider = AsyncNotifierProvider.autoDispose<
    ChatSessionsNotifier, List<ChatSession>>(ChatSessionsNotifier.new);

/// Session list with optimistic delete and refresh.
class ChatSessionsNotifier extends AutoDisposeAsyncNotifier<List<ChatSession>> {
  @override
  Future<List<ChatSession>> build() => _load();

  Future<List<ChatSession>> _load() async {
    try {
      return await ref.read(chatRepositoryProvider).getSessions();
    } on DioException catch (e) {
      if (isAuthDioError(e) && ref.read(demoModeProvider)) {
        return const [];
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  /// Optimistic delete; returns false if API failed (state restored).
  Future<bool> deleteSession(String sessionId) async {
    final previous = state.valueOrNull;
    if (previous == null) return false;

    state = AsyncData(
      previous.where((s) => s.id != sessionId).toList(),
    );

    try {
      await ref.read(chatRepositoryProvider).deleteSession(sessionId);
      final active = ref.read(chatNotifierProvider.notifier).sessionId;
      if (active == sessionId) {
        ref.read(chatNotifierProvider.notifier).clearSession();
      }
      return true;
    } catch (_) {
      state = AsyncData(previous);
      return false;
    }
  }
}

// ── Active chat state ─────────────────────────────────────────────────────────

sealed class ChatScreenState {
  const ChatScreenState();
}

class ChatIdle extends ChatScreenState {
  const ChatIdle({this.messages = const [], this.isLoadingHistory = false});
  final List<ChatMessage> messages;
  final bool isLoadingHistory;
}

class ChatStreaming extends ChatScreenState {
  const ChatStreaming({required this.messages, this.stage, this.stages = const []});
  final List<ChatMessage> messages;
  final String? stage;

  /// Ordered timeline of stages observed in the current turn.
  final List<String> stages;
}

class ChatError extends ChatScreenState {
  const ChatError({required this.messages, required this.error});
  final List<ChatMessage> messages;
  final String error;
}

// ── Chat notifier ─────────────────────────────────────────────────────────────

class ChatNotifier extends StateNotifier<ChatScreenState> {
  ChatNotifier(
    this._repo, {
    this.onTurnFinished,
  }) : super(const ChatIdle());

  final ChatRepository _repo;
  final void Function()? onTurnFinished;

  UnifiedWsClient? _wsClient;
  StreamSubscription<StreamEvent>? _eventSub;
  StreamSubscription<WsConnectionState>? _stateSub;
  StreamSubscription<String?>? _turnIdSub;

  String? _sessionId;
  String? _pendingSubscribeSessionId;
  String? _streamingMessageId;
  String? _currentTurnId;
  final List<String> _stageTimeline = [];
  final _uuid = const Uuid();

  String? get currentTurnId => _currentTurnId;
  String? get sessionId => _sessionId;

  List<ChatMessage> get _messages =>
      switch (state) {
        ChatIdle(:final messages) => messages,
        ChatStreaming(:final messages) => messages,
        ChatError(:final messages) => messages,
      };

  /// Subscribes to the app-wide [UnifiedWsClient] (does not own/dispose it).
  void attachToWs(UnifiedWsClient client) {
    if (_wsClient == client && _eventSub != null) return;
    detachFromWs();
    _wsClient = client;
    _wsState = client.state;

    _eventSub = client.events.listen(_onEvent);
    _stateSub = client.connectionState.listen(_onConnectionState);
    _turnIdSub = client.currentTurnId.listen((id) {
      _currentTurnId = id;
    });

    _trySubscribeSession();
  }

  void detachFromWs() {
    _eventSub?.cancel();
    _stateSub?.cancel();
    _turnIdSub?.cancel();
    _eventSub = null;
    _stateSub = null;
    _turnIdSub = null;
    _wsClient = null;
  }

  WsConnectionState _wsState = WsConnectionState.disconnected;
  WsConnectionState get wsConnectionState => _wsState;

  void _onConnectionState(WsConnectionState connState) {
    _wsState = connState;
    if (!_wsStateController.isClosed) _wsStateController.add(connState);
    if (connState == WsConnectionState.connected) {
      _trySubscribeSession();
    }
  }

  final _wsStateController =
      StreamController<WsConnectionState>.broadcast();
  Stream<WsConnectionState> get wsStateStream => _wsStateController.stream;

  void _onEvent(StreamEvent event) {
    if (event.turnId != null && event.turnId!.isNotEmpty) {
      _currentTurnId = event.turnId;
    }

    switch (event.type) {
      case StreamEventType.session:
        if (event.sessionId != null) {
          _sessionId = event.sessionId;
          setSessionId(event.sessionId);
        }

      case StreamEventType.stageStart:
        if (event.stage.isNotEmpty && !_stageTimeline.contains(event.stage)) {
          _stageTimeline.add(event.stage);
        }
        state = ChatStreaming(
          messages: List<ChatMessage>.from(_messages),
          stage: event.stage,
          stages: List<String>.from(_stageTimeline),
        );

      case StreamEventType.thinking:
      case StreamEventType.content:
        _appendOrCreateAssistantMessage(event.content);

      case StreamEventType.toolCall:
        _appendToolCall(event.metadata);

      case StreamEventType.sources:
        _attachSources(event.metadata);

      case StreamEventType.error:
        state = ChatError(
          messages: List<ChatMessage>.from(_messages),
          error: event.content.isEmpty
              ? 'Streaming error'
              : event.content,
        );
        onTurnFinished?.call();

      case StreamEventType.done:
        final msgs = List<ChatMessage>.from(_messages);
        final idx = msgs.indexWhere((m) => m.id == _streamingMessageId);
        if (idx != -1) msgs[idx].isStreaming = false;
        _streamingMessageId = null;
        _currentTurnId = null;
        _stageTimeline.clear();
        state = ChatIdle(messages: msgs);
        onTurnFinished?.call();

      default:
        break;
    }
  }

  void _appendOrCreateAssistantMessage(String chunk) {
    if (chunk.isEmpty) return;
    final msgs = List<ChatMessage>.from(_messages);

    if (_streamingMessageId != null) {
      final idx = msgs.indexWhere((m) => m.id == _streamingMessageId);
      if (idx != -1) {
        msgs[idx].content += chunk;
        state = ChatStreaming(
          messages: msgs,
          stage: _currentStage,
          stages: List<String>.from(_stageTimeline),
        );
        return;
      }
    }

    final newMsg = ChatMessage(
      id: _streamingMessageId = _uuid.v4(),
      role: 'assistant',
      content: chunk,
      isStreaming: true,
      sources: <Map<String, dynamic>>[],
      toolCalls: <Map<String, dynamic>>[],
      timestamp: DateTime.now(),
    );
    msgs.add(newMsg);
    state = ChatStreaming(
      messages: msgs,
      stage: _currentStage,
      stages: List<String>.from(_stageTimeline),
    );
  }

  void _appendToolCall(Map<String, dynamic> meta) {
    final msgs = List<ChatMessage>.from(_messages);
    if (_streamingMessageId != null) {
      final idx = msgs.indexWhere((m) => m.id == _streamingMessageId);
      if (idx != -1) {
        msgs[idx].toolCalls = [...msgs[idx].toolCalls, meta];
      }
    }
    state = ChatStreaming(
      messages: msgs,
      stage: _currentStage,
      stages: List<String>.from(_stageTimeline),
    );
  }

  void _attachSources(Map<String, dynamic> meta) {
    final msgs = List<ChatMessage>.from(_messages);
    if (_streamingMessageId != null) {
      final idx = msgs.indexWhere((m) => m.id == _streamingMessageId);
      if (idx != -1) {
        final sourcesRaw = meta['sources'];
        if (sourcesRaw is List) {
          final added = <Map<String, dynamic>>[];
          for (final s in sourcesRaw) {
            if (s is Map<String, dynamic>) added.add(s);
          }
          msgs[idx].sources = [...msgs[idx].sources, ...added];
        } else {
          msgs[idx].sources = [...msgs[idx].sources, meta];
        }
      }
    }
    state = ChatStreaming(
      messages: msgs,
      stage: _currentStage,
      stages: List<String>.from(_stageTimeline),
    );
  }

  String? get _currentStage => switch (state) {
        ChatStreaming(:final stage) => stage,
        _ => null,
      };

  /// Send a new turn. [overrides] supplies the composer config (capability,
  /// tools, KBs, attachments, model, language, capability config).
  void send({
    required String content,
    ChatComposerOverrides? overrides,
    String? capabilityFallback,
    List<String>? toolsFallback,
  }) {
    if (content.trim().isEmpty) return;

    final o = overrides ?? const ChatComposerOverrides();

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: 'user',
      content: content.trim(),
      timestamp: DateTime.now(),
    );

    final msgs = [..._messages, userMsg];
    _stageTimeline.clear();
    state = ChatStreaming(messages: msgs, stages: const []);

    final hasOverrides = overrides != null;
    final capability = (hasOverrides ? o.capability : capabilityFallback) ??
        capabilityFallback ??
        'chat';
    final tools = hasOverrides
        ? (o.tools.isEmpty ? null : o.tools)
        : toolsFallback;
    final kbs = hasOverrides && o.knowledgeBases.isNotEmpty
        ? o.knowledgeBases
        : null;
    final attachments =
        hasOverrides && o.attachments.isNotEmpty ? o.attachments : null;
    final config = hasOverrides && o.config.isNotEmpty ? o.config : null;
    final language = hasOverrides ? o.language : null;
    LlmSelection? llm;
    if (hasOverrides && (o.llmModel != null || o.llmProvider != null)) {
      llm = LlmSelection(provider: o.llmProvider, model: o.llmModel);
    }

    final ws = _wsClient;
    if (ws == null) {
      state = ChatError(
        messages: _messages,
        error: 'Not connected to chat server',
      );
      return;
    }

    ws.sendStartTurn(
      StartTurnMessage(
        content: content.trim(),
        sessionId: _sessionId,
        tools: tools,
        capability: capability,
        knowledgeBases: kbs,
        attachments: attachments,
        config: config,
        language: language,
        llmSelection: llm,
      ),
    );
  }

  /// Cancel the in-flight turn. No-op when nothing is streaming.
  void cancelTurn() {
    final turnId = _currentTurnId;
    if (turnId != null && turnId.isNotEmpty) {
      _wsClient?.sendCancelTurn(turnId);
    }

    if (_streamingMessageId != null) {
      final msgs = List<ChatMessage>.from(_messages);
      final idx = msgs.indexWhere((m) => m.id == _streamingMessageId);
      if (idx != -1) {
        msgs[idx].isStreaming = false;
        msgs[idx].content = msgs[idx].content.isEmpty
            ? '_(cancelled)_'
            : '${msgs[idx].content}\n\n_(cancelled)_';
      }
      _streamingMessageId = null;
      state = ChatIdle(messages: msgs);
    }
    _currentTurnId = null;
    _stageTimeline.clear();
  }

  /// Regenerate the last assistant message for the active session.
  void regenerate({ChatComposerOverrides? overrides}) {
    final sid = _sessionId;
    if (sid == null || sid.isEmpty) return;
    _stageTimeline.clear();
    _wsClient?.sendRegenerate(
      sessionId: sid,
      overrides: overrides?.toOverridesMap(),
    );
  }

  void setSessionId(String? sessionId) {
    _sessionId = sessionId;
    if (sessionId == null || sessionId.isEmpty) return;
    _pendingSubscribeSessionId = sessionId;
    _trySubscribeSession();
  }

  void _trySubscribeSession() {
    final id = _pendingSubscribeSessionId;
    if (id == null || id.isEmpty) return;
    if (_wsState != WsConnectionState.connected) return;
    _wsClient?.sendSubscribeSession(id);
    _pendingSubscribeSessionId = null;
  }

  Future<void> loadHistory(String sessionId) async {
    state = ChatIdle(messages: _messages, isLoadingHistory: true);
    try {
      final messages = await _repo.getSessionMessages(sessionId);
      state = ChatIdle(messages: messages);
    } catch (_) {
      state = ChatIdle(messages: _messages);
    }
  }

  void clearSession() {
    _sessionId = null;
    _pendingSubscribeSessionId = null;
    _streamingMessageId = null;
    _currentTurnId = null;
    _stageTimeline.clear();
    state = const ChatIdle();
  }

  @override
  void dispose() {
    detachFromWs();
    _wsStateController.close();
    super.dispose();
  }
}

final chatNotifierProvider =
    StateNotifierProvider.autoDispose<ChatNotifier, ChatScreenState>((ref) {
  final ws = ref.watch(globalUnifiedWsProvider);
  final notifier = ChatNotifier(
    ref.watch(chatRepositoryProvider),
    onTurnFinished: () => refreshAppLiveData(ref.container),
  );
  if (ws != null) {
    notifier.attachToWs(ws);
  }
  ref.onDispose(notifier.detachFromWs);
  return notifier;
});

/// @deprecated Use [globalWsConnectionStateProvider].
final wsConnectionStateProvider = globalWsConnectionStateProvider;
