import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/app_navigation.dart';
import '../../core/navigation/dt_command_palette.dart';
import '../../core/navigation/dt_floating_dock.dart';
import '../../core/navigation/more_menu_sheet.dart';
import '../../core/navigation/study_hub_sheet.dart';
import '../../core/theme/app_animations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../navigation/router.dart';

/// Immersive shell — dock fixed at bottom, content inset matches dock height exactly.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  /// @deprecated Use [AppSpacing.shellBottomInset].
  static const double dockClearance = AppSpacing.dockClearance;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// 0 = fully visible, 1 = fully collapsed.
  double _dockCollapse = 0;

  static const _collapsePerPixel = 0.006;
  static const _revealPerPixel = 0.012;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      if (delta == 0) return false;

      final next = delta > 0
          ? (_dockCollapse + delta * _collapsePerPixel).clamp(0.0, 1.0)
          : (_dockCollapse + delta * _revealPerPixel).clamp(0.0, 1.0);

      if ((next - _dockCollapse).abs() > 0.001) {
        setState(() => _dockCollapse = next);
      }
    } else if (notification is ScrollEndNotification) {
      final pixels = notification.metrics.pixels;
      if (pixels <= 0 && _dockCollapse > 0) {
        setState(() => _dockCollapse = 0);
      } else if (_dockCollapse > 0.35 && _dockCollapse < 0.65) {
        setState(() => _dockCollapse = _dockCollapse >= 0.5 ? 1.0 : 0.0);
      }
    }

    return false;
  }

  void _expandDock() => setState(() => _dockCollapse = 0);

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return AppNavigation.selectedIndexForLocation(location);
  }

  void _onDockItem(BuildContext context, ShellNavItem item) {
    _expandDock();
    switch (item.kind) {
      case ShellNavKind.route:
        if (item.route != null) context.go(item.route!);
      case ShellNavKind.studySheet:
        showStudyHubSheet(context);
      case ShellNavKind.commandPalette:
        showCommandPalette(context);
      case ShellNavKind.moreSheet:
        showMoreMenuSheet(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final selectedIndex = _selectedIndex(context);
    final location = GoRouterState.of(context).uri.path;
    final onHomeOnly = location == AppRoutes.home;
    final alignLeft = width >= AppSpacing.tabletBreakpoint;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final eased = Curves.easeOutCubic.transform(_dockCollapse);
    final dockOffset = 88.0 * eased;
    final dockOpacity = (1.0 - eased).clamp(0.0, 1.0);
    final shellInset = AppSpacing.shellBottomInset(
      context,
      includeQuickAction: onHomeOnly && eased < 0.35,
      collapseFactor: eased,
    );
    final scrimHeight =
        AppSpacing.shellFadeHeight + AppSpacing.dockBarHeight + AppSpacing.sm;

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK):
            const OpenCommandPaletteIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
            const OpenCommandPaletteIntent(),
      },
      child: Actions(
        actions: {
          OpenCommandPaletteIntent: OpenCommandPaletteAction(
            () => showCommandPalette(context),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            body: Stack(
              fit: StackFit.expand,
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: AnimatedPadding(
                    duration: AppAnimations.fast,
                    curve: AppAnimations.standardCurve,
                    padding: EdgeInsets.only(bottom: shellInset),
                    child: widget.child,
                  ),
                ),
                // Subtle fade above the dock — does not extend into safe area.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: bottomInset + AppSpacing.dockBarHeight + AppSpacing.sm,
                  height: scrimHeight,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: dockOpacity * 0.85,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.voidBlack.withValues(alpha: 0),
                              AppColors.voidBlack.withValues(alpha: 0.12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: alignLeft ? AppSpacing.lg : 0,
                  right: alignLeft ? null : 0,
                  bottom: 0,
                  child: IgnorePointer(
                    ignoring: dockOpacity < 0.05,
                    child: Transform.translate(
                      offset: Offset(0, dockOffset),
                      child: Opacity(
                        opacity: dockOpacity,
                        child: Align(
                          alignment: alignLeft
                              ? Alignment.bottomLeft
                              : Alignment.bottomCenter,
                          child: DtFloatingDock(
                            selectedIndex: selectedIndex,
                            compact: alignLeft || eased > 0.4,
                            collapseFactor: eased,
                            showQuickAction: onHomeOnly && eased < 0.35,
                            onQuickAction: () => context.push(AppRoutes.chat),
                            onItemTap: (item) => _onDockItem(context, item),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (eased > 0.72)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: bottomInset + AppSpacing.sm,
                    child: Center(
                      child: _DockPeekHandle(onTap: _expandDock),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimal handle when dock is collapsed — tap to restore.
class _DockPeekHandle extends StatelessWidget {
  const _DockPeekHandle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.surfaceGlassBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.copperPrimary.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.keyboard_arrow_up_rounded,
                color: AppColors.copperPrimary,
                size: 22,
              ),
              const SizedBox(width: 4),
              Text(
                'Navigation',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.copperPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
