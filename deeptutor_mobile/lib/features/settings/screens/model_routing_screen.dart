import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/feature_identity.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/subpage_scaffold.dart';
import '../../chat/providers/composer_providers.dart';

final _featureSurfacesProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(modelRoutingRepositoryProvider).featureSurfaces(),
);

/// Shows the LLM routing catalog and per-feature surfaces.
class ModelRoutingScreen extends ConsumerWidget {
  const ModelRoutingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(llmCatalogProvider);
    final surfacesAsync = ref.watch(_featureSurfacesProvider);

    return SubpageScaffold(
      title: 'Model routing',
      featureId: FeatureId.settings,
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
            child: Text('AVAILABLE MODELS',
                style:
                    TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
          ),
          AsyncValueWidget(
            value: catalogAsync,
            onRetry: () => ref.invalidate(llmCatalogProvider),
            builder: (models) {
              if (models.isEmpty) {
                return const ListTile(
                  title: Text('No models configured'),
                );
              }
              return Column(
                children: [
                  for (final m in models)
                    ListTile(
                      leading: const Icon(Icons.bolt),
                      title: Text(m.displayLabel),
                      subtitle: m.provider != null ? Text(m.provider!) : null,
                    ),
                ],
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
            child: Text('FEATURE SURFACES',
                style:
                    TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
          ),
          AsyncValueWidget(
            value: surfacesAsync,
            onRetry: () => ref.invalidate(_featureSurfacesProvider),
            builder: (surfaces) {
              if (surfaces.isEmpty) {
                return const ListTile(
                  title: Text('No feature surfaces declared'),
                );
              }
              return Column(
                children: [
                  for (final s in surfaces)
                    ListTile(
                      leading: const Icon(Icons.tune),
                      title: Text(s.label ?? s.id),
                      subtitle: s.preferredModel != null
                          ? Text('→ ${s.preferredModel}')
                          : null,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
