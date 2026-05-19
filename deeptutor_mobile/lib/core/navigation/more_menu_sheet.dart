import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/router.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/feature_identity.dart';
import 'dt_glass_container.dart';

Future<void> showMoreMenuSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => const _MoreMenuSheet(),
  );
}

class _MoreMenuSheet extends StatelessWidget {
  const _MoreMenuSheet();

  static const _account = [
    _MenuItem(
      featureId: null,
      icon: Icons.person_rounded,
      label: 'Profile',
      subtitle: 'Learning identity & stats',
      accent: AppColors.copperPrimary,
      route: AppRoutes.profile,
    ),
    _MenuItem(
      featureId: FeatureId.notifications,
      icon: Icons.notifications_rounded,
      label: 'Notifications',
      subtitle: 'Inbox & alerts',
      route: AppRoutes.notifications,
    ),
  ];

  static const _learning = [
    _MenuItem(
      featureId: FeatureId.progress,
      icon: Icons.insights_rounded,
      label: 'Progress',
      subtitle: 'XP, analytics & rank',
      route: AppRoutes.progress,
    ),
    _MenuItem(
      featureId: FeatureId.books,
      icon: Icons.auto_stories_rounded,
      label: 'Living Books',
      subtitle: 'Interactive texts',
      route: AppRoutes.books,
    ),
    _MenuItem(
      featureId: FeatureId.codeLab,
      icon: Icons.terminal_rounded,
      label: 'Code Lab',
      subtitle: 'Run & submit code',
      route: AppRoutes.codeLab,
    ),
    _MenuItem(
      featureId: FeatureId.knowledge,
      icon: Icons.hub_rounded,
      label: 'Knowledge',
      subtitle: 'RAG bases & uploads',
      route: AppRoutes.knowledge,
    ),
  ];

  static const _system = [
    _MenuItem(
      featureId: null,
      icon: Icons.credit_card_rounded,
      label: 'Billing',
      subtitle: 'Plans & subscription',
      accent: AppColors.warmGold,
      route: AppRoutes.billing,
    ),
    _MenuItem(
      featureId: FeatureId.settings,
      icon: Icons.settings_rounded,
      label: 'Control Center',
      subtitle: 'Theme, AI models & privacy',
      route: AppRoutes.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
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
        borderRadius: AppSpacing.radiusXL + 4,
        padding: EdgeInsets.zero,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHeader(onClose: () => Navigator.pop(context)),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    bottom + AppSpacing.lg,
                  ),
                  children: [
                    _Section(
                      label: 'Account',
                      items: _account,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _Section(
                      label: 'Learning',
                      items: _learning,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _Section(
                      label: 'System',
                      items: _system,
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

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.copperPrimary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WORKSPACE',
                      style: AppTextStyles.osSectionLabel(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'More',
                      style: AppTextStyles.osModuleTitle(context).copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Account, learning tools & settings',
                      style: AppTextStyles.caption(context),
                    ),
                  ],
                ),
              ),
              Material(
                color: AppColors.surfaceGlass,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onClose,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.close_rounded, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.items,
  });

  final String label;
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            label.toUpperCase(),
            style: AppTextStyles.osSectionLabel(context).copyWith(
              color: AppColors.copperPrimary.withValues(alpha: 0.75),
              letterSpacing: 1.6,
            ),
          ),
        ),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          _MenuRow(item: items[i]),
        ],
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item});

  final _MenuItem item;

  Color get _accent {
    if (item.accent != null) return item.accent!;
    if (item.featureId != null) {
      return FeatureIdentity.of(item.featureId!).accent;
    }
    return AppColors.copperPrimary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppColors.surfaceGlass,
      borderRadius: BorderRadius.circular(AppSpacing.radiusL),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.pop(context);
          context.push(item.route);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusL),
            border: Border.all(
              color: _accent.withValues(alpha: 0.18),
            ),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                _accent.withValues(alpha: 0.10),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: RadialGradient(
                    colors: [
                      _accent.withValues(alpha: 0.35),
                      _accent.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(color: _accent.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(item.icon, color: _accent, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _accent.withValues(alpha: 0.65),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.route,
    this.featureId,
    this.accent,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final String route;
  final FeatureId? featureId;
  final Color? accent;
}
