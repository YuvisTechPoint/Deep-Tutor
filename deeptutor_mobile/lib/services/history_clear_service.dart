import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/books/providers/book_provider.dart';
import '../features/chat/providers/chat_provider.dart';
import '../features/chat/providers/composer_providers.dart';
import '../features/co_writer/providers/co_writer_provider.dart';
import '../features/knowledge/providers/knowledge_provider.dart';
import '../features/notifications/providers/notifications_provider.dart';
import '../features/space/providers/space_providers.dart';
import 'local_cache.dart';

/// Bulk-deletes user-visible history across chat, KBs, books, co-writer, etc.
class HistoryClearService {
  const HistoryClearService(this._ref);
  final Ref _ref;

  Future<HistoryClearResult> clearAllStoredHistory() async {
    var deleted = 0;
    var failed = 0;

    Future<void> tryDelete(Future<void> Function() fn) async {
      try {
        await fn();
        deleted++;
      } catch (_) {
        failed++;
      }
    }

    final chatRepo = _ref.read(chatRepositoryProvider);
    final sessions = await chatRepo.getSessions();
    for (final s in sessions) {
      await tryDelete(() => chatRepo.deleteSession(s.id));
    }

    final kbRepo = _ref.read(knowledgeRepositoryProvider);
    final kbs = await kbRepo.list();
    for (final kb in kbs) {
      await tryDelete(() => kbRepo.delete(kb.name));
    }

    final bookRepo = _ref.read(bookRepositoryProvider);
    final books = await bookRepo.listBooks();
    for (final b in books) {
      await tryDelete(() => bookRepo.deleteBook(b.id));
    }

    final coRepo = _ref.read(coWriterRepositoryProvider);
    final docs = await coRepo.list();
    for (final d in docs) {
      await tryDelete(() => coRepo.delete(d.id));
    }

    final nbRepo = _ref.read(notebookRepositoryProvider);
    final notebooks = await nbRepo.list();
    for (final n in notebooks) {
      await tryDelete(() => nbRepo.delete(n.id));
    }

    final notifRepo = _ref.read(notificationsRepositoryProvider);
    final notifications = await notifRepo.getNotifications();
    for (final n in notifications) {
      await tryDelete(() => notifRepo.delete(n.id));
    }

    try {
      final cache = await LocalCache.init();
      for (final ns in const [
        'chat',
        'knowledge',
        'books',
        'co_writer',
        'notifications',
        'notebook',
      ]) {
        await cache.clear(ns);
      }
    } catch (_) {}

    _invalidateLists();
    return HistoryClearResult(deleted: deleted, failed: failed);
  }

  void _invalidateLists() {
    _ref.invalidate(chatSessionsProvider);
    _ref.invalidate(knowledgeBasesProvider);
    _ref.invalidate(booksListProvider);
    _ref.invalidate(coWriterDocumentsProvider);
    _ref.invalidate(notebooksListProvider);
    _ref.read(notificationsNotifierProvider.notifier).load();
  }
}

class HistoryClearResult {
  const HistoryClearResult({required this.deleted, required this.failed});

  final int deleted;
  final int failed;

  bool get hasFailures => failed > 0;
}

final historyClearServiceProvider = Provider(
  (ref) => HistoryClearService(ref),
);
