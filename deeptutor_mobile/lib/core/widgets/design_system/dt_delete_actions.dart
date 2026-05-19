import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Shared confirm dialog + snackbars for list item deletion.
class DtDeleteActions {
  DtDeleteActions._();

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  static Future<bool> runDelete(
    BuildContext context, {
    required String itemLabel,
    required Future<bool> Function() delete,
    String? inProgressMessage,
    String? successMessage,
    String? failureMessage,
  }) async {
    final confirmed = await confirm(
      context,
      title: 'Delete?',
      message: 'Remove "$itemLabel"? This cannot be undone.',
    );
    if (!confirmed || !context.mounted) return false;

    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(inProgressMessage ?? 'Deleting…'),
        duration: const Duration(seconds: 1),
      ),
    );

    final ok = await delete();
    if (!context.mounted) return ok;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (successMessage ?? 'Deleted')
              : (failureMessage ?? 'Could not delete. Try again.'),
        ),
        backgroundColor: ok ? null : AppColors.error,
      ),
    );
    return ok;
  }
}

/// Red swipe background for [Dismissible] list rows.
class DtDeleteDismissBackground extends StatelessWidget {
  const DtDeleteDismissBackground({super.key, this.marginBottom});

  final double? marginBottom;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: marginBottom ?? AppSpacing.sm),
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
