import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/dio_recruiter_repository.dart';
import '../data/recruiter_repository.dart';

const _preferLiveRecruiter = bool.fromEnvironment(
  'RECRUITER_LIVE',
  defaultValue: true,
);

final recruiterRepositoryProvider = Provider<RecruiterRepository>((ref) {
  if (!_preferLiveRecruiter) {
    return const MockRecruiterRepository();
  }
  return DioRecruiterRepository(dio: ref.watch(dioProvider));
});

final recruiterShortlistsProvider = FutureProvider.autoDispose(
  (ref) async {
    try {
      return await ref.watch(recruiterRepositoryProvider).shortlists();
    } catch (_) {
      if (_preferLiveRecruiter) {
        return const MockRecruiterRepository().shortlists();
      }
      rethrow;
    }
  },
);

class RecruiterSearchQuery {
  const RecruiterSearchQuery({
    this.query = '',
    this.skills = const [],
    this.minMatch = 0,
  });

  final String query;
  final List<String> skills;
  final double minMatch;
}

final recruiterSearchQueryProvider =
    StateProvider<RecruiterSearchQuery>((_) => const RecruiterSearchQuery());

final recruiterSearchProvider =
    FutureProvider.autoDispose<List<RecruiterCandidate>>((ref) {
  final q = ref.watch(recruiterSearchQueryProvider);
  return ref.watch(recruiterRepositoryProvider).search(
        query: q.query,
        skills: q.skills,
        minMatch: q.minMatch,
      );
});
