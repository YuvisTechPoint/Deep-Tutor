import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/system_repository.dart';
import '../../auth/providers/auth_provider.dart';

final systemRepositoryProvider = Provider(
  (ref) => SystemRepository(dio: ref.watch(dioProvider)),
);

final systemStatusProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.watch(systemRepositoryProvider).getStatus(),
);
