import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/memory_repository.dart';
import '../../../data/repositories/notebook_repository.dart';
import '../../../data/repositories/question_notebook_repository.dart';
import '../../auth/providers/auth_provider.dart';

final notebookRepositoryProvider = Provider(
  (ref) => NotebookRepository(dio: ref.watch(dioProvider)),
);

final memoryRepositoryProvider = Provider(
  (ref) => MemoryRepository(dio: ref.watch(dioProvider)),
);

final questionNotebookRepositoryProvider = Provider(
  (ref) => QuestionNotebookRepository(dio: ref.watch(dioProvider)),
);

final notebooksListProvider =
    FutureProvider.autoDispose<List<NotebookSummary>>(
  (ref) => ref.watch(notebookRepositoryProvider).list(),
);

final memorySnapshotProvider =
    FutureProvider.autoDispose<MemorySnapshot>(
  (ref) => ref.watch(memoryRepositoryProvider).get(),
);

final questionEntriesProvider =
    FutureProvider.autoDispose<List<QuestionNotebookEntry>>(
  (ref) => ref.watch(questionNotebookRepositoryProvider).entries(),
);
