import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/coding_practice_repository.dart';
import '../../auth/providers/auth_provider.dart';

final codingPracticeRepositoryProvider = Provider(
  (ref) => CodingPracticeRepository(dio: ref.watch(dioProvider)),
);

final toolchainsProvider =
    FutureProvider.autoDispose<List<Toolchain>>(
  (ref) => ref.watch(codingPracticeRepositoryProvider).toolchains(),
);
