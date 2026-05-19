import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_spacing.dart';

/// Sources cited under an assistant message bubble.
class SourcesFooter extends StatelessWidget {
  const SourcesFooter({super.key, required this.sources});

  final List<Map<String, dynamic>> sources;

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (var i = 0; i < sources.length; i++)
            ActionChip(
              avatar: Icon(_iconFor(sources[i]),
                  size: 14, color: cs.onSurfaceVariant),
              label: Text(
                _label(sources[i], i),
                style: const TextStyle(fontSize: 11),
              ),
              onPressed: () => _showDetail(context, sources[i], i),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(Map<String, dynamic> source) {
    final type = (source['source_type'] ?? source['type'])?.toString() ?? '';
    return switch (type) {
      'web' || 'url' => Icons.link,
      'paper' => Icons.article_outlined,
      'kb' || 'rag' => Icons.library_books_outlined,
      _ => Icons.bookmark_outline,
    };
  }

  String _label(Map<String, dynamic> source, int index) {
    final title = source['title'] ?? source['name'] ?? source['url'];
    if (title is String && title.trim().isNotEmpty) {
      final t = title.length > 32 ? '${title.substring(0, 32)}…' : title;
      return '${index + 1}. $t';
    }
    return 'Source ${index + 1}';
  }

  void _showDetail(
    BuildContext context,
    Map<String, dynamic> source,
    int index,
  ) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final url = source['url']?.toString();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _label(source, index),
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (source['excerpt'] is String)
                  Text(
                    source['excerpt'].toString(),
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                if (source['page_number'] != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Page ${source['page_number']}',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],
                if (url != null && url.startsWith('http')) ...[
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open source'),
                    onPressed: () => launchUrl(Uri.parse(url)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
