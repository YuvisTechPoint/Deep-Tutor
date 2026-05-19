import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Breakpoint helpers for phone / tablet / desktop layouts.
abstract final class ResponsiveLayout {
  static double screenWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool isPhone(BuildContext context) =>
      screenWidth(context) < AppSpacing.tabletBreakpoint;

  static bool isTablet(BuildContext context) {
    final w = screenWidth(context);
    return w >= AppSpacing.tabletBreakpoint && w < AppSpacing.wideBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      screenWidth(context) >= AppSpacing.wideBreakpoint;

  /// Horizontal page gutter — grows slightly on very wide screens.
  static double pageHorizontalPadding(BuildContext context) {
    final w = screenWidth(context);
    if (w < AppSpacing.tabletBreakpoint) return AppSpacing.md;
    if (w < AppSpacing.wideBreakpoint) return AppSpacing.lg;
    if (w < 1200) return AppSpacing.xl;
    return AppSpacing.xxl;
  }

  /// Max width for dashboards (home bento, lists) — uses full width on all screens.
  static double contentMaxWidth(BuildContext context) {
    final w = screenWidth(context);
    final pad = pageHorizontalPadding(context) * 2;
    if (w < AppSpacing.tabletBreakpoint) return w;
    if (w < 1200) return w - pad;
    return 1200;
  }

  /// Readable line length for chat bubbles and prose.
  static double readerMaxWidth(BuildContext context) {
    final w = screenWidth(context);
    if (w < AppSpacing.tabletBreakpoint) return w - pageHorizontalPadding(context) * 2;
    return 720;
  }

  /// When true, chat shows sessions sidebar + thread.
  static bool useChatDualPane(BuildContext context) =>
      screenWidth(context) >= AppSpacing.wideBreakpoint;
}

/// Expands to full width; optionally caps and centers dashboard content.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.centered = true,
    this.maxWidth,
  });

  final Widget child;
  final bool centered;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final cap = maxWidth ?? ResponsiveLayout.contentMaxWidth(context);
    final w = ResponsiveLayout.screenWidth(context);

    if (!centered || w <= cap) {
      return SizedBox(width: w, child: child);
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cap),
        child: child,
      ),
    );
  }
}

/// Centers readable-width content (chat messages, articles).
class ResponsiveReader extends StatelessWidget {
  const ResponsiveReader({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final maxW = ResponsiveLayout.readerMaxWidth(context);
    final pad = padding ??
        EdgeInsets.symmetric(
          horizontal: ResponsiveLayout.pageHorizontalPadding(context),
        );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Padding(
          padding: pad,
          child: child,
        ),
      ),
    );
  }
}
