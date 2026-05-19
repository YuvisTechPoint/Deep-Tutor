import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/attachments_repository.dart';
import '../../../data/repositories/knowledge_repository.dart';
import '../../../data/repositories/model_routing_repository.dart';
import '../../../data/repositories/skills_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../knowledge/providers/knowledge_provider.dart';

final knowledgeRepositoryProvider = Provider(
  (ref) => KnowledgeRepository(dio: ref.watch(dioProvider)),
);

final skillsRepositoryProvider = Provider(
  (ref) => SkillsRepository(dio: ref.watch(dioProvider)),
);

final modelRoutingRepositoryProvider = Provider(
  (ref) => ModelRoutingRepository(dio: ref.watch(dioProvider)),
);

final attachmentsRepositoryProvider = Provider(
  (ref) => AttachmentsRepository(
    dio: ref.watch(dioProvider),
    baseUrl: ref.watch(appConfigProvider).apiBase,
  ),
);

final skillsListProvider =
    FutureProvider.autoDispose<List<SkillSummary>>(
  (ref) => ref.watch(skillsRepositoryProvider).list(),
);

final llmCatalogProvider =
    FutureProvider.autoDispose<List<LlmOption>>(
  (ref) => ref.watch(modelRoutingRepositoryProvider).catalog(),
);
