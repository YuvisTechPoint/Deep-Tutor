import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// Primary branded button with loading state.
class DtButton extends StatelessWidget {
  const DtButton({
    super.key,
    required this.child,
    this.onPressed,
    this.loading = false,
    this.variant = DtButtonVariant.filled,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool loading;
  final DtButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final content = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : child;

    switch (variant) {
      case DtButtonVariant.filled:
        return ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, AppSpacing.minTouchTarget + 4),
          ),
          child: content,
        );
      case DtButtonVariant.outlined:
        return OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, AppSpacing.minTouchTarget + 4),
          ),
          child: content,
        );
      case DtButtonVariant.text:
        return TextButton(
          onPressed: loading ? null : onPressed,
          child: content,
        );
    }
  }
}

enum DtButtonVariant { filled, outlined, text }
