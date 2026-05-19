import 'package:flutter/material.dart';

import '../theme/app_animations.dart';

/// Horizontal slide + slight scale — used when advancing quiz questions.
class SlideQuestionTransition extends StatelessWidget {
  const SlideQuestionTransition({
    super.key,
    required this.child,
    required this.animation,
    required this.forward,
  });

  final Widget child;
  final Animation<double> animation;
  final bool forward;

  @override
  Widget build(BuildContext context) {
    final offset = forward
        ? Tween<Offset>(begin: const Offset(0.12, 0), end: Offset.zero)
        : Tween<Offset>(begin: const Offset(-0.12, 0), end: Offset.zero);
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppAnimations.enter,
    );

    return SlideTransition(
      position: offset.animate(curved),
      child: FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      ),
    );
  }
}

/// Y-axis flip transition for swapping card faces (onboarding / practice).
class FlipTransition extends StatelessWidget {
  const FlipTransition({
    super.key,
    required this.child,
    required this.animation,
  });

  final Widget child;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final rotate = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: animation, curve: AppAnimations.enter),
    );

    return AnimatedBuilder(
      animation: rotate,
      child: child,
      builder: (context, child) {
        final angle = rotate.value * 3.14159;
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          alignment: Alignment.center,
          child: Opacity(
            opacity: rotate.value < 0.5 ? 1.0 : 0.0,
            child: child,
          ),
        );
      },
    );
  }
}
