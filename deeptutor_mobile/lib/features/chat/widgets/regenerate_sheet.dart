import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../data/capability_catalog.dart';
import '../providers/chat_provider.dart';

/// Shows a sheet to optionally override capability/tools/KBs before regenerating.
Future<ChatComposerOverrides?> showRegenerateSheet(
  BuildContext context, {
  required ChatComposerOverrides current,
}) {
  return showModalBottomSheet<ChatComposerOverrides>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      var working = current;
      return StatefulBuilder(builder: (ctx, setSheet) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Regenerate',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Override the capability or tools before re-running this turn.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text('Capability'),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final c in CapabilityCatalog.capabilities)
                        ChoiceChip(
                          label: Text(c.label),
                          avatar: Icon(c.icon, size: 14),
                          selected: working.capability == c.id,
                          onSelected: (_) => setSheet(
                              () => working = working.copyWith(capability: c.id)),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text('Tools'),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final t in CapabilityCatalog.tools)
                        FilterChip(
                          label: Text(t.label),
                          avatar: Icon(t.icon, size: 14),
                          selected: working.tools.contains(t.id),
                          onSelected: (v) => setSheet(() {
                            final next = [...working.tools];
                            if (v) {
                              next.add(t.id);
                            } else {
                              next.remove(t.id);
                            }
                            working = working.copyWith(tools: next);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(null),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Regenerate'),
                        onPressed: () =>
                            Navigator.of(ctx).pop(working),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      });
    },
  );
}
