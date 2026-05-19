import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/feature_identity.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/design_system/design_system.dart';
import '../../../core/utils/dt_date_utils.dart';
import '../../../data/models/notification_item.dart';
import '../../../services/realtime_sync.dart';
import '../providers/notifications_provider.dart';

/// Notification inbox screen.
///
/// Lists all notifications from `GET /api/v1/notifications`.
/// Marks items read via `POST /api/v1/notifications/{id}/read`.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsNotifierProvider);
    ref.watch(realtimeTickProvider);
    final notifier = ref.read(notificationsNotifierProvider.notifier);

    return DtPageShell(
      title: 'Notifications',
      featureId: FeatureId.notifications,
      actions: [
        if (state.unreadCount > 0)
          TextButton(
            onPressed: notifier.markAllRead,
            child: const Text('Mark all read'),
          ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: notifier.load,
        ),
      ],
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? FriendlyErrorView(
                  message: state.error!,
                  onRetry: notifier.load,
                )
              : state.items.isEmpty
                  ? const _EmptyView()
                  : RefreshIndicator(
                      onRefresh: notifier.load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: state.items.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (_, i) => _NotificationTile(
                          item: state.items[i],
                          onTap: () => notifier.markRead(state.items[i].id),
                          onDelete: () =>
                              notifier.deleteNotification(state.items[i].id),
                        ),
                      ),
                    ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final NotificationItem item;
  final VoidCallback onTap;
  final Future<bool> Function() onDelete;

  static IconData _iconFor(String? type) => switch (type) {
        'mission_complete' => Icons.flag_rounded,
        'xp_gained' => Icons.bolt_rounded,
        'level_up' => Icons.star_rounded,
        'badge_earned' => Icons.military_tech_rounded,
        'system' => Icons.info_outline,
        _ => Icons.notifications_outlined,
      };

  static Color _colorFor(String? type) => switch (type) {
        'mission_complete' => AppColors.success,
        'xp_gained' => AppColors.xpGold,
        'level_up' => AppColors.levelBadge,
        'badge_earned' => AppColors.xpGold,
        'system' => AppColors.info,
        _ => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _colorFor(item.type);
    final icon = _iconFor(item.type);

    return Dismissible(
      key: ValueKey('notification-${item.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.35},
      background: const DtDeleteDismissBackground(marginBottom: 0),
      confirmDismiss: (_) => DtDeleteActions.runDelete(
        context,
        itemLabel: item.title,
        delete: onDelete,
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: item.isRead ? null : color.withValues(alpha: 0.05),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: item.isRead
                                      ? FontWeight.normal
                                      : FontWeight.w700,
                                ),
                          ),
                        ),
                        Text(
                          DtDateUtils.chatTimestamp(item.createdAt),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.5),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.body,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error.withValues(alpha: 0.85),
                  size: 20,
                ),
                tooltip: 'Delete notification',
                visualDensity: VisualDensity.compact,
                onPressed: () => DtDeleteActions.runDelete(
                  context,
                  itemLabel: item.title,
                  delete: onDelete,
                ),
              ),
              if (!item.isRead)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs, top: 2),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'All caught up!',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'No new notifications',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
