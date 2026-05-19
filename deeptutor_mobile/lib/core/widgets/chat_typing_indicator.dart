import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Animated three-dot typing / streaming indicator.
///
/// Each dot phases in and out using a sine wave offset per dot index,
/// giving a smooth "breathing" wave effect identical to what WhatsApp,
/// Telegram, etc. use for typing state.
class ChatTypingIndicator extends StatefulWidget {
  const ChatTypingIndicator({
    super.key,
    this.dotSize = 7.0,
    this.dotSpacing = 5.0,
    this.color,
  });

  final double dotSize;
  final double dotSpacing;
  final Color? color;

  @override
  State<ChatTypingIndicator> createState() => _ChatTypingIndicatorState();
}

class _ChatTypingIndicatorState extends State<ChatTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primary;
    return SizedBox(
      height: widget.dotSize * 2,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              // Sine wave with phase offset per dot.
              final phase = (i / 3.0) * 2 * math.pi;
              final raw = math.sin((_ctrl.value * 2 * math.pi) - phase);
              // Map [-1, 1] → [0.3, 1.0] for opacity.
              final opacity = 0.3 + 0.7 * ((raw + 1) / 2);
              // Map to vertical translation.
              final dy = -3.5 * ((raw + 1) / 2);
              return Padding(
                padding: EdgeInsets.only(
                  right: i < 2 ? widget.dotSpacing : 0,
                ),
                child: Transform.translate(
                  offset: Offset(0, dy),
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: widget.dotSize,
                      height: widget.dotSize,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
