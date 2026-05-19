import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../providers/chat_provider.dart';
import 'chat_session_tile.dart';

/// Sidebar session list for tablet dual-pane chat layout.
class ChatSessionsPane extends ConsumerWidget {
  const ChatSessionsPane({
    super.key,
    this.activeSessionId,
    this.width,
  });

  final String? activeSessionId;
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(chatSessionsProvider);
    final paneWidth = width ??
        (ResponsiveLayout.isDesktop(context) ? 320.0 : 280.0);

    return Container(
      width: paneWidth,
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        border: Border(
          right: BorderSide(color: AppColors.surfaceGlassBorder),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Sessions',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_comment_outlined),
                  tooltip: 'New chat',
                  onPressed: () => context.push('/chat/new'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: AsyncValueWidget(
              value: sessionsAsync,
              onRetry: () => ref.invalidate(chatSessionsProvider),
              builder: (sessions) {
                if (sessions.isEmpty) {
                  return const Center(child: Text('No chats yet'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  itemCount: sessions.length,
                  itemBuilder: (_, i) {
                    final s = sessions[i];
                    return ChatSessionTile(
                      session: s,
                      index: i,
                      compact: true,
                      onOpen: () => context.go('/chat/${s.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
