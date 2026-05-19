import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'dt_delete_actions.dart';
import 'dt_list_module.dart';

/// [DtListModule] row with swipe-to-delete and trash icon.
class DtDeletableListModule extends StatelessWidget {
  const DtDeletableListModule({
    super.key,
    required this.dismissKey,
    required this.index,
    required this.glowColor,
    required this.leading,
    required this.title,
    required this.onTap,
    required this.onDelete,
    this.subtitle,
    this.trailing,
    this.deleteTooltip = 'Delete',
  });

  final String dismissKey;
  final int index;
  final Color glowColor;
  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Future<bool> Function() onDelete;
  final Widget? trailing;
  final String deleteTooltip;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(dismissKey),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.35},
      background: const DtDeleteDismissBackground(),
      confirmDismiss: (_) => DtDeleteActions.runDelete(
        context,
        itemLabel: title,
        delete: onDelete,
      ),
      child: DtListModule(
        index: index,
        glowColor: glowColor,
        leading: leading,
        title: title,
        subtitle: subtitle,
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailing != null) trailing!,
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error.withValues(alpha: 0.85),
                size: 20,
              ),
              tooltip: deleteTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: () => DtDeleteActions.runDelete(
                context,
                itemLabel: title,
                delete: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
