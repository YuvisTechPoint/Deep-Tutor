import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/feature_identity.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/design_system/dt_page_shell.dart';
import '../../../data/models/gamification.dart' as gamification;
import '../../../data/models/learning_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/home_provider.dart';
import '../../onboarding/providers/onboarding_provider.dart';
import '../../../navigation/router.dart';

/// Learning ID / EIP profile screen.
///
/// Shows: profile summary, XP/streak stats, badges, and settings link.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final gamAsync = ref.watch(gamificationStateProvider);
    final profileAsync = ref.watch(_profileProvider);

    final username = switch (authState) {
      AuthAuthenticated(:final status) => status.username ?? 'Learner',
      _ => 'Learner',
    };

    return DtPageShell(
      title: 'Profile',
      featureId: FeatureId.settings,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push(AppRoutes.settings),
        ),
      ],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            _ProfileHeader(username: username),

            // Gamification stats
            AsyncValueWidget(
              value: gamAsync,
              loadingWidget: const SizedBox(height: 100),
              onRetry: () => ref.invalidate(gamificationStateProvider),
              builder: (gam) => _GamStats(state: gam),
            ),

            // Learning profile
            AsyncValueWidget(
              value: profileAsync,
              loadingWidget: const SizedBox(height: 80),
              onRetry: () => ref.invalidate(_profileProvider),
              builder: (profile) => _LearningIdCard(profile: profile),
            ),

            // Badges
            AsyncValueWidget(
              value: gamAsync,
              loadingWidget: const SizedBox.shrink(),
              onRetry: () => ref.invalidate(gamificationStateProvider),
              builder: (gam) => gam.badges.isNotEmpty
                  ? _BadgesSection(badges: gam.badges)
                  : const SizedBox.shrink(),
            ),

            const _ExploreSection(),

            // Actions
            _ProfileActions(
              onLogout: () async {
                await ref.read(authNotifierProvider.notifier).logout();
              },
              onStartOnboarding: () => context.push(AppRoutes.onboarding),
            ),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

// ── Profile header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.username});
  final String username;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.accent],
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              username[0].toUpperCase(),
              style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: Colors.white),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            username,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'DeepTutor Learner',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gamification stats ────────────────────────────────────────────────────────

class _GamStats extends StatelessWidget {
  const _GamStats({required this.state});
  final gamification.GamificationState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          _StatTile(value: '${state.xp}', label: 'Total XP'),
          _StatTile(value: '${state.level}', label: 'Level'),
          _StatTile(value: '${state.streak}', label: 'Streak 🔥'),
          _StatTile(value: '${state.badges.length}', label: 'Badges'),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusM),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Learning ID card ──────────────────────────────────────────────────────────

class _LearningIdCard extends StatelessWidget {
  const _LearningIdCard({required this.profile});
  final LearningProfile profile;

  @override
  Widget build(BuildContext context) {
    if (profile.careerPathId.isEmpty && profile.experienceLevel.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.badge_outlined, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Learning Identity',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.lg),
              if (profile.careerPathId.isNotEmpty)
                _ProfileRow(label: 'Career Path', value: profile.targetPath),
              if (profile.experienceLevel.isNotEmpty)
                _ProfileRow(label: 'Level', value: profile.experienceLevel),
              if (profile.weeklyHours != null)
                _ProfileRow(
                    label: 'Weekly Hours',
                    value: '${profile.weeklyHours!.round()} hrs'),
              if (profile.learningStyles.isNotEmpty)
                _ProfileRow(
                    label: 'Learning Style',
                    value: profile.learningStyles.join(', ')),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Badges ────────────────────────────────────────────────────────────────────

class _BadgesSection extends StatelessWidget {
  const _BadgesSection({required this.badges});
  final List<gamification.Badge> badges;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Badges',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: badges
                .map((b) => Tooltip(
                      message: b.description,
                      child: Chip(
                        avatar: const Icon(Icons.military_tech,
                            color: AppColors.xpGold, size: 18),
                        label: Text(b.name),
                        backgroundColor:
                            AppColors.xpGold.withOpacity(0.1),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Explore ───────────────────────────────────────────────────────────────────

class _ExploreSection extends StatelessWidget {
  const _ExploreSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _ExploreTile(
                  icon: Icons.insights_outlined,
                  title: 'Progress & analytics',
                  onTap: () => context.push(AppRoutes.progress),
                ),
                const Divider(height: 1),
                _ExploreTile(
                  icon: Icons.map_outlined,
                  title: 'Learning roadmap',
                  onTap: () => context.push(AppRoutes.roadmap),
                ),
                const Divider(height: 1),
                _ExploreTile(
                  icon: Icons.smart_toy_outlined,
                  title: 'TutorBots',
                  onTap: () => context.push(AppRoutes.tutorBots),
                ),
                const Divider(height: 1),
                _ExploreTile(
                  icon: Icons.edit_note_outlined,
                  title: 'Co-Writer',
                  onTap: () => context.push(AppRoutes.coWriter),
                ),
                const Divider(height: 1),
                _ExploreTile(
                  icon: Icons.draw_outlined,
                  title: 'Whiteboard tutor',
                  onTap: () => context.push(AppRoutes.whiteboard),
                ),
                const Divider(height: 1),
                _ExploreTile(
                  icon: Icons.hub_outlined,
                  title: 'Space workspace',
                  onTap: () => context.push(AppRoutes.space),
                ),
                const Divider(height: 1),
                _ExploreTile(
                  icon: Icons.badge_outlined,
                  title: 'Learning ID (EIP)',
                  onTap: () => context.push(AppRoutes.eipSettings),
                ),
                const Divider(height: 1),
                _ExploreTile(
                  icon: Icons.school_outlined,
                  title: 'Mentor portal',
                  onTap: () => context.push(AppRoutes.mentor),
                ),
                const Divider(height: 1),
                _ExploreTile(
                  icon: Icons.work_outline,
                  title: 'Recruiter portal',
                  onTap: () => context.push(AppRoutes.recruiter),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreTile extends StatelessWidget {
  const _ExploreTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

// ── Actions ───────────────────────────────────────────────────────────────────

class _ProfileActions extends StatelessWidget {
  const _ProfileActions({
    required this.onLogout,
    required this.onStartOnboarding,
  });

  final VoidCallback onLogout;
  final VoidCallback onStartOnboarding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          OutlinedButton.icon(
            onPressed: onStartOnboarding,
            icon: const Icon(Icons.edit_note),
            label: const Text('Update Learning Profile'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, AppSpacing.minTouchTarget),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout, color: AppColors.error),
            label: const Text(
              'Sign Out',
              style: TextStyle(color: AppColors.error),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, AppSpacing.minTouchTarget),
              side: const BorderSide(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Internal provider ─────────────────────────────────────────────────────────

final _profileProvider = FutureProvider.autoDispose<LearningProfile>((ref) {
  return ref.watch(profileRepositoryProvider).getProfile();
});
