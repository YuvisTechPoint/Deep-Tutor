import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../layout/responsive.dart';
import '../../theme/app_spacing.dart';
import '../../theme/feature_identity.dart';
import 'glass_surface.dart';

/// Cinematic subpage shell — glass header, transparent scaffold, dock clearance.
class DtPageShell extends StatelessWidget {
  const DtPageShell({
    super.key,
    required this.title,
    required this.body,
    this.featureId,
    this.actions,
    this.floatingActionButton,
    this.bottom,
    this.slivers,
    this.showBack = true,
  });

  final String title;
  final Widget body;
  final FeatureId? featureId;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? bottom;
  final List<Widget>? slivers;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final accent = featureId != null
        ? FeatureIdentity.of(featureId!).accent
        : Theme.of(context).colorScheme.primary;

    if (slivers != null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        floatingActionButton: floatingActionButton,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              pinned: true,
              stretch: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              leading: showBack ? _BackButton(accent: accent) : null,
              title: Text(title),
              actions: actions,
              bottom: bottom,
              flexibleSpace: FlexibleSpaceBar(
                background: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        accent.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ...slivers!,
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: AppSpacing.shellBottomInset(context),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: floatingActionButton,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: GlassSurface(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                glowColor: accent,
                child: Row(
                  children: [
                    if (showBack) _BackButton(accent: accent),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (actions != null) ...actions!,
                  ],
                ),
              ),
            ),
          ),
          if (bottom != null) bottom!,
          Expanded(
            child: ResponsiveContent(
              centered: false,
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back_rounded, color: accent),
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      },
      tooltip: 'Back',
    );
  }
}
