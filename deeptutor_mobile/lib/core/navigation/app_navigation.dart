import 'package:flutter/material.dart';

import '../../navigation/router.dart';

/// Shared shell navigation model for dock + bottom bar.
enum ShellNavKind {
  route,
  studySheet,
  commandPalette,
  moreSheet,
}

class ShellNavItem {
  const ShellNavItem({
    required this.id,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.semanticLabel,
    required this.kind,
    this.route,
  });

  final String id;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String semanticLabel;
  final ShellNavKind kind;
  final String? route;
}

/// Primary dock destinations (max 5).
abstract final class AppNavigation {
  static const items = <ShellNavItem>[
    ShellNavItem(
      id: 'hub',
      icon: Icons.home_rounded,
      selectedIcon: Icons.home_rounded,
      label: 'Hub',
      semanticLabel: 'Home dashboard',
      kind: ShellNavKind.route,
      route: AppRoutes.home,
    ),
    ShellNavItem(
      id: 'chat',
      icon: Icons.chat_bubble_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
      label: 'Chat',
      semanticLabel: 'AI chat',
      kind: ShellNavKind.route,
      route: AppRoutes.chat,
    ),
    ShellNavItem(
      id: 'study',
      icon: Icons.school_rounded,
      selectedIcon: Icons.school_rounded,
      label: 'Study',
      semanticLabel: 'Learning hub',
      kind: ShellNavKind.studySheet,
    ),
    ShellNavItem(
      id: 'search',
      icon: Icons.search_rounded,
      selectedIcon: Icons.search_rounded,
      label: 'Search',
      semanticLabel: 'Command palette',
      kind: ShellNavKind.commandPalette,
    ),
    ShellNavItem(
      id: 'more',
      icon: Icons.grid_view_rounded,
      selectedIcon: Icons.grid_view_rounded,
      label: 'More',
      semanticLabel: 'More options',
      kind: ShellNavKind.moreSheet,
    ),
  ];

  /// Index of the dock item that should appear active for [location].
  static int selectedIndexForLocation(String location) {
    if (location.startsWith(AppRoutes.chat)) return 1;

    if (location.startsWith(AppRoutes.learn) ||
        location.startsWith(AppRoutes.practice) ||
        location.startsWith(AppRoutes.revision) ||
        location.startsWith(AppRoutes.diagnostic) ||
        location.startsWith(AppRoutes.career)) {
      return 2;
    }

    if (location.startsWith(AppRoutes.profile) ||
        location.startsWith(AppRoutes.settings) ||
        location.startsWith(AppRoutes.notifications) ||
        location.startsWith(AppRoutes.billing)) {
      return 4;
    }

    return 0;
  }

  static bool isRouteItemSelected(ShellNavItem item, int selectedIndex) {
    final index = items.indexOf(item);
    if (index < 0) return false;
    return index == selectedIndex && item.kind == ShellNavKind.route;
  }
}
