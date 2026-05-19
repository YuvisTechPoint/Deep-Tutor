import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/feature_identity.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/design_system/ai_section_header.dart';
import '../../../core/widgets/design_system/dt_page_shell.dart';
import '../../../core/widgets/design_system/premium_module_card.dart';
import '../../../services/realtime_sync.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_session_tile.dart';

/// Premium chat session hub with swipe-to-delete and API-backed removal.
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(chatSessionsProvider);
    ref.watch(realtimeTickProvider);
    final accent = FeatureIdentity.of(FeatureId.chat).accent;

    return DtPageShell(
      title: 'AI Chat',
      featureId: FeatureId.chat,
      actions: [
        IconButton.filled(
          tooltip: 'New chat',
          onPressed: () => context.push('/chat/new'),
          style: IconButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.add_comment_rounded),
        ),
      ],
      body: RefreshIndicator(
        color: accent,
        onRefresh: () => ref.read(chatSessionsProvider.notifier).refresh(),
        child: AsyncValueWidget(
          value: sessionsAsync,
          onRetry: () => ref.invalidate(chatSessionsProvider),
          builder: (sessions) {
            if (sessions.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  PremiumModuleCard(
                    featureId: FeatureId.chat,
                    height: 140,
                    icon: Icons.chat_bubble_rounded,
                    label: 'Start your first chat',
                    subtitle: 'Streaming AI tutor',
                    color: accent,
                    showPulse: true,
                    accentWidget: AiPulseBars(color: accent),
                    onTap: () => context.push('/chat/new'),
                  ),
                ],
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                const AiSectionHeader(
                  title: 'Recent sessions',
                  subtitle: 'Swipe left or tap delete',
                  live: true,
                ),
                for (var i = 0; i < sessions.length; i++)
                  ChatSessionTile(
                    session: sessions[i],
                    index: i,
                    onOpen: () => context.push('/chat/${sessions[i].id}'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
