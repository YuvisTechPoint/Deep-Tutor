import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_animations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_gradients.dart';
import '../../theme/app_spacing.dart';

enum DtCopperButtonVariant { primary, ghost, destructive }

/// Premium copper CTA with spring press and glow.
class DtCopperButton extends StatefulWidget {
  const DtCopperButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = DtCopperButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final DtCopperButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  State<DtCopperButton> createState() => _DtCopperButtonState();
}

class _DtCopperButtonState extends State<DtCopperButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;

    final child = AnimatedScale(
      scale: _pressed ? AppAnimations.pressScale : 1.0,
      duration: AppAnimations.fast,
      curve: AppAnimations.liquidNav,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  widget.onPressed!();
                }
              : null,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: Ink(
            height: 52,
            decoration: _decoration(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.loading)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else ...[
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 20, color: _foreground),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Text(
                      widget.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: _foreground,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return widget.expand ? SizedBox(width: double.infinity, child: child) : child;
  }

  Color get _foreground {
    switch (widget.variant) {
      case DtCopperButtonVariant.primary:
        return Colors.white;
      case DtCopperButtonVariant.ghost:
        return AppColors.copperPrimary;
      case DtCopperButtonVariant.destructive:
        return Colors.white;
    }
  }

  BoxDecoration _decoration(BuildContext context) {
    switch (widget.variant) {
      case DtCopperButtonVariant.primary:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          gradient: AppGradients.buttonPrimary(),
          boxShadow: [
            BoxShadow(
              color: AppColors.copperPrimary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        );
      case DtCopperButtonVariant.ghost:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: AppColors.copperPrimary.withValues(alpha: 0.5)),
          color: AppColors.surfaceGlass,
        );
      case DtCopperButtonVariant.destructive:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          color: AppColors.error,
        );
    }
  }
}
