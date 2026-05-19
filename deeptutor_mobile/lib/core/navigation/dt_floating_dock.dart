import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_navigation.dart';
import 'dt_glass_container.dart';

/// Floating glass dock — morphing active pill and optional home quick action.
class DtFloatingDock extends StatelessWidget {
  const DtFloatingDock({
    super.key,
    required this.selectedIndex,
    required this.onItemTap,
    this.compact = false,
    this.collapseFactor = 0,
    this.showQuickAction = false,
    this.onQuickAction,
    this.quickActionTooltip = 'New chat',
  });

  final int selectedIndex;
  final ValueChanged<ShellNavItem> onItemTap;
  final bool compact;
  /// 0 = expanded, 1 = collapsed — drives compact scale.
  final double collapseFactor;
  final bool showQuickAction;
  final VoidCallback? onQuickAction;
  final String quickActionTooltip;

  @override
  Widget build(BuildContext context) {
    const items = AppNavigation.items;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final showLabels = !compact &&
        collapseFactor < 0.35 &&
        MediaQuery.sizeOf(context).width < 520;
    final scale = 1.0 - (collapseFactor * 0.08);

    const dockRadius = BorderRadius.only(
      topLeft: Radius.circular(28),
      topRight: Radius.circular(28),
    );
    final innerBottom = bottomInset > 0
        ? bottomInset + AppSpacing.sm
        : AppSpacing.sm;

    return Transform.scale(
      scale: scale,
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (showQuickAction && onQuickAction != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _QuickActionFab(
                  onPressed: onQuickAction!,
                  tooltip: quickActionTooltip,
                ),
              ),
            DtGlassContainer(
              borderRadius: 28,
              borderRadiusGeometry: dockRadius,
              padding: EdgeInsets.fromLTRB(
                showLabels ? AppSpacing.sm : AppSpacing.md,
                collapseFactor > 0.5 ? AppSpacing.xs : AppSpacing.sm,
                showLabels ? AppSpacing.sm : AppSpacing.md,
                innerBottom +
                    (collapseFactor > 0.5 ? AppSpacing.xs : AppSpacing.sm),
              ),
              child: _DockBar(
                items: items,
                selectedIndex: selectedIndex,
                showLabels: showLabels,
                onItemTap: onItemTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockBar extends StatelessWidget {
  const _DockBar({
    required this.items,
    required this.selectedIndex,
    required this.showLabels,
    required this.onItemTap,
  });

  final List<ShellNavItem> items;
  final int selectedIndex;
  final bool showLabels;
  final ValueChanged<ShellNavItem> onItemTap;

  static const double _itemWidth = 58;

  @override
  Widget build(BuildContext context) {
    final count = items.length;
    final barWidth = _itemWidth * count;

    return SizedBox(
      width: barWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedPositioned(
            duration: AppAnimations.standard,
            curve: AppAnimations.liquidNav,
            left: selectedIndex * _itemWidth + 4,
            width: _itemWidth - 8,
            top: 4,
            bottom: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    AppColors.copperPrimary.withValues(alpha: 0.45),
                    AppColors.copperDeep.withValues(alpha: 0.35),
                  ],
                ),
                boxShadow: AppElevationDock.activeGlow,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < count; i++)
                SizedBox(
                  width: _itemWidth,
                  child: _DockButton(
                    item: items[i],
                    selected: i == selectedIndex,
                    showLabel: showLabels,
                    showPillBackground: false,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onItemTap(items[i]);
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Glow presets for dock pill (keeps elevation.dart free of dock-only tokens).
abstract final class AppElevationDock {
  static final activeGlow = [
    BoxShadow(
      color: AppColors.copperPrimary.withValues(alpha: 0.40),
      blurRadius: 16,
      spreadRadius: -2,
    ),
  ];
}

class _QuickActionFab extends StatelessWidget {
  const _QuickActionFab({
    required this.onPressed,
    required this.tooltip,
  });

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.copperPrimary,
        elevation: 8,
        shadowColor: AppColors.copperPrimary.withValues(alpha: 0.5),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onPressed();
          },
          customBorder: const CircleBorder(),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Icon(Icons.add_comment_rounded, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatefulWidget {
  const _DockButton({
    required this.item,
    required this.selected,
    required this.showLabel,
    required this.onTap,
    this.showPillBackground = true,
  });

  final ShellNavItem item;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;
  final bool showPillBackground;

  @override
  State<_DockButton> createState() => _DockButtonState();
}

class _DockButtonState extends State<_DockButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale;

  @override
  void initState() {
    super.initState();
    _scale = AnimationController(
      vsync: this,
      duration: AppAnimations.fast,
      lowerBound: 0.92,
      upperBound: 1,
      value: 1,
    );
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = widget.selected;
    final iconColor = active
        ? AppColors.copperPrimary
        : theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final iconSize = active ? 26.0 : 24.0;

    return Semantics(
      button: true,
      selected: active,
      label: widget.item.semanticLabel,
      child: GestureDetector(
        onTapDown: (_) => _scale.reverse(),
        onTapUp: (_) {
          _scale.forward();
          widget.onTap();
        },
        onTapCancel: () => _scale.forward(),
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: AppAnimations.standard,
            curve: AppAnimations.standardCurve,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: EdgeInsets.symmetric(
              horizontal: widget.showLabel ? AppSpacing.md : AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: widget.showPillBackground && active
                  ? AppColors.copperPrimary.withValues(alpha: 0.18)
                  : Colors.transparent,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active ? widget.item.selectedIcon : widget.item.icon,
                  size: iconSize,
                  color: iconColor,
                ),
                if (widget.showLabel) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.item.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: iconColor,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 10,
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
