import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Compact save-state indicator for editors (Co-Writer, settings forms).
enum SaveStatus { idle, pending, saving, saved, error }

class SaveStatusChip extends StatelessWidget {
  const SaveStatusChip({super.key, required this.status});

  final SaveStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      SaveStatus.idle => ('', AppColors.grey400, Icons.circle_outlined),
      SaveStatus.pending => (
          'Unsaved',
          AppColors.warning,
          Icons.edit_outlined,
        ),
      SaveStatus.saving => (
          'Saving…',
          AppColors.primary,
          Icons.cloud_upload_outlined,
        ),
      SaveStatus.saved => (
          'Saved',
          AppColors.success,
          Icons.cloud_done_outlined,
        ),
      SaveStatus.error => (
          'Save failed',
          AppColors.error,
          Icons.error_outline,
        ),
    };

    if (status == SaveStatus.idle) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == SaveStatus.saving)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          else
            Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
