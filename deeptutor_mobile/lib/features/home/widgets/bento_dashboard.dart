import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/feature_identity.dart';
import '../../../core/widgets/bento/bento_grid.dart';
import '../../../core/widgets/design_system/premium_module_card.dart';
import '../../../navigation/router.dart';
import '../providers/home_insights_provider.dart';

// ── Tile catalog ─────────────────────────────────────────────────────────────

List<BentoTileSpec> _defaultBentoTiles() => [
      const BentoTileSpec(
        featureId: FeatureId.chat,
        crossAxisSpan: 4,
        isHero: true,
      ),
      const BentoTileSpec(
        featureId: FeatureId.tutorBot,
        crossAxisSpan: 2,
        density: BentoDensity.compact,
      ),
      const BentoTileSpec(
        featureId: FeatureId.whiteboard,
        crossAxisSpan: 2,
        density: BentoDensity.compact,
      ),
      const BentoTileSpec(
        featureId: FeatureId.practice,
        crossAxisSpan: 2,
      ),
      const BentoTileSpec(
        featureId: FeatureId.books,
        crossAxisSpan: 2,
      ),
      const BentoTileSpec(
        featureId: FeatureId.revision,
        crossAxisSpan: 2,
      ),
      const BentoTileSpec(
        featureId: FeatureId.coWriter,
        crossAxisSpan: 2,
      ),
      const BentoTileSpec(
        featureId: FeatureId.codeLab,
        crossAxisSpan: 2,
      ),
      const BentoTileSpec(
        featureId: FeatureId.knowledge,
        crossAxisSpan: 2,
      ),
      const BentoTileSpec(
        featureId: FeatureId.missions,
        crossAxisSpan: 2,
      ),
      const BentoTileSpec(
        featureId: FeatureId.career,
        crossAxisSpan: 2,
      ),
      const BentoTileSpec(
        featureId: FeatureId.progress,
        crossAxisSpan: 2,
      ),
      const BentoTileSpec(
        featureId: FeatureId.roadmap,
        crossAxisSpan: 3,
        density: BentoDensity.compact,
      ),
      const BentoTileSpec(
        featureId: FeatureId.diagnostic,
        crossAxisSpan: 3,
        density: BentoDensity.compact,
      ),
    ];

// ── Dashboard ────────────────────────────────────────────────────────────────

/// Home learning OS bento — adaptive grid, hero chat, insight badges.
class BentoDashboard extends ConsumerWidget {
  const BentoDashboard({super.key, this.compact = false});

  /// On phone, show hero + highest-priority modules only (full list via study hub).
  final bool compact;

  static const _compactTileCount = 9;

  static String _routeFor(FeatureId id) => switch (id) {
        FeatureId.chat => AppRoutes.chat,
        FeatureId.tutorBot => AppRoutes.tutorBots,
        FeatureId.whiteboard => AppRoutes.whiteboard,
        FeatureId.practice => AppRoutes.practice,
        FeatureId.books => AppRoutes.books,
        FeatureId.revision => AppRoutes.revision,
        FeatureId.coWriter => AppRoutes.coWriter,
        FeatureId.codeLab => AppRoutes.codeLab,
        FeatureId.knowledge => AppRoutes.knowledge,
        FeatureId.missions => AppRoutes.missions,
        FeatureId.career => AppRoutes.career,
        FeatureId.progress => AppRoutes.progress,
        FeatureId.roadmap => AppRoutes.roadmap,
        FeatureId.diagnostic => AppRoutes.diagnostic,
        _ => AppRoutes.learn,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(homeInsightsProvider).valueOrNull ??
        const <HomeInsight>[];

    String? badge(FeatureId id) => insightForFeature(id, insights)?.badge;

    void go(FeatureId id, {String? sessionId}) {
      if (id == FeatureId.chat && sessionId != null) {
        context.push('${AppRoutes.chat}/$sessionId');
      } else {
        context.push(_routeFor(id));
      }
    }

    final chatInsight = insightForFeature(FeatureId.chat, insights);

    var tiles = _sortedTiles(insights);
    if (compact && tiles.length > _compactTileCount) {
      final hero = tiles.firstWhere((t) => t.isHero);
      final rest = tiles.where((t) => !t.isHero).take(_compactTileCount - 1);
      tiles = [hero, ...rest];
    }

    return AdaptiveBentoLayout(
      tiles: tiles,
      tileBuilder: (context, spec) {
        final id = spec.featureId;
        final identity = FeatureIdentity.of(id);

        if (spec.isHero && id == FeatureId.chat) {
          return _ChatHeroCard(
            previewSubtitle: chatInsight?.resumeSubtitle,
            onTap: () => go(
              FeatureId.chat,
              sessionId: chatInsight?.resumeSessionId,
            ),
          );
        }

        final insight = insightForFeature(id, insights);
        final subtitle = HomeInsight.sanitizeSubtitle(identity.subtitle);

        return PremiumModuleCard(
          featureId: id,
          density: spec.density,
          icon: identity.icon,
          label: identity.label,
          subtitle: subtitle,
          color: identity.accent,
          badge: badge(id),
          onTap: () => go(
            id,
            sessionId: id == FeatureId.chat ? insight?.resumeSessionId : null,
          ),
        );
      },
    );
  }

  List<BentoTileSpec> _sortedTiles(List<HomeInsight> insights) {
    final base = _defaultBentoTiles();
    final chat = base.firstWhere((t) => t.isHero);
    final rest = base.where((t) => !t.isHero).toList()
      ..sort((a, b) {
        final pa = priorityForFeature(a.featureId, insights);
        final pb = priorityForFeature(b.featureId, insights);
        if (pa != pb) return pb.compareTo(pa);
        return a.featureId.index.compareTo(b.featureId.index);
      });
    return [
      chat.copyWith(priority: priorityForFeature(FeatureId.chat, insights)),
      ...rest.map(
        (t) => t.copyWith(
          priority: priorityForFeature(t.featureId, insights),
        ),
      ),
    ];
  }
}

// ── Chat hero tile ───────────────────────────────────────────────────────────

class _ChatHeroCard extends StatefulWidget {
  const _ChatHeroCard({
    required this.onTap,
    this.previewSubtitle,
  });

  final VoidCallback onTap;
  final String? previewSubtitle;

  @override
  State<_ChatHeroCard> createState() => _ChatHeroCardState();
}

class _ChatHeroCardState extends State<_ChatHeroCard>
    with TickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;
  late final AnimationController _mesh;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: AppAnimations.fast,
      lowerBound: 0,
      upperBound: 1,
      value: 1,
    );
    _scale = Tween<double>(begin: 0.97, end: 1).animate(
      CurvedAnimation(parent: _press, curve: AppAnimations.enter),
    );
    _mesh = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _press.dispose();
    _mesh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = FeatureIdentity.of(FeatureId.chat).accent;
    final preview = HomeInsight.chatPreview(widget.previewSubtitle);
    final minH = AppSpacing.heroMinHeight(context);
    final padding = AppSpacing.cardPadding(context);

    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: (_) => _press.reverse(),
        onTapUp: (_) => _press.forward(),
        onTapCancel: () => _press.forward(),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            constraints: BoxConstraints(minHeight: minH),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
              gradient: AppGradients.glassModule(FeatureId.chat, isDark: isDark),
              border: Border.all(color: accent.withValues(alpha: 0.42)),
              boxShadow: AppElevation.glowActive(accent, isDark: isDark),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _mesh,
                      builder: (context, _) => CustomPaint(
                        painter: _NeuralMeshPainter(
                          phase: _mesh.value,
                          accent: accent,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -40,
                    top: -40,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ModuleIconOrb(
                              icon: FeatureIdentity.of(FeatureId.chat).icon,
                              color: accent,
                              size: 44,
                              iconSize: 24,
                            ),
                            const Spacer(),
                            LiveDot(color: accent),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'AI Chat',
                          style: AppTextStyles.bentoHeroTitle(context),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bentoHeroPreview(context),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AiPulseBars(color: accent),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NeuralMeshPainter extends CustomPainter {
  _NeuralMeshPainter({required this.phase, required this.accent});

  final double phase;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 6; i++) {
      final t = (phase + i * 0.15) % 1.0;
      final x = size.width * (0.15 + t * 0.7);
      final y = size.height * (0.2 + (i % 3) * 0.25);
      paint.color = accent.withValues(alpha: 0.04 + (i % 2) * 0.03);
      canvas.drawCircle(Offset(x, y), 28 + i * 6.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NeuralMeshPainter old) => old.phase != phase;
}
