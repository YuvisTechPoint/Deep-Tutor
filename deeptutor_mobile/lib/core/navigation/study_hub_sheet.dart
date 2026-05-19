import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/router.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'dt_glass_container.dart';

/// Quick entry to learning-loop surfaces from the dock.
Future<void> showStudyHubSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => const _StudyHubSheet(),
  );
}

class _StudyHubSheet extends StatelessWidget {
  const _StudyHubSheet();

  static const _rows = [
    (
      Icons.hub_rounded,
      'Learn hub',
      'Overview of practice & revision',
      AppFeatureColors.learn,
      AppRoutes.learn,
    ),
    (
      Icons.quiz_rounded,
      'Practice',
      'MCQ quizzes by topic',
      AppFeatureColors.practice,
      AppRoutes.practice,
    ),
    (
      Icons.replay_rounded,
      'Revision',
      'Spaced repetition queue',
      AppFeatureColors.revision,
      AppRoutes.revision,
    ),
    (
      Icons.psychology_rounded,
      'Diagnostic',
      'Skill assessment',
      AppColors.copperPrimary,
      AppRoutes.diagnostic,
    ),
    (
      Icons.trending_up_rounded,
      'Career',
      'Roadmap & job readiness',
      AppFeatureColors.career,
      AppRoutes.career,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: DtGlassContainer(
        borderRadius: AppSpacing.radiusXL,
        padding: EdgeInsets.zero,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Study',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Practice, revise, and track your learning loop.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.only(
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    bottom: bottom + AppSpacing.lg,
                  ),
                  children: [
                    for (final row in _rows)
                      _StudyRow(
                        icon: row.$1,
                        label: row.$2,
                        subtitle: row.$3,
                        color: row.$4,
                        onTap: () {
                          Navigator.pop(context);
                          context.push(row.$5);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudyRow extends StatelessWidget {
  const _StudyRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(label, style: theme.textTheme.titleSmall),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
      ),
      onTap: onTap,
    );
  }
}
