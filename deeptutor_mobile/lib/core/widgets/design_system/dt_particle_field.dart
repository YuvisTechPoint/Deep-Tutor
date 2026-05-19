import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Lightweight floating particles for hero sections (max 20).
class DtParticleField extends StatelessWidget {
  const DtParticleField({
    super.key,
    this.count = 20,
    this.phase = 0,
  });

  final int count;
  final double phase;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _CopperParticlePainter(
          count: count.clamp(0, 20),
          phase: phase,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _CopperParticlePainter extends CustomPainter {
  _CopperParticlePainter({required this.count, required this.phase});

  final int count;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < count; i++) {
      final paint = Paint()
        ..color = (i.isEven ? AppColors.copperPrimary : Colors.white)
            .withValues(alpha: 0.03 + (i % 4) * 0.01);
      final x = size.width * ((i * 0.17 + phase) % 1.0);
      final y = size.height * ((i * 0.23 + phase * 0.3) % 1.0);
      canvas.drawCircle(Offset(x, y), 1.0 + (i % 3) * 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(_CopperParticlePainter old) =>
      old.phase != phase || old.count != count;
}
