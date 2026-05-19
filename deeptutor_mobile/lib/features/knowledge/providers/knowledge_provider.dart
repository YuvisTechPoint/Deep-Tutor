import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/knowledge_base.dart';
import '../../../data/repositories/knowledge_repository.dart';
import '../../chat/providers/composer_providers.dart';

final knowledgeBasesProvider = AsyncNotifierProvider.autoDispose<
    KnowledgeBasesNotifier, List<KnowledgeBaseSummary>>(KnowledgeBasesNotifier.new);

class KnowledgeBasesNotifier
    extends AutoDisposeAsyncNotifier<List<KnowledgeBaseSummary>> {
  KnowledgeRepository get _repo => ref.read(knowledgeRepositoryProvider);

  @override
  Future<List<KnowledgeBaseSummary>> build() => _repo.list();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.list());
  }

  Future<bool> deleteBase(String name) async {
    final previous = state.valueOrNull;
    if (previous == null) return false;

    state = AsyncData(previous.where((kb) => kb.name != name).toList());
    try {
      await _repo.delete(name);
      return true;
    } catch (_) {
      state = AsyncData(previous);
      return false;
    }
  }
}
