import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/ws_client.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/animated_entrance.dart';
import '../../../core/widgets/chat_typing_indicator.dart';
import '../../../core/widgets/subpage_scaffold.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/start_turn_message.dart';
import '../../../data/models/stream_event.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/widgets/assistant_message.dart';

/// Dedicated WS chat against `/api/v1/tutorbot/{id}/ws`.
///
/// Reuses [UnifiedWsClient] with a different URL since the wire protocol
/// matches (start_turn + StreamEvent frames).
class TutorBotChatScreen extends ConsumerStatefulWidget {
  const TutorBotChatScreen({super.key, required this.botId});

  final String botId;

  @override
  ConsumerState<TutorBotChatScreen> createState() =>
      _TutorBotChatScreenState();
}

class _TutorBotChatScreenState extends ConsumerState<TutorBotChatScreen> {
  UnifiedWsClient? _ws;
  final List<ChatMessage> _messages = [];
  final _ctrl = TextEditingController();
  final _scrollController = ScrollController();
  String? _streamingId;
  bool _streaming = false;
  String? _stage;

  @override
  void initState() {
    super.initState();
    _initWs();
  }

  void _initWs() {
    final config = ref.read(appConfigProvider);
    final token = ref.read(authTokenProvider);
    _ws = UnifiedWsClient(
      wsUrl: '${config.wsBase}/api/v1/tutorbot/${widget.botId}/ws',
      token: token,
    );
    _ws!.events.listen(_onEvent);
    _ws!.connect();
  }

  void _onEvent(StreamEvent e) {
    switch (e.type) {
      case StreamEventType.stageStart:
        setState(() => _stage = e.stage);
      case StreamEventType.content:
      case StreamEventType.thinking:
        setState(() {
          _scrollToBottom();
          if (_streamingId == null) {
            final msg = ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              role: 'assistant',
              content: e.content,
              isStreaming: true,
            );
            _streamingId = msg.id;
            _messages.add(msg);
          } else {
            final idx =
                _messages.indexWhere((m) => m.id == _streamingId);
            if (idx != -1) _messages[idx].content += e.content;
          }
        });
      case StreamEventType.done:
      case StreamEventType.error:
        setState(() {
          final idx =
              _messages.indexWhere((m) => m.id == _streamingId);
          if (idx != -1) _messages[idx].isStreaming = false;
          _streamingId = null;
          _streaming = false;
          _stage = null;
        });
      default:
        break;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppAnimations.fast,
          curve: AppAnimations.enter,
        );
      }
    });
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _ws == null) return;
    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'user',
        content: text,
      ));
      _streaming = true;
    });
    _ws!.sendStartTurn(StartTurnMessage(content: text));
    _ctrl.clear();
  }

  @override
  void dispose() {
    _ws?.dispose();
    _ctrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SubpageScaffold(
      title: 'TutorBot',
      body: Column(
        children: [
          if (_stage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              color: AppColors.accent.withOpacity(0.08),
              child:
                  Text(_stage!, style: const TextStyle(color: AppColors.accent)),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                final isUser = m.isUser;
                return AnimatedEntrance(
                  slideOffset: 12,
                  duration: AppAnimations.fast,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.sizeOf(context).width * 0.85,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: isUser
                              ? AppColors.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(
                              AppSpacing.radiusL),
                        ),
                        child: isUser
                            ? Text(m.content,
                                style: const TextStyle(color: Colors.white))
                            : (m.isStreaming && m.content.isEmpty)
                                ? const ChatTypingIndicator()
                                : AssistantMessageBody(
                                    content: m.content,
                                    isStreaming: m.isStreaming,
                                  ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    enabled: !_streaming,
                    decoration: const InputDecoration(
                      hintText: 'Talk to your bot…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filled(
                  onPressed: _streaming ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
