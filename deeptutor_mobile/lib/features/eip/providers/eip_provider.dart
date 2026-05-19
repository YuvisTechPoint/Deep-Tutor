import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/achievements_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../auth/providers/auth_provider.dart' show AuthAuthenticated, authNotifierProvider, dioProvider;
import '../data/dio_eip_repository.dart';
import '../data/eip_repository.dart';

const _preferLiveEip = bool.fromEnvironment(
  'EIP_LIVE',
  defaultValue: true,
);

final eipRepositoryProvider = Provider<EipRepository>((ref) {
  if (!_preferLiveEip) {
    return MockEipRepository();
  }
  final auth = ref.watch(authNotifierProvider);
  final username = switch (auth) {
    AuthAuthenticated(:final status) => status.username ?? 'learner',
    _ => 'learner',
  };
  return DioEipRepository(
    profileRepo: ProfileRepository(dio: ref.watch(dioProvider)),
    achievementsRepo:
        AchievementsRepository(dio: ref.watch(dioProvider)),
    username: username,
  );
});

final myEipProfileProvider = FutureProvider.autoDispose(
  (ref) async {
    try {
      return await ref.watch(eipRepositoryProvider).myProfile();
    } catch (_) {
      if (_preferLiveEip) {
        return MockEipRepository().myProfile();
      }
      rethrow;
    }
  },
);

final eipPublicProfileProvider =
    FutureProvider.autoDispose.family<EipProfile, String>(
  (ref, slug) async {
    try {
      return await ref.watch(eipRepositoryProvider).publicProfile(slug);
    } catch (_) {
      if (_preferLiveEip) {
        return MockEipRepository().publicProfile(slug);
      }
      rethrow;
    }
  },
);
