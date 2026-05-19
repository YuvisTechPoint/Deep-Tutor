import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import 'ambient_mesh_background.dart';
import 'glass_surface.dart';

/// Shared auth/onboarding layout with copper glass branding.
class DtAuthShell extends StatelessWidget {
  const DtAuthShell({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
  });

  final Widget child;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      body: AmbientMeshBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.copperLight,
                          AppColors.copperPrimary,
                          AppColors.copperDeep,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.copperPrimary.withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (title != null)
                  Text(
                    title!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.osHero(context),
                  ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption(context),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                GlassSurface(
                  glowColor: AppColors.copperPrimary,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
