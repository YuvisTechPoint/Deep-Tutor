import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/payments_repository.dart';
import '../../auth/providers/auth_provider.dart';

final paymentsRepositoryProvider = Provider(
  (ref) => PaymentsRepository(dio: ref.watch(dioProvider)),
);

final razorpayStatusProvider =
    FutureProvider.autoDispose<RazorpayStatus>(
  (ref) => ref.watch(paymentsRepositoryProvider).status(),
);

final subscriptionProvider =
    FutureProvider.autoDispose<SubscriptionInfo>(
  (ref) => ref.watch(paymentsRepositoryProvider).subscription(),
);
