import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/feature_identity.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/design_system/dt_ai_pulse.dart';
import '../../../core/widgets/design_system/dt_page_shell.dart';
import '../../../data/models/career.dart';
import '../providers/career_live_provider.dart';
import '../providers/career_provider.dart';

/// Career paths screen.
///
/// Loads from `GET /api/v1/career/paths` with live updates via `/career/ws`.
class CareerScreen extends ConsumerStatefulWidget {
  const CareerScreen({super.key});

  @override
  ConsumerState<CareerScreen> createState() => _CareerScreenState();
}

class _CareerScreenState extends ConsumerState<CareerScreen>
    with RouteAware, WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Refresh when the app comes back to foreground (e.g. from background).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(careerPathsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(careerLiveListenerProvider);
    final pathsAsync = ref.watch(careerPathsProvider);
    final live = ref.watch(careerLiveListenerProvider) != null;

    return DtPageShell(
      title: 'Career',
      featureId: FeatureId.career,
      actions: [
        if (live) const Padding(
          padding: EdgeInsets.only(right: 8),
          child: DtAiPulse(label: 'LIVE', size: 6),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(careerPathsProvider),
        ),
      ],
      body: pathsAsync.when(
        loading: () => const _CareerSkeleton(),
        error: (e, _) => FriendlyErrorView(
          error: e,
          onRetry: () => ref.invalidate(careerPathsProvider),
        ),
        data: (response) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(careerPathsProvider),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (response.profileSummary != null)
                SliverToBoxAdapter(
                  child: _ProfileSummaryCard(summary: response.profileSummary!),
                ),

              // Stats row
              if (response.stats != null)
                SliverToBoxAdapter(
                  child: _StatsRow(stats: response.stats!),
                ),

              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _CareerPathCard(
                      path: response.paths[i],
                      isRecommended:
                          response.paths[i].id == response.recommendedPathId,
                    ),
                    childCount: response.paths.length,
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

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.summary});
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusL),
      ),
      child: Row(
        children: [
          const Icon(Icons.psychology_outlined, color: AppColors.accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(summary,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final totalPaths = stats['total_paths'] ?? 0;
    final avgReadiness = stats['avg_readiness_percent'] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: Row(
        children: [
          _StatChip(label: '$totalPaths paths', icon: Icons.route_outlined),
          const SizedBox(width: AppSpacing.sm),
          _StatChip(
            label: '${avgReadiness.toStringAsFixed(0)}% avg readiness',
            icon: Icons.bar_chart_rounded,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurface.withOpacity(0.6)),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _CareerPathCard extends StatelessWidget {
  const _CareerPathCard({
    required this.path,
    required this.isRecommended,
  });

  final CareerPath path;
  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final readiness = path.readinessPercent ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusL),
        border: Border.all(
          color: isRecommended
              ? AppColors.primary.withOpacity(0.5)
              : cs.outlineVariant,
          width: isRecommended ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  path.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: const Text(
                    'Recommended',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            path.description,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurface.withOpacity(0.6)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.md),

          // Readiness progress bar
          Row(
            children: [
              Text('Readiness',
                  style: Theme.of(context).textTheme.labelMedium),
              const Spacer(),
              Text(
                '$readiness%',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _readinessColor(readiness),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: readiness / 100,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor:
                  AlwaysStoppedAnimation<Color>(_readinessColor(readiness)),
              minHeight: 8,
            ),
          ),

          if (path.skills.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: path.skills
                  .take(5)
                  .map((s) => Chip(
                        label: Text(s,
                            style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        backgroundColor:
                            AppColors.accent.withOpacity(0.08),
                      ))
                  .toList(),
            ),
          ],

          if (path.skillGaps.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.arrow_upward,
                    size: 14, color: AppColors.warning),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Learn: ${path.skillGaps.take(3).join(", ")}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.warning,
                        ),
                  ),
                ),
              ],
            ),
          ],

          if (path.estimatedMonths != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.schedule,
                    size: 14,
                    color: cs.onSurface.withOpacity(0.5)),
                const SizedBox(width: 4),
                Text(
                  '~${path.estimatedMonths} months',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withOpacity(0.5),
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static Color _readinessColor(int pct) {
    if (pct >= 70) return AppColors.success;
    if (pct >= 40) return AppColors.warning;
    return AppColors.error;
  }
}

class _CareerSkeleton extends StatelessWidget {
  const _CareerSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        height: 160,
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusL),
        ),
      ),
    );
  }
}
