import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/onboarding/providers/onboarding_gate_provider.dart';
import '../../services/realtime_sync.dart';

/// Runs startup side-effects: onboarding gate refresh and auth refresh on resume.
class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onAuthChanged());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(authNotifierProvider.notifier).refresh());
      unawaited(refreshOnboardingGate(ref));
      refreshAppLiveData(ProviderScope.containerOf(context));
    }
  }

  void _onAuthChanged() {
    final auth = ref.read(authNotifierProvider);
    if (auth is AuthAuthenticated) {
      unawaited(refreshOnboardingGate(ref));
    } else if (auth is AuthUnauthenticated || auth is AuthError) {
      ref.read(onboardingGateProvider.notifier).state =
          OnboardingGate.complete;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authNotifierProvider, (_, __) => _onAuthChanged());
    return widget.child;
  }
}
