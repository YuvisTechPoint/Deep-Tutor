import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/layout/responsive.dart';
import '../../../core/network/global_chat_ws.dart';
import '../../../core/network/ws_client.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/feature_identity.dart';
import '../../../core/widgets/animated_entrance.dart';
import '../../../core/widgets/design_system/dt_ai_pulse.dart';
import '../../../core/widgets/design_system/dt_page_shell.dart';
import '../../../core/widgets/chat_typing_indicator.dart';
import '../../../data/models/chat_message.dart';
import '../../settings/providers/safety_providers.dart';
import '../../settings/providers/safety_settings.dart';
import '../providers/chat_provider.dart';
import '../widgets/assistant_message.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/regenerate_sheet.dart';
import '../widgets/sources_footer.dart';
import '../widgets/stage_timeline.dart';
import '../widgets/chat_sessions_pane.dart';
import '../widgets/tool_call_chip.dart';

/// Live chat thread screen using the unified WebSocket.
///
/// Rebuilds incrementally as [ChatStreaming] events arrive.
/// Messages are rendered via [AssistantMessageBody] for rich AI responses.
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, this.sessionId});

  final String? sessionId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(chatNotifierProvider.notifier);
      final id = widget.sessionId;
      if (id != null && id != 'new') {
        notifier.setSessionId(id);
        notifier.loadHistory(id);
      } else {
        notifier.setSessionId(const Uuid().v4());
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _onRegenerate() async {
    final overrides = ref.read(composerOverridesProvider);
    final chosen =
        await showRegenerateSheet(context, current: overrides);
    if (chosen == null) return;
    ref
        .read(composerOverridesProvider.notifier)
        .update((_) => chosen);
    ref.read(chatNotifierProvider.notifier).regenerate(overrides: chosen);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatNotifierProvider);

    final isLoadingHistory =
        chatState is ChatIdle && chatState.isLoadingHistory;

    final messages = switch (chatState) {
      ChatIdle(:final messages) => messages,
      ChatStreaming(:final messages) => messages,
      ChatError(:final messages) => messages,
    };

    final isStreaming = chatState is ChatStreaming;
    final activeStage = isStreaming ? chatState.stage : null;
    final stages = isStreaming ? chatState.stages : const <String>[];
    final error = chatState is ChatError ? chatState.error : null;

    ref.listen(chatNotifierProvider, (_, next) {
      if (next is ChatStreaming) _scrollToBottom();
    });

    final notifier = ref.read(chatNotifierProvider.notifier);
    final hasSession = notifier.sessionId != null;
    final canRegenerate = !isStreaming && hasSession && messages.isNotEmpty;

    final sessionId = widget.sessionId != null && widget.sessionId != 'new'
        ? widget.sessionId
        : notifier.sessionId;

    final threadBody = Column(
      children: [
        if (stages.isNotEmpty)
          StageTimeline(stages: stages, activeStage: activeStage),
        if (error != null) _ErrorBanner(message: error),
        Expanded(
          child: isLoadingHistory
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty
                  ? const _EmptyChat()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            ResponsiveLayout.pageHorizontalPadding(context),
                        vertical: AppSpacing.sm,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (_, i) => Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth:
                                ResponsiveLayout.readerMaxWidth(context),
                          ),
                          child: _MessageBubble(message: messages[i]),
                        ),
                      ),
                    ),
        ),
        ChatInputBar(
          enabled: !isStreaming,
          onSend: (text, {required overrides}) async {
            if (ref.read(safetyEnabledProvider)) {
              final verdict =
                  await ref.read(safetyRepositoryProvider).moderate(text);
              if (verdict.blocked) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Blocked by safety filter: '
                        '${verdict.reason ?? "content not allowed"}',
                      ),
                    ),
                  );
                }
                return;
              }
            }
            notifier.send(content: text, overrides: overrides);
          },
        ),
      ],
    );

    final useDualPane = ResponsiveLayout.useChatDualPane(context);

    return DtPageShell(
          title: 'AI Chat',
          featureId: FeatureId.chat,
          actions: [
            if (isStreaming)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: DtAiPulse(label: 'LIVE', size: 6),
              ),
            const _WsConnectionIndicator(),
            if (canRegenerate)
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Regenerate',
                onPressed: _onRegenerate,
              ),
            if (isStreaming)
              IconButton(
                icon: const Icon(Icons.stop_circle_outlined),
                tooltip: 'Cancel',
                onPressed: () => notifier.cancelTurn(),
              ),
            IconButton(
              icon: const Icon(Icons.add_comment_outlined),
              tooltip: 'New session',
              onPressed: () => notifier.clearSession(),
            ),
          ],
          body: useDualPane
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ChatSessionsPane(activeSessionId: sessionId),
                    Expanded(child: threadBody),
                  ],
                )
              : threadBody,
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = message.isUser;

    return AnimatedEntrance(
      slideOffset: 12,
      duration: AppAnimations.fast,
      child: Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _Avatar(isUser: false),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.primary
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(AppSpacing.radiusL),
                      topRight: const Radius.circular(AppSpacing.radiusL),
                      bottomLeft: Radius.circular(
                          isUser ? AppSpacing.radiusL : AppSpacing.radiusXS),
                      bottomRight: Radius.circular(
                          isUser ? AppSpacing.radiusXS : AppSpacing.radiusL),
                    ),
                  ),
                  child: isUser
                      ? SelectableText(
                          message.content,
                          style: const TextStyle(color: Colors.white),
                        )
                      : (message.isStreaming && message.content.isEmpty)
                          ? const Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: AppSpacing.xs),
                              child: ChatTypingIndicator(),
                            )
                          : AssistantMessageBody(
                              content: message.content,
                              isStreaming: message.isStreaming,
                            ),
                ),
                if (message.toolCalls.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: message.toolCalls
                          .map((t) => ToolCallChip(toolCall: t))
                          .toList(),
                    ),
                  ),
                if (message.sources.isNotEmpty)
                  SourcesFooter(sources: message.sources),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: AppSpacing.sm),
            _Avatar(isUser: true),
          ],
        ],
      ),
    ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.isUser});
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: isUser
          ? AppColors.primary.withOpacity(0.2)
          : AppColors.accent.withOpacity(0.2),
      child: Icon(
        isUser ? Icons.person : Icons.school_rounded,
        size: 18,
        color: isUser ? AppColors.primary : AppColors.accent,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.error.withOpacity(0.08),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 16),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_rounded,
            size: 72,
            color: AppColors.primary.withOpacity(0.3),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Ask me anything!',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text('Your AI tutor is ready to help'),
        ],
      ),
    );
  }
}

// ── WS connection status indicator ───────────────────────────────────────────

/// Small dot in the AppBar title showing the real-time connection state.
///
/// When connected it pulses with a ring animation to signal live data.
class _WsConnectionIndicator extends ConsumerStatefulWidget {
  const _WsConnectionIndicator();

  @override
  ConsumerState<_WsConnectionIndicator> createState() =>
      _WsConnectionIndicatorState();
}

class _WsConnectionIndicatorState
    extends ConsumerState<_WsConnectionIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _scale = Tween<double>(begin: 1.0, end: 2.6).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connAsync = ref.watch(globalWsConnectionStateProvider);
    final connState =
        connAsync.valueOrNull ?? WsConnectionState.disconnected;
    final isConnected = connState == WsConnectionState.connected;

    final (color, tooltip) = switch (connState) {
      WsConnectionState.connected => (AppColors.success, 'Connected'),
      WsConnectionState.connecting => (AppColors.warning, 'Connecting…'),
      WsConnectionState.reconnecting =>
        (AppColors.warning, 'Reconnecting…'),
      WsConnectionState.unreachable => (
          AppColors.error,
          'API unreachable — start the backend on port 8001',
        ),
      WsConnectionState.disconnected =>
        (AppColors.grey400, 'Disconnected'),
    };

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 16,
        height: 16,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isConnected)
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Transform.scale(
                  scale: _scale.value,
                  child: Opacity(
                    opacity: _opacity.value,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
