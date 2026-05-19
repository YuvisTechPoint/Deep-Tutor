import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/async_value_widget.dart';
import '../../knowledge/providers/knowledge_provider.dart';

/// Bottom sheet listing available KBs as multi-select chips.
Future<List<String>?> showKbPickerSheet(
  BuildContext context, {
  required Set<String> selected,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      var working = Set<String>.from(selected);
      return Consumer(builder: (ctx, ref, _) {
        final kbsAsync = ref.watch(knowledgeBasesProvider);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Knowledge bases',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints:
                      BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                  child: AsyncValueWidget(
                    value: kbsAsync,
                    onRetry: () =>
                        ref.invalidate(knowledgeBasesProvider),
                    builder: (kbs) {
                      if (kbs.isEmpty) {
                        return const _EmptyKbList();
                      }
                      return StatefulBuilder(
                        builder: (ctx, setSheet) => ListView(
                          shrinkWrap: true,
                          children: [
                            for (final kb in kbs)
                              CheckboxListTile(
                                value: working.contains(kb.name),
                                title: Text(kb.title),
                                subtitle: kb.description != null
                                    ? Text(
                                        kb.description!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : null,
                                onChanged: (v) => setSheet(() {
                                  if (v == true) {
                                    working.add(kb.name);
                                  } else {
                                    working.remove(kb.name);
                                  }
                                }),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
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

class _EmptyKbList extends StatelessWidget {
  const _EmptyKbList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 32,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 8),
          const Text('No knowledge bases yet'),
          const SizedBox(height: 4),
          Text(
            'Create one from the Knowledge tab',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
