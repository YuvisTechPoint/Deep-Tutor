import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/feature_identity.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/design_system/design_system.dart';
import '../../../data/models/book_summary.dart';
import '../providers/book_provider.dart';

/// Lists living books from the Book Engine with swipe-to-delete.
class BooksListScreen extends ConsumerWidget {
  const BooksListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksListProvider);
    final accent = FeatureIdentity.of(FeatureId.books).accent;

    return DtPageShell(
      title: 'Living Books',
      featureId: FeatureId.books,
      actions: [
        IconButton.filled(
          tooltip: 'New book',
          onPressed: () => _showCreateDialog(context, ref),
          style: IconButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.auto_stories_outlined),
        ),
      ],
      body: RefreshIndicator(
        color: accent,
        onRefresh: () => ref.read(booksListProvider.notifier).refresh(),
        child: AsyncValueWidget(
          value: booksAsync,
          onRetry: () => ref.invalidate(booksListProvider),
          builder: (books) {
            if (books.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.5,
                    child:
                        _EmptyBooks(onCreate: () => _showCreateDialog(context, ref)),
                  ),
                ],
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                const AiSectionHeader(
                  title: 'Your books',
                  subtitle: 'Swipe left or tap delete',
                ),
                for (var i = 0; i < books.length; i++)
                  _BookTile(book: books[i], index: i),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create a living book'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText:
                'What should this book teach? e.g. "Linear algebra for JEE"',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created != true || !context.mounted) return;

    try {
      final book = await ref.read(bookRepositoryProvider).createBook(
            userIntent: controller.text.trim(),
          );
      ref.invalidate(booksListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Started "${book.displayTitle}"')),
        );
        context.push('/books/${book.id}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
    }
  }
}

class _BookTile extends ConsumerWidget {
  const _BookTile({required this.book, required this.index});

  final BookSummary book;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = FeatureIdentity.of(FeatureId.books).accent;
    final statusColor = book.isReady ? AppColors.success : AppColors.warning;
    final subtitle = book.description.isEmpty
        ? '${book.pageCount} pages · ${book.status}'
        : book.description;

    return DtDeletableListModule(
      dismissKey: 'book-${book.id}',
      index: index,
      glowColor: accent,
      leading: ModuleIconOrb(
        icon: Icons.menu_book_rounded,
        color: accent,
      ),
      title: book.displayTitle,
      subtitle: subtitle,
      deleteTooltip: 'Delete book',
      onTap: () => context.push('/books/${book.id}'),
      onDelete: () =>
          ref.read(booksListProvider.notifier).deleteBook(book.id),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          book.status,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: statusColor,
          ),
        ),
      ),
    );
  }
}

class _EmptyBooks extends StatelessWidget {
  const _EmptyBooks({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_stories_outlined,
                size: 72, color: AppColors.accent),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No books yet',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Turn your notes, chat, or goals into an interactive living book.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create your first book'),
            ),
          ],
        ),
      ),
    );
  }
}
