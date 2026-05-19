import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/live_session_mentor_repository.dart';
import '../data/mentor_repository.dart';

const _preferLiveMentor = bool.fromEnvironment(
  'MENTOR_LIVE',
  defaultValue: true,
);

final mentorRepositoryProvider = Provider<MentorRepository>((ref) {
  if (!_preferLiveMentor) {
    return const MockMentorRepository();
  }
  return LiveSessionMentorRepository(dio: ref.watch(dioProvider));
});

final mentorDashboardProvider = FutureProvider.autoDispose(
  (ref) async {
    try {
      return await ref.watch(mentorRepositoryProvider).dashboard();
    } catch (_) {
      if (_preferLiveMentor) {
        return const MockMentorRepository().dashboard();
      }
      rethrow;
    }
  },
);

final mentorStudentsProvider = FutureProvider.autoDispose(
  (ref) async {
    try {
      return await ref.watch(mentorRepositoryProvider).students();
    } catch (_) {
      if (_preferLiveMentor) {
        return const MockMentorRepository().students();
      }
      rethrow;
    }
  },
);

final mentorInterventionsProvider = FutureProvider.autoDispose(
  (ref) async {
    try {
      return await ref.watch(mentorRepositoryProvider).interventions();
    } catch (_) {
      if (_preferLiveMentor) {
        return const MockMentorRepository().interventions();
      }
      rethrow;
    }
  },
);

final mentorMessagesProvider = FutureProvider.autoDispose(
  (ref) async {
    try {
      return await ref.watch(mentorRepositoryProvider).messages();
    } catch (_) {
      if (_preferLiveMentor) {
        return const MockMentorRepository().messages();
      }
      rethrow;
    }
  },
);

final mentorCohortAnalyticsProvider = FutureProvider.autoDispose(
  (ref) async {
    try {
      return await ref.watch(mentorRepositoryProvider).cohortAnalytics();
    } catch (_) {
      if (_preferLiveMentor) {
        return const MockMentorRepository().cohortAnalytics();
      }
      rethrow;
    }
  },
);
