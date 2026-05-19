import 'package:flutter/material.dart';

/// Design token spacing and radius constants.
///
/// 4-point grid system. All UI spacing should derive from these values.
abstract final class AppSpacing {
  // Spacing
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  /// Cinematic section rhythm (phone).
  static const double sectionGap = 24;
  static const double sectionGapLarge = 32;
  static const double sectionGapHero = 48;

  /// Legacy default — prefer [shellBottomInset].
  static const double dockClearance = 88;

  /// Height of the dock pill (icons + vertical padding).
  static const double dockBarHeight = 56;

  /// Quick-action FAB above the dock on home.
  static const double dockQuickActionHeight = 50;
  static const double dockQuickActionGap = 8;

  /// Soft fade behind the dock — not a full opaque band.
  static const double shellFadeHeight = 52;

  /// Live bottom inset for scrollable content above [DtFloatingDock].
  static double shellBottomInset(
    BuildContext context, {
    bool includeQuickAction = false,
    double collapseFactor = 0,
  }) {
    final safe = MediaQuery.paddingOf(context).bottom;
    var inset = dockBarHeight + md + safe;
    if (includeQuickAction) {
      inset += dockQuickActionHeight + dockQuickActionGap;
    }
    return inset * (1.0 - collapseFactor.clamp(0.0, 1.0) * 0.88);
  }

  /// Extra inset for composers **outside** [AppShell] (shell already pads content).
  static double composerBottomInset(BuildContext context, {double extra = 0}) {
    return sm + extra;
  }

  // Radius
  static const double radiusXS = 4;
  static const double radiusS = 8;
  static const double radiusM = 12;
  static const double radiusL = 16;
  static const double radiusXL = 24;
  static const double radiusFull = 999;

  // Touch targets (minimum 48dp per spec)
  static const double minTouchTarget = 48;

  // Content max width for tablets
  static const double maxContentWidth = 720;

  // Breakpoints
  static const double phoneBreakpoint = 360;
  static const double tabletBreakpoint = 600;
  static const double wideBreakpoint = 840;

  /// Minimum height for cinematic chat hero tiles.
  static const double heroMinHeightStatic = 152;

  static int bentoColumnCount(double width) {
    if (width < phoneBreakpoint) return 4;
    if (width < tabletBreakpoint) return 6;
    if (width < wideBreakpoint) return 8;
    if (width < 1200) return 10;
    return 12;
  }

  static double bentoGap(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= tabletBreakpoint ? md : sm;
  }

  static double cardPadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w < phoneBreakpoint ? sm + xs : md;
  }

  static double heroMinHeight(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < phoneBreakpoint) return 140;
    if (w < tabletBreakpoint) return heroMinHeightStatic;
    return 168;
  }

  static double sectionGapFor(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= tabletBreakpoint ? sectionGapLarge : sectionGap;
  }
}
