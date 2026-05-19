import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_token_store.dart';
import '../../../data/models/auth_status.dart';
import '../../../data/repositories/auth_repository.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.current);

/// True when using "Skip login" — no Bearer token; works with AUTH_ENABLED=false APIs.
final demoModeProvider = StateProvider<bool>((ref) => false);

final secureTokenStoreProvider = Provider<SecureTokenStore>(
  (_) => SecureTokenStore(),
);

final authTokenProvider = StateProvider<String?>((ref) => null);

/// Stable [Dio] — token is read per-request so auth state changes never recreate it.
final dioProvider = Provider((ref) {
  final config = ref.watch(appConfigProvider);
  return createDio(
    config,
    tokenReader: () => ref.read(authTokenProvider),
    demoModeReader: () => ref.read(demoModeProvider),
  );
});

final authRepositoryProvider = Provider((ref) => AuthRepository(
      dio: ref.watch(dioProvider),
      tokenStore: ref.read(secureTokenStoreProvider),
    ));

// ── Auth state ────────────────────────────────────────────────────────────────

/// Authentication state visible to the entire app.
sealed class AuthState {
  const AuthState();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({required this.status, this.isDemo = false});
  final AuthStatus status;
  final bool isDemo;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.authEnabled = true});
  final bool authEnabled;
}

class AuthError extends AuthState {
  const AuthError({required this.message});
  final String message;
}

// ── Auth notifier ─────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo, this._tokenStore, this._ref)
      : super(const AuthUnauthenticated()) {
    unawaited(_init());
    _startBootstrapWatchdog();
  }

  final AuthRepository _repo;
  final SecureTokenStore _tokenStore;
  final Ref _ref;
  Timer? _watchdog;

  static const _storageTimeout = Duration(milliseconds: 800);
  static const _statusTimeout = Duration(seconds: 3);

  void _startBootstrapWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 3), () {
      if (state is AuthLoading) {
        state = const AuthUnauthenticated();
      }
    });
  }

  void _clearWatchdog() => _watchdog?.cancel();

  Future<void> _init() async {
    if (await _tokenStore.readDemoMode()) {
      await _restoreLocalDemo();
      _clearWatchdog();
      return;
    }

    String? savedToken;
    try {
      savedToken = await _tokenStore
          .readToken()
          .timeout(_storageTimeout, onTimeout: () => null);
    } catch (_) {}

    if (savedToken != null && savedToken.isNotEmpty) {
      _ref.read(authTokenProvider.notifier).state = savedToken;
      _ref.read(demoModeProvider.notifier).state = false;
      state = const AuthLoading();
      await _resolveFromServer();
      _clearWatchdog();
      return;
    }

    state = const AuthUnauthenticated();
    _clearWatchdog();
    unawaited(_resolveFromServer(silent: true));
  }

  Future<void> _restoreLocalDemo() async {
    final cached = await _tokenStore.readUser();
    final username =
        cached.username?.trim().isNotEmpty == true ? cached.username! : 'Guest';
    _ref.read(demoModeProvider.notifier).state = true;
    _ref.read(authTokenProvider.notifier).state = null;
    state = AuthAuthenticated(
      isDemo: true,
      status: AuthStatus(
        authEnabled: false,
        userId: 'demo-local',
        username: username,
        role: cached.role ?? 'learner',
        authenticated: true,
      ),
    );
  }

  Future<void> _resolveFromServer({bool silent = false}) async {
    if (_ref.read(demoModeProvider)) return;

    try {
      final status = await _repo.getStatus(timeout: _statusTimeout);

      if (!status.authEnabled) {
        state = AuthAuthenticated(status: status);
        return;
      }

      if (status.authenticated) {
        state = AuthAuthenticated(status: status);
      } else {
        await _tokenStore.clearAll();
        _ref.read(authTokenProvider.notifier).state = null;
        state = AuthUnauthenticated(authEnabled: status.authEnabled);
      }
    } catch (_) {
      if (silent && state is AuthUnauthenticated) return;

      if (_ref.read(demoModeProvider)) return;

      final hasToken = _ref.read(authTokenProvider) != null;
      if (hasToken) {
        await _tokenStore.deleteToken();
        _ref.read(authTokenProvider.notifier).state = null;
      }
      if (state is! AuthAuthenticated) {
        state = const AuthUnauthenticated();
      }
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    await _exitDemoMode();
    state = const AuthLoading();
    _startBootstrapWatchdog();
    try {
      final resp = await _repo.login(username: username, password: password);
      if (resp.accessToken != null) {
        _ref.read(authTokenProvider.notifier).state = resp.accessToken;
      }
      final status = await _repo.getStatus();
      state = AuthAuthenticated(status: status);
      _clearWatchdog();
    } on Exception catch (e) {
      state = AuthError(message: e.toString());
      _clearWatchdog();
    }
  }

  Future<void> register({
    required String username,
    required String password,
  }) async {
    await _exitDemoMode();
    state = const AuthLoading();
    _startBootstrapWatchdog();
    try {
      await _repo.register(username: username, password: password);
      await login(username: username, password: password);
    } on Exception catch (e) {
      state = AuthError(message: e.toString());
      _clearWatchdog();
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    await _exitDemoMode();
    state = const AuthUnauthenticated();
  }

  /// Bypass login — always succeeds and enters the app.
  ///
  /// 1. If the API has auth disabled, use the live server without a token.
  /// 2. Otherwise try common demo credentials against the server.
  /// 3. Fall back to a persisted local demo session (no Bearer header).
  Future<void> skipAuth({String? username}) async {
    state = const AuthLoading();
    _startBootstrapWatchdog();

    final displayName =
        username?.trim().isNotEmpty == true ? username!.trim() : 'Guest';

    try {
      final status = await _repo.getStatus(timeout: _statusTimeout);
      if (!status.authEnabled) {
        await _exitDemoMode();
        await _tokenStore.deleteToken();
        _ref.read(authTokenProvider.notifier).state = null;
        state = AuthAuthenticated(
          status: AuthStatus(
            authEnabled: false,
            userId: status.userId ?? 'local',
            username: displayName,
            role: status.role ?? 'admin',
            authenticated: true,
          ),
        );
        _clearWatchdog();
        return;
      }
    } catch (_) {}

    final attempts = <(String, String)>[
      (displayName, 'demo'),
      ('demo', 'demo'),
      ('guest', 'guest'),
      ('admin', 'admin'),
    ];

    for (final (user, pass) in attempts) {
      try {
        await _exitDemoMode();
        final resp = await _repo.login(username: user, password: pass);
        if (resp.accessToken != null) {
          _ref.read(authTokenProvider.notifier).state = resp.accessToken;
        }
        final status = await _repo.getStatus(timeout: _statusTimeout);
        state = AuthAuthenticated(status: status);
        _clearWatchdog();
        return;
      } catch (_) {}
    }

    await _enterLocalDemo(displayName);
    _clearWatchdog();
  }

  Future<void> _enterLocalDemo(String username) async {
    await _tokenStore.setDemoMode(true);
    await _tokenStore.deleteToken();
    await _tokenStore.writeUser(username: username, role: 'learner');
    _ref.read(demoModeProvider.notifier).state = true;
    _ref.read(authTokenProvider.notifier).state = null;
    state = AuthAuthenticated(
      isDemo: true,
      status: AuthStatus(
        authEnabled: false,
        userId: 'demo-local',
        username: username,
        role: 'learner',
        authenticated: true,
      ),
    );
  }

  Future<void> _exitDemoMode() async {
    _ref.read(demoModeProvider.notifier).state = false;
    await _tokenStore.setDemoMode(false);
  }

  Future<void> refresh() => _init();

  @override
  void dispose() {
    _watchdog?.cancel();
    super.dispose();
  }
}

/// Uses [ref.read] for dependencies so token updates never recreate this notifier.
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.read(authRepositoryProvider),
    ref.read(secureTokenStoreProvider),
    ref,
  );
});
