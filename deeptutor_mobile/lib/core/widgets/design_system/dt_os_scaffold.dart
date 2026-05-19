import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import 'ambient_mesh_background.dart';

/// Transparent OS scaffold with ambient mesh and dock clearance.
class DtOsScaffold extends StatelessWidget {
  const DtOsScaffold({
    super.key,
    required this.body,
    this.floatingActionButton,
    this.extendBody = true,
    this.bottomPadding = true,
  });

  final Widget body;
  final Widget? floatingActionButton;
  final bool extendBody;
  final bool bottomPadding;

  @override
  Widget build(BuildContext context) {
    final bottom =
        bottomPadding ? AppSpacing.shellBottomInset(context) : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: extendBody,
      floatingActionButton: floatingActionButton,
      body: AmbientMeshBackground(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: body,
        ),
      ),
    );
  }
}
