import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/learning_plan_repository.dart';
import '../../auth/providers/auth_provider.dart';

final learningPlanRepositoryProvider = Provider(
  (ref) => LearningPlanRepository(dio: ref.watch(dioProvider)),
);

final learningPlanProvider =
    FutureProvider.autoDispose<LearningPlanSnapshot>(
  (ref) => ref.watch(learningPlanRepositoryProvider).get(),
);
