import 'package:flutter/material.dart';

/// Motion design tokens for DeepTutor Copper AI OS.
abstract final class AppAnimations {
  static const Duration instant = Duration(milliseconds: 80);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration standard = Duration(milliseconds: 280);
  static const Duration medium = Duration(milliseconds: 400);
  static const Duration slow = Duration(milliseconds: 600);
  static const Duration xSlow = Duration(milliseconds: 900);

  static const Duration staggerStep = Duration(milliseconds: 45);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve spring = Curves.elasticOut;
  static const Curve standardCurve = Curves.easeInOutCubic;
  static const Curve decelerate = Curves.decelerate;
  static const Curve liquidNav = Curves.easeOutBack;

  static const double pageSlideOffset = 40.0;
  static const double dockIconScaleActive = 1.12;
  static const double pressScale = 0.96;

  static const SpringDescription snappy = SpringDescription(
    mass: 0.6,
    stiffness: 420,
    damping: 28,
  );

  static const SpringDescription cinematic = SpringDescription(
    mass: 1.0,
    stiffness: 180,
    damping: 22,
  );

  static const SpringDescription dockMorph = SpringDescription(
    mass: 0.8,
    stiffness: 320,
    damping: 26,
  );

  static const Duration dockHide = Duration(milliseconds: 220);
  static const Duration pulse = Duration(milliseconds: 2400);
  static const Duration shimmer = Duration(milliseconds: 1400);
}

/// Motion orchestration helpers.
abstract final class DtMotion {
  static Duration stagger(int index) =>
      AppAnimations.staggerStep * index;

  static Curve springCurve() => AppAnimations.liquidNav;

  static Animation<double> pulseAnimation(AnimationController controller) =>
      Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );

  static bool reduceMotion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);
}
