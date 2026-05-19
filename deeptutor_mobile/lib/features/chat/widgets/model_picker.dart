import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/async_value_widget.dart';
import '../providers/composer_providers.dart';

/// Lets the user pick a (provider, model) pair from the routing catalog.
Future<({String? provider, String? model})?> showModelPickerSheet(
  BuildContext context, {
  required String? selectedModel,
}) {
  return showModalBottomSheet<({String? provider, String? model})>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return Consumer(builder: (ctx, ref, _) {
        final llmsAsync = ref.watch(llmCatalogProvider);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Model',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                  child: AsyncValueWidget(
                    value: llmsAsync,
                    onRetry: () => ref.invalidate(llmCatalogProvider),
                    builder: (models) {
                      if (models.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No models configured. Defaulting to backend selection.',
                            style: Theme.of(ctx).textTheme.bodyMedium,
                          ),
                        );
                      }
                      return ListView(
                        shrinkWrap: true,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.auto_awesome),
                            title: const Text('Auto (server default)'),
                            trailing: selectedModel == null
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.green)
                                : null,
                            onTap: () => Navigator.of(ctx)
                                .pop((provider: null, model: null)),
                          ),
                          const Divider(height: 1),
                          for (final m in models)
                            ListTile(
                              leading: const Icon(Icons.bolt),
                              title: Text(m.displayLabel),
                              subtitle: m.provider != null
                                  ? Text(m.provider!)
                                  : null,
                              trailing: m.modelId == selectedModel
                                  ? const Icon(Icons.check_rounded,
                                      color: Colors.green)
                                  : null,
                              onTap: () => Navigator.of(ctx).pop(
                                (provider: m.provider, model: m.modelId),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      });
    },
  );
}
