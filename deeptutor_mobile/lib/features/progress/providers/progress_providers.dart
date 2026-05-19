import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/achievements_repository.dart';
import '../../../data/repositories/analytics_repository.dart';
import '../../auth/providers/auth_provider.dart';

final analyticsRepositoryProvider = Provider(
  (ref) => AnalyticsRepository(dio: ref.watch(dioProvider)),
);

final achievementsRepositoryProvider = Provider(
  (ref) => AchievementsRepository(dio: ref.watch(dioProvider)),
);

final analyticsSummaryProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(analyticsRepositoryProvider).summary(),
);

final xpTrendProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(analyticsRepositoryProvider).xpTrend(),
);

final topicMasteryProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(analyticsRepositoryProvider).topicMastery(),
);

final weakAreasProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(analyticsRepositoryProvider).weakAreas(),
);

final timeDistributionProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(analyticsRepositoryProvider).timeDistribution(),
);

final achievementsListProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(achievementsRepositoryProvider).list(),
);

final leaderboardProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(achievementsRepositoryProvider).leaderboard(),
);
