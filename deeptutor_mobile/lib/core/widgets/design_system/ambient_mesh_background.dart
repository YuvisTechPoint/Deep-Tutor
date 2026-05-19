import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_gradients.dart';

/// Cinematic mesh gradient + copper ambient orbs.
class AmbientMeshBackground extends StatefulWidget {
  const AmbientMeshBackground({
    super.key,
    required this.child,
    this.animate = true,
  });

  final Widget child;
  final bool animate;

  @override
  State<AmbientMeshBackground> createState() => _AmbientMeshBackgroundState();
}

class _AmbientMeshBackgroundState extends State<AmbientMeshBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    if (widget.animate) _drift.repeat();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? AppColors.voidBlack : AppColors.backgroundLight,
            gradient: isDark
                ? AppGradients.meshDark()
                : AppGradients.meshLight(),
          ),
        ),
        if (widget.animate)
          AnimatedBuilder(
            animation: _drift,
            builder: (context, _) {
              final t = _drift.value * 2 * math.pi;
              return Stack(
                children: [
                  _MeshOrb(
                    alignment: Alignment(
                      -0.5 + 0.08 * math.sin(t),
                      -0.7 + 0.05 * math.cos(t * 0.7),
                    ),
                    color: AppColors.copperPrimary.withValues(alpha: 0.12),
                    size: 340,
                  ),
                  _MeshOrb(
                    alignment: Alignment(
                      0.8 + 0.06 * math.cos(t * 0.9),
                      -0.3 + 0.07 * math.sin(t * 1.1),
                    ),
                    color: AppColors.copperDeep.withValues(alpha: 0.08),
                    size: 280,
                  ),
                  _MeshOrb(
                    alignment: Alignment(
                      0.15 + 0.1 * math.sin(t * 0.5),
                      0.85,
                    ),
                    color: AppColors.copperMuted.withValues(alpha: 0.06),
                    size: 220,
                  ),
                ],
              );
            },
          ),
        if (widget.animate)
          AnimatedBuilder(
            animation: _drift,
            builder: (context, _) => CustomPaint(
              painter: _ParticlePainter(_drift.value),
              size: Size.infinite,
            ),
          ),
        widget.child,
      ],
    );
  }
}

class _MeshOrb extends StatelessWidget {
  const _MeshOrb({
    required this.alignment,
    required this.color,
    required this.size,
  });

  final Alignment alignment;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.phase);
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 20; i++) {
      final paint = Paint()
        ..color = (i.isEven ? AppColors.copperPrimary : Colors.white)
            .withValues(alpha: 0.025 + (i % 3) * 0.01);
      final x = size.width * ((i * 0.17 + phase) % 1.0);
      final y = size.height * ((i * 0.23 + phase * 0.3) % 1.0);
      canvas.drawCircle(Offset(x, y), 1.0 + (i % 3) * 0.4, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.phase != phase;
}
