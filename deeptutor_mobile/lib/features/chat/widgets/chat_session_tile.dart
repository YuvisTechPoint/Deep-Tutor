import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_errors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/feature_identity.dart';
import '../../../core/widgets/design_system/dt_list_module.dart';
import '../../../core/widgets/design_system/premium_module_card.dart';
import '../../../data/models/chat_session.dart';
import '../providers/chat_provider.dart';

/// Swipe-to-delete + explicit delete control for a chat session row.
class ChatSessionTile extends ConsumerWidget {
  const ChatSessionTile({
    super.key,
    required this.session,
    required this.index,
    required this.onOpen,
    this.compact = false,
  });

  final ChatSession session;
  final int index;
  final VoidCallback onOpen;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = FeatureIdentity.of(FeatureId.chat).accent;
    final title = session.title.isNotEmpty ? session.title : 'New chat';
    final subtitle = _displaySubtitle(session.lastMessage);

    return Dismissible(
      key: ValueKey('chat-session-${session.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {
        DismissDirection.endToStart: 0.35,
      },
      background: _DeleteBackground(compact: compact),
      confirmDismiss: (_) =>
          _confirmAndDelete(context, ref, title, session.id),
      child: DtListModule(
        index: index,
        glowColor: accent,
        leading: ModuleIconOrb(
          icon: Icons.chat_bubble_outline,
          color: accent,
        ),
        title: title,
        subtitle: subtitle,
        onTap: onOpen,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error.withValues(alpha: 0.85),
                size: 20,
              ),
              tooltip: 'Delete session',
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final deleted = await _confirmAndDelete(
                  context,
                  ref,
                  title,
                  session.id,
                );
                if (deleted == true && context.mounted) {
                  final location = GoRouterState.of(context).matchedLocation;
                  if (location == '/chat/${session.id}') {
                    context.go('/chat');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String? _displaySubtitle(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final text = raw.trim();
    if (text.startsWith('Error code:') || text.contains('authentication')) {
      return 'Last turn failed — open to retry';
    }
    if (text.length > 120) return '${text.substring(0, 117)}…';
    return text;
  }

  static Future<bool?> _confirmAndDelete(
    BuildContext context,
    WidgetRef ref,
    String title,
    String sessionId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session?'),
        content: Text(
          'Remove "$title"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return false;

    HapticFeedback.mediumImpact();

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Deleting session…'),
        duration: Duration(seconds: 1),
      ),
    );

    final ok = await ref
        .read(chatSessionsProvider.notifier)
        .deleteSession(sessionId);

    if (!context.mounted) return ok;

    messenger.hideCurrentSnackBar();
    if (ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Session deleted')),
      );
      return true;
    }

    final err = ref.read(chatSessionsProvider).error;
    final message = err is DioException && isAuthDioError(err)
        ? 'Not allowed to delete — check sign-in permissions'
        : 'Could not delete session. Try again.';

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
    return false;
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: compact ? 4 : AppSpacing.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.error.withValues(alpha: 0.85),
            AppColors.copperDeep.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppSpacing.lg),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline, color: Colors.white),
          SizedBox(width: AppSpacing.sm),
          Text(
            'Delete',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
