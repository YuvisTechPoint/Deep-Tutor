import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/subpage_scaffold.dart';
import '../providers/billing_provider.dart';

/// Razorpay subscription screen.
///
/// Reads `--dart-define=RAZORPAY_KEY_ID=<keyId>` for the client key (the secret
/// stays on the server). When that key is absent or the backend says Razorpay
/// isn't configured, this screen shows a read-only "Configure to enable" state.
class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  static const _kRazorpayKeyId =
      String.fromEnvironment('RAZORPAY_KEY_ID');

  Razorpay? _razorpay;
  String? _pendingOrderId;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && _kRazorpayKeyId.isNotEmpty) {
      _razorpay = Razorpay()
        ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess)
        ..on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError)
        ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    }
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  Future<void> _startPlan(String planId, String billingPeriod) async {
    if (_razorpay == null) {
      _showSnack('Set --dart-define=RAZORPAY_KEY_ID to enable checkout.');
      return;
    }
    setState(() => _processing = true);
    try {
      final amountPaise =
          _amountForPlan(planId, billingPeriod);
      if (amountPaise == null) {
        _showSnack('Unknown plan/billing combination');
        return;
      }
      final order = await ref.read(paymentsRepositoryProvider).createOrder(
            amountPaise: amountPaise,
            currency: 'INR',
            planId: planId,
            billingPeriod: billingPeriod,
          );
      _pendingOrderId = order.orderId;
      _razorpay!.open({
        'key': _kRazorpayKeyId,
        'amount': order.amount,
        'currency': order.currency,
        'order_id': order.orderId,
        'name': 'DeepTutor',
        'description': '$planId · $billingPeriod',
        'prefill': const {},
      });
    } catch (e) {
      _showSnack('Failed to start checkout: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse r) async {
    try {
      await ref.read(paymentsRepositoryProvider).verify(
            orderId: r.orderId ?? _pendingOrderId ?? '',
            paymentId: r.paymentId ?? '',
            signature: r.signature ?? '',
          );
      ref.invalidate(subscriptionProvider);
      _showSnack('Payment verified.');
    } catch (e) {
      _showSnack('Verification failed: $e');
    }
  }

  void _onPaymentError(PaymentFailureResponse r) {
    _showSnack('Payment failed: ${r.message ?? r.code}');
  }

  void _onExternalWallet(ExternalWalletResponse r) {
    _showSnack('External wallet: ${r.walletName ?? "unknown"}');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  int? _amountForPlan(String planId, String billingPeriod) {
    // Approximate amounts in paise; backend enforces catalog validation.
    if (planId == 'pro' && billingPeriod == 'monthly') return 49900;
    if (planId == 'pro' && billingPeriod == 'annual') return 499000;
    if (planId == 'team' && billingPeriod == 'monthly') return 199900;
    if (planId == 'team' && billingPeriod == 'annual') return 1999000;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(razorpayStatusProvider);
    final subAsync = ref.watch(subscriptionProvider);

    return SubpageScaffold(
      title: 'Billing',
      body: AsyncValueWidget(
        value: statusAsync,
        onRetry: () => ref.invalidate(razorpayStatusProvider),
        builder: (status) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (!status.configured)
                Card(
                  color:
                      Theme.of(context).colorScheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_outlined),
                    title: const Text('Razorpay not configured'),
                    subtitle: const Text(
                      'Backend is missing RAZORPAY_KEY_ID/SECRET; UI is read-only.',
                    ),
                  ),
                ),
              if (_kRazorpayKeyId.isEmpty)
                Card(
                  color: Theme.of(context)
                      .colorScheme
                      .secondaryContainer,
                  child: const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Client key not set'),
                    subtitle: Text(
                      'Pass --dart-define=RAZORPAY_KEY_ID=<key_id> at build time.',
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              AsyncValueWidget(
                value: subAsync,
                onRetry: () => ref.invalidate(subscriptionProvider),
                builder: (sub) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.workspace_premium_outlined),
                    title:
                        Text('Current plan: ${sub.planId.toUpperCase()}'),
                    subtitle: sub.billingPeriod != null
                        ? Text('Billing: ${sub.billingPeriod}')
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Plans',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              _PlanCard(
                title: 'Pro',
                priceLabel: '₹499 / month · ₹4,990 / year',
                onMonthly: !status.configured || _processing
                    ? null
                    : () => _startPlan('pro', 'monthly'),
                onAnnual: !status.configured || _processing
                    ? null
                    : () => _startPlan('pro', 'annual'),
              ),
              const SizedBox(height: AppSpacing.sm),
              _PlanCard(
                title: 'Team',
                priceLabel: '₹1,999 / month · ₹19,990 / year',
                onMonthly: !status.configured || _processing
                    ? null
                    : () => _startPlan('team', 'monthly'),
                onAnnual: !status.configured || _processing
                    ? null
                    : () => _startPlan('team', 'annual'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.priceLabel,
    required this.onMonthly,
    required this.onAnnual,
  });

  final String title;
  final String priceLabel;
  final VoidCallback? onMonthly;
  final VoidCallback? onAnnual;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(priceLabel, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                FilledButton(
                  onPressed: onMonthly,
                  child: const Text('Monthly'),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton.tonal(
                  onPressed: onAnnual,
                  child: const Text('Annual'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
