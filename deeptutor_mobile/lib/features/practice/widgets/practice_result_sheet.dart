import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/practice.dart';

/// Results screen shown after quiz submission.
class PracticeResultSheet extends StatelessWidget {
  const PracticeResultSheet({
    super.key,
    required this.result,
    required this.onRetry,
  });

  final PracticeSubmitResult result;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final pct = result.percentage;
    final isPassed = pct >= 0.6;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: AppSpacing.xl),
          CircularPercentIndicator(
            radius: 80,
            lineWidth: 10,
            percent: pct,
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${(pct * 100).round()}%',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isPassed ? AppColors.success : AppColors.error,
                      ),
                ),
                Text(
                  '${result.score}/${result.total}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            progressColor: isPassed ? AppColors.success : AppColors.error,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            animation: true,
            animationDuration: 1000,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            isPassed ? '🎉 Well done!' : '📚 Keep practicing!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (result.feedback != null)
            Text(
              result.feedback!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
            ),
          const SizedBox(height: AppSpacing.xl),

          // XP earned
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.xpGold.withOpacity(0.1),
                  AppColors.primary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusL),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('⚡', style: TextStyle(fontSize: 32)),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  children: [
                    Text(
                      '+${result.xpAwarded} XP',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.xpGold,
                          ),
                    ),
                    Text(
                      'Experience earned',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
            child: const Text('Practice Again'),
          ),
        ],
      ),
    );
  }
}
