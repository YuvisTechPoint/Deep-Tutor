import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/book_summary.dart';
import '../../../data/repositories/book_repository.dart';
import '../../auth/providers/auth_provider.dart';

final bookRepositoryProvider = Provider(
  (ref) => BookRepository(dio: ref.watch(dioProvider)),
);

final booksListProvider = AsyncNotifierProvider.autoDispose<
    BooksListNotifier, List<BookSummary>>(BooksListNotifier.new);

class BooksListNotifier extends AutoDisposeAsyncNotifier<List<BookSummary>> {
  BookRepository get _repo => ref.read(bookRepositoryProvider);

  @override
  Future<List<BookSummary>> build() => _repo.listBooks();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.listBooks());
  }

  Future<bool> deleteBook(String bookId) async {
    final previous = state.valueOrNull;
    if (previous == null) return false;

    state = AsyncData(previous.where((b) => b.id != bookId).toList());
    try {
      await _repo.deleteBook(bookId);
      return true;
    } catch (_) {
      state = AsyncData(previous);
      return false;
    }
  }
}

final bookDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, bookId) => ref.watch(bookRepositoryProvider).getBook(bookId),
);
