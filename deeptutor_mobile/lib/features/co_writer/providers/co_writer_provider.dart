import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/co_writer_repository.dart';
import '../../auth/providers/auth_provider.dart';

final coWriterRepositoryProvider = Provider(
  (ref) => CoWriterRepository(dio: ref.watch(dioProvider)),
);

final coWriterDocumentsProvider = AsyncNotifierProvider.autoDispose<
    CoWriterDocumentsNotifier, List<CoWriterDocument>>(
  CoWriterDocumentsNotifier.new,
);

class CoWriterDocumentsNotifier
    extends AutoDisposeAsyncNotifier<List<CoWriterDocument>> {
  CoWriterRepository get _repo => ref.read(coWriterRepositoryProvider);

  @override
  Future<List<CoWriterDocument>> build() => _repo.list();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.list());
  }

  Future<bool> deleteDocument(String id) async {
    final previous = state.valueOrNull;
    if (previous == null) return false;

    state = AsyncData(previous.where((d) => d.id != id).toList());
    try {
      await _repo.delete(id);
      return true;
    } catch (_) {
      state = AsyncData(previous);
      return false;
    }
  }
}
