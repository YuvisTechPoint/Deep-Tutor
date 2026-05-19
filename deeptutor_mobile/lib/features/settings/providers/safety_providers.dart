import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/safety_repository.dart';
import '../../auth/providers/auth_provider.dart';

final safetyRepositoryProvider = Provider(
  (ref) => SafetyRepository(dio: ref.watch(dioProvider)),
);
