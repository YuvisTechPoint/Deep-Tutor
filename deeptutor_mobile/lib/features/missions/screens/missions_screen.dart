import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/feature_identity.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/design_system/ai_section_header.dart';
import '../../../core/widgets/design_system/dt_page_shell.dart';
import '../../../data/models/gamification.dart';
import '../../career/providers/career_live_provider.dart';
import '../providers/missions_provider.dart';
import '../widgets/missions_os_widgets.dart';

/// Live missions OS — API-backed daily missions, XP, and reward shop.
class MissionsScreen extends ConsumerStatefulWidget {
  const MissionsScreen({super.key});

  @override
  ConsumerState<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends ConsumerState<MissionsScreen> {
  String? _claimingRewardId;

  Future<void> _refresh() async {
    refreshMissionsHub(ref);
    await Future.wait([
      ref.read(missionsNotifierProvider.notifier).load(),
      ref.read(gamificationStateProvider.future),
      ref.read(missionsRewardCatalogProvider.future),
      ref.read(missionsXpHistoryProvider.future),
    ]);
  }

  Future<void> _completeMission(Mission mission) async {
    try {
      final result = await ref
          .read(missionsNotifierProvider.notifier)
          .complete(mission.id, xpReward: mission.xpReward);
      ref.invalidate(gamificationStateProvider);
      ref.invalidate(missionsTodayProvider);
      if (!mounted) return;
      final xp = result?.xpAwarded ?? mission.xpReward;
      if (result?.alreadyCompleted == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already completed today')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('+$xp XP · Mission complete'),
            backgroundColor: AppColors.copperDeep,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not complete: $e')),
        );
      }
    }
  }

  Future<void> _claimReward(RewardCatalogItem item) async {
    setState(() => _claimingRewardId = item.id);
    try {
      await ref.read(gamificationRepositoryProvider).claimReward(item.id);
      refreshMissionsHub(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} claimed — fulfillment queued'),
            backgroundColor: AppColors.copperDeep,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _claimingRewardId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(careerLiveListenerProvider);

    final missionsState = ref.watch(missionsNotifierProvider);
    final gamAsync = ref.watch(gamificationStateProvider);
    final rewardsAsync = ref.watch(missionsRewardCatalogProvider);

    return DtPageShell(
      title: 'Missions',
      featureId: FeatureId.missions,
      actions: [
        if (missionsState.syncing)
          const Padding(
            padding: EdgeInsets.only(right: AppSpacing.sm),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Sync from server',
          onPressed: _refresh,
        ),
      ],
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: RefreshIndicator(
            color: AppColors.copperPrimary,
            onRefresh: _refresh,
            child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: AsyncValueWidget(
                value: gamAsync,
                loadingWidget: const MissionsGamSkeleton(),
                onRetry: () => ref.invalidate(gamificationStateProvider),
                builder: (gam) => MissionsGamHero(state: gam),
              ),
            ),
            if (missionsState.missions != null)
              SliverToBoxAdapter(
                child: MissionsTodayProgress(today: missionsState.missions!),
              ),
            SliverPadding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              sliver: SliverToBoxAdapter(
                child: AiSectionHeader(
                  title: 'Daily objectives',
                  subtitle: 'Live from your learning plan',
                  live: true,
                ),
              ),
            ),
            _missionsSliver(missionsState),
            if (missionsState.missions?.bonus != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: MissionLiveCard(
                    key: ValueKey(missionsState.missions!.bonus!.id),
                    mission: missionsState.missions!.bonus!,
                    completing: missionsState.completingId ==
                        missionsState.missions!.bonus!.id,
                    highlight: true,
                    onComplete: () =>
                        _completeMission(missionsState.missions!.bonus!),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: AsyncValueWidget(
                value: ref.watch(missionsXpHistoryProvider),
                loadingWidget: const SizedBox.shrink(),
                builder: (entries) => Padding(
                  padding: EdgeInsets.only(
                    top: AppSpacing.sectionGapFor(context),
                  ),
                  child: MissionsXpFeed(entries: entries),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(top: AppSpacing.sectionGapFor(context)),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AiSectionHeader(
                      title: 'XP marketplace',
                      subtitle: 'Redeem reward XP balance',
                    ),
                    rewardsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, __) => Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          'Could not load rewards. Pull to refresh.',
                          style: AppTextStyles.caption(context),
                        ),
                      ),
                      data: (items) {
                        final shopXp =
                            gamAsync.valueOrNull?.rewardXpBalance ?? 0;
                        return MissionsRewardShop(
                          items: items,
                          shopXp: shopXp,
                          claimingId: _claimingRewardId,
                          onClaim: _claimReward,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: AppSpacing.dockClearance +
                    MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _missionsSliver(MissionsNotifierState state) {
    if (state.isInitialLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.hasError && state.missions == null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Could not reach missions API',
                  style: AppTextStyles.moduleTitle(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${state.error}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption(context),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () =>
                      ref.read(missionsNotifierProvider.notifier).load(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final today = state.missions;
    if (today == null || today.missions.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'No missions for today — check back after midnight UTC.',
            style: AppTextStyles.caption(context),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final mission = today.missions[index];
          return MissionLiveCard(
            key: ValueKey(mission.id),
            mission: mission,
            completing: state.completingId == mission.id,
            onComplete: () => _completeMission(mission),
          );
        },
        childCount: today.missions.length,
      ),
    );
  }
}
