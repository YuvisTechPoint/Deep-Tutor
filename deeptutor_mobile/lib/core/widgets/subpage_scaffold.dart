import 'package:flutter/material.dart';

import '../theme/feature_identity.dart';
import 'design_system/dt_page_shell.dart';

/// Back-compat wrapper — delegates to [DtPageShell].
class SubpageScaffold extends StatelessWidget {
  const SubpageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottom,
    this.featureId,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? bottom;
  final FeatureId? featureId;

  @override
  Widget build(BuildContext context) {
    return DtPageShell(
      title: title,
      body: body,
      actions: actions,
      floatingActionButton: floatingActionButton,
      bottom: bottom,
      featureId: featureId,
      showBack: true,
    );
  }
}
