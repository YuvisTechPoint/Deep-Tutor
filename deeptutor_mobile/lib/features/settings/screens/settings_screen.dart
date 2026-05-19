import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/feature_identity.dart';
import '../../../core/widgets/design_system/design_system.dart';
import '../../../data/repositories/settings_repository.dart';
import '../providers/system_status_provider.dart';
import '../../../services/biometric_lock.dart';
import '../../../services/history_clear_service.dart';
import '../../../services/telemetry.dart';
import '../../../core/config/app_config.dart';
import '../../../navigation/router.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/safety_settings.dart';

// ── Theme mode provider (persisted locally via SharedPreferences) ─────────────

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme_mode');
    state = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }
}

final settingsRepositoryProvider = Provider(
  (ref) => SettingsRepository(dio: ref.watch(dioProvider)),
);

// ── Language provider (synced to POST /api/v1/settings/language) ─────────────

final languageProvider =
    StateNotifierProvider<LanguageNotifier, String>((ref) {
  return LanguageNotifier(ref.watch(settingsRepositoryProvider));
});

class LanguageNotifier extends StateNotifier<String> {
  LanguageNotifier(this._repo) : super('en') {
    _load();
  }

  final SettingsRepository _repo;

  Future<void> _load() async {
    try {
      state = await _repo.getLanguage();
    } catch (_) {}
  }

  Future<void> setLanguage(String code) async {
    state = code;
    try {
      await _repo.setLanguage(code);
    } catch (_) {}
  }
}

// ── Local notification preference (no server API in phase 1) ─────────────────

final notificationsEnabledProvider =
    StateNotifierProvider<NotificationsPrefNotifier, bool>((ref) {
  return NotificationsPrefNotifier();
});

class NotificationsPrefNotifier extends StateNotifier<bool> {
  NotificationsPrefNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('notifications_enabled') ?? true;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

/// App settings screen — language, theme, account, about.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _languages = [
    ('en', 'English'),
    ('hi', 'हिन्दी (Hindi)'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(languageProvider);
    final notificationsOn = ref.watch(notificationsEnabledProvider);
    final langLabel = _languages
        .firstWhere((l) => l.$1 == language, orElse: () => ('en', 'English'))
        .$2;

    return DtPageShell(
      title: 'Control Center',
      featureId: FeatureId.settings,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const DtModuleHeader(featureId: FeatureId.settings),
          const SizedBox(height: AppSpacing.lg),
          Text('Appearance', style: AppTextStyles.osSectionLabel(context)),
          const SizedBox(height: AppSpacing.sm),
          Text('Theme', style: AppTextStyles.moduleTitle(context)),
          const SizedBox(height: AppSpacing.sm),
          DtSegmentedControl<ThemeMode>(
            segments: const [ThemeMode.dark, ThemeMode.light, ThemeMode.system],
            selected: themeMode,
            labelBuilder: (m) => switch (m) {
              ThemeMode.dark => 'Dark',
              ThemeMode.light => 'Light',
              _ => 'Auto',
            },
            onChanged: (m) => ref.read(themeModeProvider.notifier).setMode(m),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Language', style: AppTextStyles.moduleTitle(context)),
          const SizedBox(height: AppSpacing.sm),
          DtSegmentedControl<String>(
            segments: _languages.map((l) => l.$1).toList(),
            selected: language,
            labelBuilder: (code) =>
                _languages.firstWhere((l) => l.$1 == code).$2,
            onChanged: (code) =>
                ref.read(languageProvider.notifier).setLanguage(code),
          ),
          SizedBox(height: AppSpacing.sectionGapFor(context)),
          Text('Workspace', style: AppTextStyles.osSectionLabel(context)),
          const SizedBox(height: AppSpacing.sm),
          DtControlTile(
            icon: Icons.person_outline,
            title: 'Profile',
            subtitle: 'Learning identity',
            onTap: () => context.push(AppRoutes.profile),
          ),
          DtControlTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: langLabel,
            trailing: DtGlowToggle(
              value: notificationsOn,
              onChanged: (v) => ref
                  .read(notificationsEnabledProvider.notifier)
                  .setEnabled(v),
            ),
          ),
          DtControlTile(
            icon: Icons.shield_outlined,
            title: 'Safety screening',
            subtitle: 'Pre-check messages before send',
            trailing: DtGlowToggle(
              value: ref.watch(safetyEnabledProvider),
              onChanged: (v) =>
                  ref.read(safetyEnabledProvider.notifier).set(v),
            ),
          ),
          DtControlTile(
            icon: Icons.fingerprint,
            title: 'Biometric unlock',
            subtitle: 'Fingerprint or device PIN',
            trailing: DtGlowToggle(
              value: ref.watch(biometricEnabledProvider),
              onChanged: (v) =>
                  ref.read(biometricEnabledProvider.notifier).set(v),
            ),
          ),
          DtControlTile(
            icon: Icons.analytics_outlined,
            title: 'Usage analytics',
            subtitle: 'Help improve DeepTutor',
            trailing: DtGlowToggle(
              value: ref.watch(telemetryEnabledProvider),
              onChanged: (v) =>
                  ref.read(telemetryEnabledProvider.notifier).set(v),
            ),
          ),
          DtControlTile(
            icon: Icons.delete_sweep_outlined,
            title: 'Clear stored history',
            subtitle: 'Chats, books, knowledge bases, documents',
            onTap: () => _confirmClearHistory(context, ref),
          ),
          SizedBox(height: AppSpacing.sectionGapFor(context)),
          Text('AI & Integrations', style: AppTextStyles.osSectionLabel(context)),
          const SizedBox(height: AppSpacing.sm),
          const _SystemStatusTile(),
          DtControlTile(
            icon: Icons.bolt,
            title: 'Model routing',
            subtitle: 'LLM catalog and surfaces',
            onTap: () => context.push('/settings/model-routing'),
          ),
          DtControlTile(
            icon: Icons.tune,
            title: 'Catalog settings',
            subtitle: 'Server configuration',
            onTap: () => context.push('/settings/advanced'),
          ),
          DtControlTile(
            icon: Icons.credit_card,
            title: 'Billing',
            subtitle: 'Subscription',
            onTap: () => context.push('/billing'),
          ),
          SizedBox(height: AppSpacing.sectionGapFor(context)),
          Text('Portals', style: AppTextStyles.osSectionLabel(context)),
          const SizedBox(height: AppSpacing.sm),
          DtControlTile(
            icon: Icons.school_outlined,
            title: 'Mentor portal',
            onTap: () => context.push(AppRoutes.mentor),
          ),
          DtControlTile(
            icon: Icons.work_outline,
            title: 'Recruiter portal',
            onTap: () => context.push(AppRoutes.recruiter),
          ),
          DtControlTile(
            icon: Icons.badge_outlined,
            title: 'Learning ID (EIP)',
            onTap: () => context.push(AppRoutes.eipSettings),
          ),
          SizedBox(height: AppSpacing.sectionGapFor(context)),
          Text('About', style: AppTextStyles.osSectionLabel(context)),
          const SizedBox(height: AppSpacing.sm),
          const DtControlTile(
            icon: Icons.info_outline,
            title: 'App Version',
            subtitle: '1.0.0 (build 1)',
          ),
          DtControlTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => _openPrivacyPolicy(context, ref),
          ),
          const SizedBox(height: AppSpacing.lg),
          DtCopperButton(
            label: 'Sign Out',
            variant: DtCopperButtonVariant.destructive,
            icon: Icons.logout,
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Sign Out',
                          style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await ref.read(authNotifierProvider.notifier).logout();
              }
            },
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Future<void> _confirmClearHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all stored history?'),
        content: const Text(
          'This permanently removes chat sessions, living books, '
          'knowledge bases, co-writer documents, notebooks, and '
          'notifications from your account. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Clearing stored history…')),
    );

    final result =
        await ref.read(historyClearServiceProvider).clearAllStoredHistory();

    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.hasFailures
              ? 'Cleared ${result.deleted} items (${result.failed} failed)'
              : 'Cleared ${result.deleted} stored items',
        ),
        backgroundColor: result.hasFailures ? AppColors.warning : null,
      ),
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context, WidgetRef ref) async {
    final uri = Uri.parse(AppConfig.privacyPolicyUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open privacy policy')),
        );
      }
    }
  }
}

class _SystemStatusTile extends ConsumerWidget {
  const _SystemStatusTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(systemStatusProvider);
    return statusAsync.when(
      data: (data) {
        final backend =
            (data['backend'] as Map?)?['status']?.toString() ?? 'unknown';
        final llm = (data['llm'] as Map?)?['model']?.toString();
        final subtitle = llm != null && llm.isNotEmpty
            ? 'Backend: $backend · LLM: $llm'
            : 'Backend: $backend';
        return DtControlTile(
          icon: Icons.dns_outlined,
          title: 'System status',
          subtitle: subtitle,
          onTap: () => _showSystemDialog(context, data),
        );
      },
      loading: () => const DtControlTile(
        icon: Icons.dns_outlined,
        title: 'System status',
        subtitle: 'Checking…',
      ),
      error: (e, _) => DtControlTile(
        icon: Icons.dns_outlined,
        title: 'System status',
        subtitle: 'Unavailable — is the backend running?',
        onTap: () => ref.invalidate(systemStatusProvider),
      ),
    );
  }

  void _showSystemDialog(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('System status'),
        content: SingleChildScrollView(
          child: Text(
            const JsonEncoder.withIndent('  ').convert(data),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

