import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/career.dart';
import '../../../data/repositories/career_repository.dart';
import '../../auth/providers/auth_provider.dart';

final careerRepositoryProvider = Provider(
  (ref) => CareerRepository(dio: ref.watch(dioProvider)),
);

/// All career paths — auto-disposed so it refreshes when navigating away & back.
final careerPathsProvider =
    FutureProvider.autoDispose<CareerPathsResponse>((ref) async {
  return ref.watch(careerRepositoryProvider).getPaths();
});

/// Selected path id for the detail view.
final selectedCareerPathIdProvider = StateProvider<String?>((ref) => null);

/// Single path detail — fetched only when a path is selected.
final selectedCareerPathProvider =
    FutureProvider.autoDispose<CareerPath?>((ref) async {
  final pathId = ref.watch(selectedCareerPathIdProvider);
  if (pathId == null) return null;
  return ref.watch(careerRepositoryProvider).getPath(pathId);
});
