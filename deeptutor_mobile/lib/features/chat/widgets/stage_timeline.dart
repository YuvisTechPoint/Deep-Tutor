import 'package:flutter/material.dart';

import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Collapsible card showing each stage observed during the current turn.
///
/// Visible above the chat list while the assistant is streaming.
class StageTimeline extends StatefulWidget {
  const StageTimeline({
    super.key,
    required this.stages,
    required this.activeStage,
  });

  final List<String> stages;
  final String? activeStage;

  @override
  State<StageTimeline> createState() => _StageTimelineState();
}

class _StageTimelineState extends State<StageTimeline> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final stages = widget.stages;
    if (stages.isEmpty) return const SizedBox.shrink();

    return Material(
      color: AppColors.accent.withOpacity(0.06),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedSize(
          duration: AppAnimations.fast,
          curve: AppAnimations.enter,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        widget.activeStage ?? stages.last,
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '${stages.length} ${stages.length == 1 ? "stage" : "stages"}',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 18,
                      color: AppColors.accent,
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: AppSpacing.xs),
                  for (var i = 0; i < stages.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(
                          left: AppSpacing.lg, bottom: 2),
                      child: Row(
                        children: [
                          Icon(
                            i == stages.length - 1 &&
                                    widget.activeStage != null
                                ? Icons.radio_button_checked
                                : Icons.check_circle_outline,
                            size: 12,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              stages[i],
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.accent.withOpacity(0.85),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
