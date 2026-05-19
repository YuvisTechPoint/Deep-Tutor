import 'package:flutter/material.dart';

import '../data/capability_catalog.dart';

/// Bottom sheet that lets the user toggle Level-1 tools for the next turn.
Future<List<String>?> showToolsPickerSheet(
  BuildContext context, {
  required Set<String> selected,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      var working = Set<String>.from(selected);
      return StatefulBuilder(builder: (ctx, setSheet) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tools',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Pick which built-in tools the model may call.',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in CapabilityCatalog.tools)
                      FilterChip(
                        label: Text(t.label),
                        avatar: Icon(t.icon, size: 16),
                        selected: working.contains(t.id),
                        onSelected: (v) => setSheet(() {
                          if (v) {
                            working.add(t.id);
                          } else {
                            working.remove(t.id);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.of(ctx).pop(working.toList(growable: false)),
                    child: const Text('Apply'),
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
