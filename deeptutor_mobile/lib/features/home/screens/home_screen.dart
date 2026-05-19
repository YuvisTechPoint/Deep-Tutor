import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/responsive.dart';
import '../../../core/navigation/study_hub_sheet.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/animated_entrance.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/design_system/ai_section_header.dart';
import '../../../core/widgets/design_system/dt_premium_skeleton.dart';
import '../providers/home_insights_provider.dart';
import '../../../navigation/router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../career/providers/career_live_provider.dart';
import '../../revision/providers/revision_provider.dart';
import '../providers/home_provider.dart';
import '../widgets/ai_hero_section.dart';
import '../widgets/bento_dashboard.dart';
import '../widgets/premium_xp_module.dart';

/// AI learning OS home — single scroll surface; no viewport-filling column hacks.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(careerLiveListenerProvider);
    final gamState = ref.watch(gamificationStateProvider);
    final authState = ref.watch(authNotifierProvider);
    final username = switch (authState) {
      AuthAuthenticated(:final status, :final isDemo) => isDemo
          ? (status.username ?? 'Guest')
          : (status.username ?? 'Learner'),
      _ => 'Learner',
    };

    ref.watch(homeInsightsProvider);
    final hPad = ResponsiveLayout.pageHorizontalPadding(context);
    final sectionGap = AppSpacing.sectionGapFor(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.copperPrimary,
          onRefresh: () async {
            ref.invalidate(gamificationStateProvider);
            ref.invalidate(missionsTodayProvider);
            ref.invalidate(revisionQueueCountProvider);
            ref.invalidate(homeInsightsProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(hPad, AppSpacing.md, hPad, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    AnimatedEntrance(
                      child: AiHeroSection(username: username),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AnimatedEntrance(
                      delay: AppAnimations.staggerStep,
                      child: AsyncValueWidget(
                        value: gamState,
                        loadingWidget: const _XpSkeleton(),
                        onRetry: () =>
                            ref.invalidate(gamificationStateProvider),
                        builder: (data) => PremiumXpModule(
                          state: data,
                          onTap: () => context.push(AppRoutes.progress),
                        ),
                      ),
                    ),
                    SizedBox(height: sectionGap),
                    AnimatedEntrance(
                      delay: AppAnimations.staggerStep * 3,
                      child: const AiSectionHeader(
                        title: 'Your workspace',
                        subtitle: 'AI modules · adaptive priorities',
                        live: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AnimatedEntrance(
                      delay: AppAnimations.staggerStep * 4,
                      child: BentoDashboard(
                        compact: ResponsiveLayout.isPhone(context),
                      ),
                    ),
                    if (ResponsiveLayout.isPhone(context)) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => showStudyHubSheet(context),
                          icon: const Icon(Icons.apps_rounded, size: 18),
                          label: const Text('Browse all modules'),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _XpSkeleton extends StatelessWidget {
  const _XpSkeleton();

  @override
  Widget build(BuildContext context) {
    return const DtPremiumSkeleton(
      height: 140,
      borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusXL)),
    );
  }
}
