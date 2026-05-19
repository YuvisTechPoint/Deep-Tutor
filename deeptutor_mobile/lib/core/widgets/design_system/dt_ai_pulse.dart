import 'package:flutter/material.dart';

import '../../theme/app_animations.dart';
import '../../theme/app_colors.dart';

/// Live AI activity indicator with copper pulse.
class DtAiPulse extends StatefulWidget {
  const DtAiPulse({
    super.key,
    this.label,
    this.size = 8,
    this.color,
  });

  final String? label;
  final double size;
  final Color? color;

  @override
  State<DtAiPulse> createState() => _DtAiPulseState();
}

class _DtAiPulseState extends State<DtAiPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.pulse,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (DtMotion.reduceMotion(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.copperPrimary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final scale = 0.85 + _controller.value * 0.3;
            return Container(
              width: widget.size * scale,
              height: widget.size * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5 + _controller.value * 0.3),
                    blurRadius: 8 + _controller.value * 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            );
          },
        ),
        if (widget.label != null) ...[
          const SizedBox(width: 6),
          Text(
            widget.label!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
          ),
        ],
      ],
    );
  }
}
