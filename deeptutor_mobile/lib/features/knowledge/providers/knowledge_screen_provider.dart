import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/knowledge_base.dart';
import '../../chat/providers/composer_providers.dart';

/// Files inside a single KB.
final knowledgeBaseFilesProvider =
    FutureProvider.autoDispose.family<List<KnowledgeBaseFile>, String>(
  (ref, name) =>
      ref.watch(knowledgeRepositoryProvider).files(name),
);

/// Current indexing progress snapshot (polled).
final knowledgeBaseProgressProvider =
    FutureProvider.autoDispose.family<KnowledgeBaseProgress, String>(
  (ref, name) => ref.watch(knowledgeRepositoryProvider).progress(name),
);

/// Supported file extensions from the backend.
final supportedFileTypesProvider =
    FutureProvider.autoDispose<List<String>>(
  (ref) => ref.watch(knowledgeRepositoryProvider).supportedFileTypes(),
);
