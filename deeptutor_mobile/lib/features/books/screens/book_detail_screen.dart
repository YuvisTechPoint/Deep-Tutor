import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/subpage_scaffold.dart';
import '../providers/book_provider.dart';

/// Read-only book detail (spine + pages summary).
class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, required this.bookId});
  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(bookDetailProvider(bookId));

    return SubpageScaffold(
      title: 'Book',
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(bookDetailProvider(bookId)),
        child: AsyncValueWidget(
          value: detailAsync,
          onRetry: () => ref.invalidate(bookDetailProvider(bookId)),
          builder: (data) {
            final book = data['book'] as Map<String, dynamic>? ?? {};
            final pages = data['pages'] as List<dynamic>? ?? [];
            final title = (book['title'] as String?)?.trim();
            final description = (book['description'] as String?) ?? '';
            final status = (book['status'] as String?) ?? 'draft';

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  (title == null || title.isEmpty) ? 'Untitled book' : title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.xs),
                Chip(label: Text(status)),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(description),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Pages (${pages.length})',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (pages.isEmpty)
                  Text(
                    'No pages compiled yet. Continue setup in the web admin or wait for generation to finish.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  ...pages.map((p) {
                    final page = p as Map<String, dynamic>;
                    final pid = (page['id'] ?? page['page_id'] ?? '')
                        .toString();
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        title: Text(
                          (page['title'] as String?)?.trim().isNotEmpty == true
                              ? page['title'] as String
                              : 'Page $pid',
                        ),
                        subtitle: Text(
                          (page['status'] as String?) ?? 'pending',
                        ),
                        leading: const Icon(Icons.article_outlined),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: pid.isEmpty
                            ? null
                            : () => context
                                .push('/books/$bookId/pages/$pid'),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}
